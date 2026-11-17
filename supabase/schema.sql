-- =====================================================================
-- JEKPE — база данных MVP (Supabase / PostgreSQL)
-- Как запустить: Supabase → SQL Editor → вставить весь файл → Run
-- =====================================================================

-- ---------- Пользователи ----------
-- Supabase сам хранит логин/пароль в auth.users, здесь — профиль.
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null,
  role        text not null default 'athlete'
              check (role in ('athlete','coach','organizer','admin')),
  phone       text,
  birth_date  date,
  gender      text check (gender in ('m','f')),
  club_id     uuid,
  lang        text not null default 'ru' check (lang in ('ru','kz','en')),
  credits     int  not null default 0 check (credits >= 0),  -- баланс организатора
  created_at  timestamptz not null default now()
);

-- ---------- Клубы / академии ----------
create table clubs (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  city       text,
  owner_id   uuid references profiles(id),
  created_at timestamptz not null default now()
);
alter table profiles add constraint profiles_club_fk
  foreign key (club_id) references clubs(id) on delete set null;

-- ---------- Турниры ----------
create table events (
  id            uuid primary key default gen_random_uuid(),
  organizer_id  uuid not null references profiles(id),
  title         text not null,
  sport         text not null
                check (sport in ('bjj','judo','free','greco','sambo','karate')),
  city          text,
  venue         text,
  starts_on     date not null,
  reg_deadline  date,
  entry_fee     int  default 0,          -- взнос атлета в тенге (собирает организатор)
  payment_info  text,                    -- «Kaspi +7 7xx… / на взвешивании»
  description   text,
  status        text not null default 'draft'
                check (status in ('draft','open','closed','live','finished')),
  mats_count    int not null default 1,
  created_at    timestamptz not null default now()
);

-- ---------- Категории (вес / возраст / пояс) ----------
create table divisions (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references events(id) on delete cascade,
  name        text not null,             -- «Adult Blue Male −76 kg»
  gender      text check (gender in ('m','f','mixed')),
  age_min     int,
  age_max     int,
  weight_max  numeric(5,1),              -- null = абсолютная категория
  belt        text,
  match_time  int not null default 300,  -- секунд
  bracket     text not null default 'single'
              check (bracket in ('single','double','round_robin')),
  locked      boolean not null default false  -- сетка сформирована
);

-- ---------- Заявки ----------
create table registrations (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references events(id) on delete cascade,
  division_id  uuid not null references divisions(id) on delete cascade,
  athlete_id   uuid not null references profiles(id),
  club_id      uuid references clubs(id),
  status       text not null default 'pending'
               check (status in ('pending','confirmed','cancelled')),
  paid         boolean not null default false,  -- отметка организатора
  weight_in    numeric(5,1),                    -- вес на взвешивании
  confirmed_at timestamptz,
  created_at   timestamptz not null default now(),
  unique (division_id, athlete_id)
);

-- ---------- История кредитов ----------
create table credit_transactions (
  id              uuid primary key default gen_random_uuid(),
  organizer_id    uuid not null references profiles(id),
  amount          int  not null,          -- +100 начисление, −1 списание
  reason          text not null
                  check (reason in ('manual_topup','registration','refund','bonus')),
  registration_id uuid references registrations(id),
  note            text,                   -- «Kaspi перевод 45 000 ₸ от 18.11»
  created_by      uuid references profiles(id),
  created_at      timestamptz not null default now()
);

-- ---------- Схватки (сетка + результаты с табло) ----------
create table matches (
  id           uuid primary key default gen_random_uuid(),
  division_id  uuid not null references divisions(id) on delete cascade,
  round        int  not null,             -- 1 = первый круг
  position     int  not null,             -- номер в круге
  red_id       uuid references registrations(id),
  blue_id      uuid references registrations(id),
  winner_id    uuid references registrations(id),
  next_match   uuid references matches(id),   -- куда идёт победитель
  mat          int,
  scheduled_at timestamptz,
  red_score    jsonb,                     -- {"pts":4,"adv":1,"pen":0}
  blue_score   jsonb,
  win_reason   text,                      -- «Сабмишн», «По очкам»…
  status       text not null default 'waiting'
               check (status in ('waiting','ready','live','done')),
  finished_at  timestamptz,
  unique (division_id, round, position)
);

-- =====================================================================
-- Логика кредитов
-- =====================================================================

