-- =====================================================================
-- JEKPE — миграция 004: профиль атлета, пояса, дисциплины турнира,
-- умная регистрация, ввод результатов, места и статистика
-- =====================================================================

-- ---------- Профиль атлета ----------
alter table profiles add column if not exists belt text;
alter table profiles drop constraint if exists profiles_belt_check;
alter table profiles add constraint profiles_belt_check
  check (belt is null or belt in ('white','grey','yellow','orange','green','blue','purple','brown','black'));
alter table profiles add column if not exists club_name text;
alter table profiles add column if not exists city text;
alter table profiles add column if not exists country text default 'KZ';
alter table profiles add column if not exists weight numeric(5,1);
alter table profiles add column if not exists bio text;

grant select (belt, club_name, city, country) on profiles to anon, authenticated;
grant update (belt, club_name, city, country, weight, bio) on profiles to authenticated;

create or replace function belt_rank(b text) returns int language sql immutable as $$
  select array_position(array['white','grey','yellow','orange','green','blue','purple','brown','black'], b);
$$;

-- История поясов
create table if not exists belt_history (
  id         uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references profiles(id) on delete cascade,
  belt       text not null,
  changed_at timestamptz not null default now()
);
alter table belt_history enable row level security;
drop policy if exists "belt history read" on belt_history;
create policy "belt history read" on belt_history for select using (true);

-- Пояс нельзя понизить (как в Smoothcomp) — только админ
create or replace function profiles_belt_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.belt is distinct from old.belt then
    if old.belt is not null and new.belt is not null
       and belt_rank(new.belt) < belt_rank(old.belt) and not is_admin() then
      raise exception 'BELT_DOWN';
    end if;
    if new.belt is not null then
      insert into belt_history (athlete_id, belt) values (new.id, new.belt);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_belt on profiles;
create trigger profiles_belt before update on profiles
  for each row execute function profiles_belt_guard();

-- Публичный профиль (возраст вместо даты рождения)
create or replace function public_profile(p uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'id', id, 'full_name', full_name, 'role', role, 'belt', belt, 'gender', gender,
    'club_name', club_name, 'city', city, 'country', country, 'bio', bio,
    'age', case when birth_date is null then null else extract(year from age(birth_date))::int end,
    'created_at', created_at)
  from profiles where id = p;
$$;

-- ---------- Дисциплины турнира и автокатегории ----------
alter table events add column if not exists entries jsonb not null default '[]';
alter table divisions add column if not exists key text;
alter table divisions add column if not exists entry text;
create unique index if not exists divisions_event_key on divisions (event_id, key) where key is not null;
alter table registrations add column if not exists place int;

-- Регистрация атлета: находит или создаёт категорию по ключу дисциплины
create or replace function register_athlete(
  p_event uuid, p_entry text, p_key text, p_name text, p_gender text,
  p_age_min int, p_age_max int, p_weight numeric, p_belt text,
  p_time int, p_bracket text, p_club text)
returns uuid language plpgsql security definer set search_path = public as $$
declare ev events; d uuid; r uuid;
begin
  if auth.uid() is null then raise exception 'AUTH'; end if;
  select * into ev from events where id = p_event;
  if ev.status <> 'open' then raise exception 'REG_CLOSED'; end if;
  if not exists (select 1 from jsonb_array_elements(ev.entries) e where e->>'id' = p_entry) then
    raise exception 'BAD_ENTRY';
  end if;
  if position(p_entry || '|' in p_key) <> 1 or length(p_name) > 200 then raise exception 'BAD_KEY'; end if;

  select id into d from divisions where event_id = p_event and key = p_key;
  if d is null then
    insert into divisions (event_id, name, gender, age_min, age_max, weight_max, belt, match_time, bracket, key, entry)
    values (p_event, p_name, p_gender, p_age_min, p_age_max, p_weight, p_belt, coalesce(p_time, 300),
            coalesce(p_bracket, 'single'), p_key, p_entry)
    on conflict (event_id, key) where key is not null do update set key = excluded.key
    returning id into d;
  end if;

  insert into registrations (event_id, division_id, athlete_id, club_name)
  values (p_event, d, auth.uid(), nullif(trim(p_club), ''))
  returning id into r;
  return r;
end $$;

