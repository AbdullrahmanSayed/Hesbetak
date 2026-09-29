-- B0 pgTAP harness: proves the database test pipeline works and that B0 created no B1 objects.
begin;

create extension if not exists pgtap with schema extensions;

select plan(4);

select ok(
  exists (select 1 from pg_timezone_names where name = 'Africa/Cairo'),
  'Africa/Cairo time zone is available'
);

select is(
  (timestamptz '2026-01-14 22:00:00+00' at time zone 'Africa/Cairo')::date,
  date '2026-01-15',
  'Cairo business date of 2026-01-14 22:00 UTC is 2026-01-15 (parity with src/lib/dates.ts)'
);

select is(
  (select count(*)::int from pg_tables where schemaname = 'public'),
  0,
  'no tables exist in schema public (B0 creates no B1 objects)'
);

select is(
  (
    select count(*)::int
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  ),
  0,
  'no functions exist in schema public (B0 creates no B1 objects)'
);

select * from finish();

rollback;
