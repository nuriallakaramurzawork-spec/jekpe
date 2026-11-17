-- =====================================================================
-- JEKPE — миграция 003: не-ваза (JJIF) и системы сеток
-- =====================================================================

-- Новый вид спорта: джиу-джитсу не-ваза (JJIF)
alter table events drop constraint if exists events_sport_check;
alter table events add constraint events_sport_check
  check (sport in ('bjj','newaza','judo','free','greco','sambo','karate'));

-- Системы сеток
--  single          — олимпийская, схватка за 3-е место
--  single_2bronze  — олимпийская, два третьих места (IBJJF)
--  repechage_judo  — с утешительными (IJF: проигравшие полуфиналистам с 1/4)
--  repechage_full  — с утешительными (UWW / FIAS / WKF: проигравшие финалистам)
--  double          — двойное выбывание
--  round_robin     — круговая (каждый с каждым)
--  pools           — группы + плей-офф
--  best_of_3       — до двух побед (для 2 участников)
alter table divisions drop constraint if exists divisions_bracket_check;
update divisions set bracket = 'single' where bracket not in
  ('single','single_2bronze','repechage_judo','repechage_full','double','round_robin','pools','best_of_3');
alter table divisions add constraint divisions_bracket_check
  check (bracket in ('single','single_2bronze','repechage_judo','repechage_full','double','round_robin','pools','best_of_3'));

-- Части сетки: main / bronze / repechage / losers / pool-A, pool-B … / playoff
alter table matches add column if not exists part text not null default 'main';
alter table matches drop constraint if exists matches_division_id_round_position_key;
alter table matches add constraint matches_division_part_round_position_key
  unique (division_id, part, round, position);

-- Атлет может указать клуб при заявке (для разведения одноклубников в сетке)
alter table registrations add column if not exists club_name text;
grant update (paid, weight_in, club_name) on registrations to authenticated;
