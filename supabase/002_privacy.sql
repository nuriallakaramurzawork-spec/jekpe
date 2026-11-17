-- =====================================================================
-- JEKPE — миграция 002: защита личных данных и статусов заявок
-- Запускать после schema.sql
-- =====================================================================

-- ---------- Профили: чужие видят только имя и роль ----------
revoke select, update on profiles from anon, authenticated;
grant select (id, full_name, role, club_id, gender, lang, created_at) on profiles to anon, authenticated;
grant update (full_name, phone, birth_date, gender, club_id, lang) on profiles to authenticated;

drop policy if exists "profiles update" on profiles;
create policy "profiles update" on profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Свой профиль целиком (с телефоном и кредитами)
create or replace function my_profile()
returns profiles language sql stable security definer set search_path = public as $$
  select * from profiles where id = auth.uid();
$$;

-- Список пользователей для админки
create or replace function admin_users()
returns table (id uuid, full_name text, role text, phone text, credits int, email text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Только для админа'; end if;
  return query
    select p.id, p.full_name, p.role, p.phone, p.credits, u.email::text, p.created_at
      from profiles p join auth.users u on u.id = p.id
     order by p.created_at desc;
end $$;

-- Админ может сделать пользователя организатором
create or replace function admin_set_role(user_id uuid, new_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'Только для админа'; end if;
  if new_role not in ('athlete','coach','organizer') then raise exception 'Неверная роль'; end if;
  update profiles set role = new_role where id = user_id and role <> 'admin';
end $$;

-- ---------- Заявки: организатор меняет только «оплачено» и вес ----------
revoke update on registrations from anon, authenticated;
grant update (paid, weight_in) on registrations to authenticated;

drop policy if exists "reg org update" on registrations;
create policy "reg org update" on registrations for update
  using (exists (select 1 from events e where e.id = event_id
                 and (e.organizer_id = auth.uid() or is_admin())));

-- Проверка при подаче заявки: категория из этого турнира, регистрация открыта,
-- атлет не может сам отметить «оплачено» или «подтверждено»
create or replace function check_registration()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from divisions d join events e on e.id = d.event_id
                  where d.id = new.division_id and d.event_id = new.event_id
                    and e.status = 'open') then
    raise exception 'REG_CLOSED';
  end if;
  new.status := 'pending';
  new.paid := false;
  new.confirmed_at := null;
  return new;
end $$;
drop trigger if exists registrations_check on registrations;
create trigger registrations_check before insert on registrations
  for each row execute function check_registration();

-- ---------- Турниры создают только организаторы ----------
drop policy if exists "events write" on events;
create policy "events write" on events for all
  using (organizer_id = auth.uid() or is_admin())
  with check (is_admin() or (organizer_id = auth.uid() and exists
    (select 1 from profiles where id = auth.uid() and role in ('organizer','admin'))));
