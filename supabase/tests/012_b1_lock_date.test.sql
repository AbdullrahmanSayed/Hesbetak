begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(6);

select tests.create_user('60000000-0000-0000-0000-000000000001', 'lock-owner@example.com');
select tests.authenticate_as('60000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('lock-tenant', 'Lock Tenant') $$, 'lock tenant bootstraps');

-- Post an entry before lock
select lives_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'lock-tenant'),
    gen_random_uuid(),
    date '2026-05-15',
    gen_random_uuid(),
    'Entry before lock',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'cash_main'), 'debit', '1000', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '1000')
    )
  )
$q$, 'entry before lock succeeds');

-- Set lock date to 2026-05-31
select lives_ok($$ select public.set_lock_date((select id from public.tenants where slug = 'lock-tenant'), date '2026-05-31') $$, 'owner sets lock date');

-- Entry on locked date fails
select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'lock-tenant'),
    gen_random_uuid(),
    date '2026-05-31',
    gen_random_uuid(),
    'Entry on locked date',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'cash_main'), 'debit', '1000', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '1000')
    )
  )
$q$, '55000', null, 'entry on locked date fails');

-- Entry before lock date fails
select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'lock-tenant'),
    gen_random_uuid(),
    date '2026-05-20',
    gen_random_uuid(),
    'Entry before locked date',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'cash_main'), 'debit', '1000', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '1000')
    )
  )
$q$, '55000', null, 'entry before locked date fails');

-- Entry after lock date succeeds
select lives_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'lock-tenant'),
    gen_random_uuid(),
    date '2026-06-01',
    gen_random_uuid(),
    'Entry after lock',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'cash_main'), 'debit', '1000', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'lock-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '1000')
    )
  )
$q$, 'entry after lock date succeeds');

select * from finish();
rollback;
