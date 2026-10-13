-- Foundation pgTAP harness: proves the database test pipeline and Cairo time-zone contract.
begin;

create extension if not exists pgtap with schema extensions;

select plan(2);

select ok(
  exists (select 1 from pg_timezone_names where name = 'Africa/Cairo'),
  'Africa/Cairo time zone is available'
);

select is(
  (timestamptz '2026-01-14 22:00:00+00' at time zone 'Africa/Cairo')::date,
  date '2026-01-15',
  'Cairo business date of 2026-01-14 22:00 UTC is 2026-01-15 (parity with src/lib/dates.ts)'
);

select * from finish();

rollback;