-- ---------- Ввод результата схватки ----------
create or replace function set_match_result(
  p_match uuid, p_winner uuid, p_method text, p_red jsonb, p_blue jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare m matches; dv divisions; org uuid; loser uuid; maxr int; nextpos int; wins_r int; wins_b int;
begin
  select * into m from matches where id = p_match for update;
  select * into dv from divisions where id = m.division_id;
  select organizer_id into org from events where id = dv.event_id;
  if org <> auth.uid() and not is_admin() then raise exception 'Нет доступа'; end if;
  if p_winner is null or p_winner not in (m.red_id, m.blue_id) or m.red_id is null or m.blue_id is null then
    raise exception 'BAD_WINNER';
  end if;
  loser := case when p_winner = m.red_id then m.blue_id else m.red_id end;

  update matches set winner_id = p_winner, win_reason = p_method, red_score = p_red, blue_score = p_blue,
         status = 'done', finished_at = now() where id = p_match;

  if m.part = 'main' then
    if dv.bracket = 'best_of_3' then
      select count(*) filter (where winner_id = m.red_id), count(*) filter (where winner_id = m.blue_id)
        into wins_r, wins_b from matches where division_id = dv.id and part = 'main';
      if wins_r >= 2 or wins_b >= 2 then
        update registrations set place = case when id = (case when wins_r >= 2 then m.red_id else m.blue_id end) then 1 else 2 end
         where id in (m.red_id, m.blue_id);
      end if;
      return;
    end if;
    select max(round) into maxr from matches where division_id = dv.id and part = 'main';
    if m.round < maxr then
      nextpos := (m.position + 1) / 2;
      if m.position % 2 = 1 then
        update matches set red_id = p_winner where division_id = dv.id and part = 'main' and round = m.round + 1 and position = nextpos;
      else
        update matches set blue_id = p_winner where division_id = dv.id and part = 'main' and round = m.round + 1 and position = nextpos;
      end if;
      update matches set status = case when red_id is not null and blue_id is not null then 'ready' else 'waiting' end
       where division_id = dv.id and part = 'main' and round = m.round + 1 and position = nextpos and status <> 'done';
      -- полуфинал
      if m.round = maxr - 1 then
        if dv.bracket = 'single' then
          if m.position % 2 = 1 then
            update matches set red_id = loser where division_id = dv.id and part = 'bronze';
          else
            update matches set blue_id = loser where division_id = dv.id and part = 'bronze';
          end if;
          update matches set status = 'ready' where division_id = dv.id and part = 'bronze' and red_id is not null and blue_id is not null and status <> 'done';
        else
          update registrations set place = 3 where id = loser;
        end if;
      end if;
    else
      update registrations set place = 1 where id = p_winner;
      update registrations set place = 2 where id = loser;
    end if;
  elsif m.part = 'bronze' then
    update registrations set place = 3 where id = p_winner;
    update registrations set place = 4 where id = loser;
  elsif m.part like 'pool%' and dv.bracket = 'round_robin' then
    if not exists (select 1 from matches where division_id = dv.id and part like 'pool%' and status <> 'done') then
      with w as (
        select r.id, count(mm.id) filter (where mm.winner_id = r.id) as wins
          from registrations r
          left join matches mm on mm.division_id = dv.id and (mm.red_id = r.id or mm.blue_id = r.id)
         where r.division_id = dv.id and r.status = 'confirmed'
         group by r.id),
      rk as (select id, rank() over (order by wins desc) as pl from w)
      update registrations set place = rk.pl from rk where registrations.id = rk.id;
    end if;
  end if;
end $$;

-- ---------- Статистика атлета ----------
create or replace function athlete_stats(p uuid)
returns json language sql stable security definer set search_path = public as $$
  with regs as (select id, event_id, place, status from registrations where athlete_id = p),
  ms as (
    select m.*, (m.winner_id in (select id from regs)) as won
      from matches m
     where m.status = 'done' and m.red_id is not null and m.blue_id is not null
       and coalesce(m.win_reason, '') <> 'bye'
       and (m.red_id in (select id from regs) or m.blue_id in (select id from regs)))
  select json_build_object(
    'events',  (select count(distinct event_id) from regs where status = 'confirmed'),
    'matches', (select count(*) from ms),
    'wins',    (select count(*) from ms where won),
    'losses',  (select count(*) from ms where not won),
    'by_method', coalesce((select json_object_agg(win_reason, c) from
                 (select coalesce(win_reason, 'points') as win_reason, count(*) c from ms where won group by 1) x), '{}'::json),
    'gold',    (select count(*) from regs where place = 1),
    'silver',  (select count(*) from regs where place = 2),
    'bronze',  (select count(*) from regs where place = 3));
$$;
