begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(8);

select tests.create_user('51000000-0000-0000-0000-000000000001', 'counter-owner@example.com');
select tests.authenticate_as('51000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('counter-a', 'Counter A') $$, 'counter tenant A bootstraps');
select lives_ok($$ select public.bootstrap_tenant('counter-b', 'Counter B') $$, 'counter tenant B bootstraps');

-- First entry in tenant A 2026 gets number 1
create temp table entry_a1 (result jsonb);
insert into entry_a1
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'counter-a'),
  gen_random_uuid(),
  date '2026-04-01',
  gen_random_uuid(),
  'Entry A1',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'cash_main'), 'debit', '1000', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'sales'), 'debit', '0', 'credit', '1000')
  )
);
select is((select result->>'entry_no' from entry_a1), '1', 'tenant A 2026 first entry is number 1');

-- Second entry in tenant A 2026 gets number 2
create temp table entry_a2 (result jsonb);
insert into entry_a2
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'counter-a'),
  gen_random_uuid(),
  date '2026-04-02',
  gen_random_uuid(),
  'Entry A2',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'cash_main'), 'debit', '2000', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'sales'), 'debit', '0', 'credit', '2000')
  )
);
select is((select result->>'entry_no' from entry_a2), '2', 'tenant A 2026 second entry is number 2');

-- First entry in tenant B 2026 starts fresh at 1
create temp table entry_b1 (result jsonb);
insert into entry_b1
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'counter-b'),
  gen_random_uuid(),
  date '2026-04-01',
  gen_random_uuid(),
  'Entry B1',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-b') and system_key = 'cash_main'), 'debit', '500', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-b') and system_key = 'sales'), 'debit', '0', 'credit', '500')
  )
);
select is((select result->>'entry_no' from entry_b1), '1', 'tenant B counter is independent');

-- Entry in tenant A 2027 starts fresh at 1 (year rollover)
create temp table entry_a_2027 (result jsonb);
insert into entry_a_2027
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'counter-a'),
  gen_random_uuid(),
  date '2027-01-15',
  gen_random_uuid(),
  'Entry A 2027',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'cash_main'), 'debit', '3000', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'sales'), 'debit', '0', 'credit', '3000')
  )
);
select is((select result->>'entry_no' from entry_a_2027), '1', 'year rollover resets counter');

-- After year rollover, tenant A 2026 continues from 2
create temp table entry_a3 (result jsonb);
insert into entry_a3
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'counter-a'),
  gen_random_uuid(),
  date '2026-12-31',
  gen_random_uuid(),
  'Entry A3',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'cash_main'), 'debit', '4000', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'counter-a') and system_key = 'sales'), 'debit', '0', 'credit', '4000')
  )
);
select is((select result->>'entry_no' from entry_a3), '3', 'tenant A 2026 continues from previous number');

select tests.reset_authentication();
select is(
  (select count(distinct (tenant_id, doc_type, year))::int from public.document_counters),
  3,
  'three distinct counter partitions exist'
);

select * from finish();
rollback;
