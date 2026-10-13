begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(9);

select tests.create_user('50000000-0000-0000-0000-000000000001', 'idemp-owner@example.com');
select tests.authenticate_as('50000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('idemp-tenant', 'Idempotency Tenant') $$, 'idempotency tenant bootstraps');

-- First posting with a specific request_id
create temp table first_result (result jsonb);
insert into first_result
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'idemp-tenant'),
  '50000000-0000-0000-0000-000000000010',
  date '2026-03-01',
  '50000000-0000-0000-0000-000000000011',
  'Idempotent entry',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'cash_main'), 'debit', '5000', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '5000')
  )
);

select is((select count(*)::int from public.journal_entries where tenant_id = (select id from public.tenants where slug = 'idemp-tenant')), 1, 'first request creates one entry');
select is((select result->>'entry_no' from first_result), '1', 'first entry gets number 1');

-- Identical retry with same request_id, operation, and payload
create temp table retry_result (result jsonb);
insert into retry_result
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'idemp-tenant'),
  '50000000-0000-0000-0000-000000000010',
  date '2026-03-01',
  '50000000-0000-0000-0000-000000000011',
  'Idempotent entry',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'cash_main'), 'debit', '5000', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '5000')
  )
);

select is((select count(*)::int from public.journal_entries where tenant_id = (select id from public.tenants where slug = 'idemp-tenant')), 1, 'identical retry does not create a second entry');
select is((select result->>'entry_no' from retry_result), '1', 'retry returns the original entry number');
select is((select result->>'entry_id' from retry_result), (select result->>'entry_id' from first_result), 'retry returns the original entry_id');

-- Mismatched retry: same request_id but different payload
select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'idemp-tenant'),
    '50000000-0000-0000-0000-000000000010',
    date '2026-03-01',
    '50000000-0000-0000-0000-000000000011',
    'Different description',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'cash_main'), 'debit', '5000', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '5000')
    )
  )
$q$, '23514', null, 'mismatched payload with same request_id is rejected');

-- New request_id gets a new entry
create temp table second_result (result jsonb);
insert into second_result
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'idemp-tenant'),
  '50000000-0000-0000-0000-000000000020',
  date '2026-03-01',
  '50000000-0000-0000-0000-000000000021',
  'Second entry',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'cash_main'), 'debit', '3000', 'credit', '0'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'idemp-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '3000')
  )
);

select is((select count(*)::int from public.journal_entries where tenant_id = (select id from public.tenants where slug = 'idemp-tenant')), 2, 'new request_id creates second entry');
select is((select result->>'entry_no' from second_result), '2', 'second entry gets number 2');

select * from finish();
rollback;