-- Подтвердить заявку: списывает 1 кредит у организатора.
-- Если кредитов нет — ошибка, заявка остаётся «в ожидании».
create or replace function confirm_registration(reg_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  r   registrations;
  org uuid;
begin
  select * into r from registrations where id = reg_id for update;
  if r.status = 'confirmed' then return; end if;
  if r.status = 'cancelled' then raise exception 'Заявка отменена'; end if;

  select organizer_id into org from events where id = r.event_id;
  if org <> auth.uid() and not is_admin() then
    raise exception 'Нет доступа';
  end if;

  update profiles set credits = credits - 1
   where id = org and credits >= 1;
  if not found then raise exception 'NO_CREDITS'; end if;

  update registrations set status = 'confirmed', confirmed_at = now()
   where id = reg_id;
  insert into credit_transactions (organizer_id, amount, reason, registration_id, created_by)
  values (org, -1, 'registration', reg_id, auth.uid());
end $$;

-- Отменить подтверждённую заявку: кредит возвращается.
create or replace function cancel_registration(reg_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r registrations; org uuid;
begin
  select * into r from registrations where id = reg_id for update;
  select organizer_id into org from events where id = r.event_id;
  if org <> auth.uid() and r.athlete_id <> auth.uid() and not is_admin() then
    raise exception 'Нет доступа';
  end if;
  if r.status = 'confirmed' then
    update profiles set credits = credits + 1 where id = org;
    insert into credit_transactions (organizer_id, amount, reason, registration_id, created_by)
    values (org, 1, 'refund', reg_id, auth.uid());
  end if;
  update registrations set status = 'cancelled' where id = reg_id;
end $$;

-- Ручное начисление (только админ — ты): после перевода на Kaspi.
create or replace function add_credits(org_id uuid, qty int, comment text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Только для админа'; end if;
  update profiles set credits = credits + qty where id = org_id;
  insert into credit_transactions (organizer_id, amount, reason, note, created_by)
  values (org_id, qty, 'manual_topup', comment, auth.uid());
end $$;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- Профиль создаётся автоматически при регистрации
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, role)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', ''),
          case when new.raw_user_meta_data->>'role' in ('athlete','coach','organizer')
               then new.raw_user_meta_data->>'role' else 'athlete' end);  -- admin нельзя выбрать при регистрации
  return new;
end $$;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function handle_new_user();

-- =====================================================================
-- Доступы (Row Level Security): кто что видит и меняет
-- =====================================================================
alter table profiles            enable row level security;
alter table clubs               enable row level security;
alter table events              enable row level security;
alter table divisions           enable row level security;
alter table registrations       enable row level security;
alter table credit_transactions enable row level security;
alter table matches             enable row level security;

-- Профили: видят все (имена в сетках), меняет только владелец.
-- Баланс кредитов и роль admin руками поменять нельзя — только функциями.
create policy "profiles read"   on profiles for select using (true);
create policy "profiles update" on profiles for update using (id = auth.uid())
  with check (id = auth.uid()
    and credits = (select credits from profiles where id = auth.uid())
    and role <> 'admin');

-- Клубы
create policy "clubs read"  on clubs for select using (true);
create policy "clubs write" on clubs for all using (owner_id = auth.uid() or is_admin())
  with check (owner_id = auth.uid() or is_admin());

-- Турниры: опубликованные видят все, черновики — только организатор
create policy "events read" on events for select
  using (status <> 'draft' or organizer_id = auth.uid() or is_admin());
create policy "events write" on events for all
  using (organizer_id = auth.uid() or is_admin())
  with check (organizer_id = auth.uid() or is_admin());

-- Категории и схватки: видят все, меняет организатор турнира
create policy "divisions read" on divisions for select using (true);
create policy "divisions write" on divisions for all
  using (exists (select 1 from events e where e.id = event_id and (e.organizer_id = auth.uid() or is_admin())))
  with check (exists (select 1 from events e where e.id = event_id and (e.organizer_id = auth.uid() or is_admin())));

create policy "matches read" on matches for select using (true);
create policy "matches write" on matches for all
  using (exists (select 1 from divisions d join events e on e.id = d.event_id
                 where d.id = division_id and (e.organizer_id = auth.uid() or is_admin())))
  with check (exists (select 1 from divisions d join events e on e.id = d.event_id
                 where d.id = division_id and (e.organizer_id = auth.uid() or is_admin())));

-- Заявки: видят все (списки участников публичные),
-- подаёт атлет за себя (или тренер — добавим позже), статус меняют только функции
create policy "reg read" on registrations for select using (true);
create policy "reg insert" on registrations for insert
  with check (athlete_id = auth.uid() and status = 'pending');
create policy "reg org update" on registrations for update
  using (exists (select 1 from events e where e.id = event_id and (e.organizer_id = auth.uid() or is_admin())))
  with check (status = (select status from registrations x where x.id = registrations.id));

-- Кредиты: организатор видит только свою историю
create policy "credits read" on credit_transactions for select
  using (organizer_id = auth.uid() or is_admin());

-- Индексы для скорости
create index on events (status, starts_on);
create index on divisions (event_id);
create index on registrations (event_id, status);
create index on matches (division_id, round);
