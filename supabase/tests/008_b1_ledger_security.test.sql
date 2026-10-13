begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(14);

select tests.create_user('41000000-0000-0000-0000-000000000001', 'invariant-owner@example.com');
select tests.authenticate_as('41000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('invariant-a', 'Invariant A') $$, 'first invariant tenant bootstraps');
select lives_ok($$ select public.bootstrap_tenant('invariant-b', 'Invariant B') $$, 'second invariant tenant bootstraps');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'imbalanced',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '100', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '99')
    )
  )
$q$, '23514', null, 'imbalanced entry is rejected');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'one line',
    jsonb_build_array(jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '100', 'credit', '0'))
  )
$q$, '23514', null, 'one-line entry is rejected');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'both sides',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '100', 'credit', '100'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '100', 'credit', '100')
    )
  )
$q$, '23514', null, 'line with both positive sides is rejected');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'zero sides',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '0', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '0')
    )
  )
$q$, '23514', null, 'zero-sided lines are rejected');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'header account',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and code = '1100'), 'debit', '100', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '100')
    )
  )
$q$, '23514', null, 'header account cannot receive postings');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'cross tenant account',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-b') and system_key = 'cash_main'), 'debit', '100', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '100')
    )
  )
$q$, '23514', null, 'cross-tenant account is rejected');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'negative amount',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '-1', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '-1')
    )
  )
$q$, '23514', null, 'negative amount is rejected');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'malformed amount',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '12.5', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '12.5')
    )
  )
$q$, '22P02', null, 'malformed decimal money string is rejected');

select tests.reset_authentication();
update public.accounts set is_active = false
where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales';
select tests.authenticate_as('41000000-0000-0000-0000-000000000001');
select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'inactive account',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '100', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '100')
    )
  )
$q$, '23514', null, 'inactive account cannot receive postings');

select throws_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'invariant-a'), gen_random_uuid(), date '2026-02-01', gen_random_uuid(), 'overflow',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'cash_main'), 'debit', '9223372036854775808', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'invariant-a') and system_key = 'sales'), 'debit', '0', 'credit', '9223372036854775808')
    )
  )
$q$, '22003', null, 'signed-bigint overflow is rejected');

select throws_ok(
  $$ insert into public.journal_entries (tenant_id, entry_no, entry_date, source_type, source_id, description, request_id, created_by)
     values ((select id from public.tenants where slug = 'invariant-a'), 99, date '2026-02-01', 'direct', gen_random_uuid(), 'direct', gen_random_uuid(), auth.uid()) $$,
  '42501',
  null,
  'authenticated role cannot insert journal entries directly'
);

select is((select count(*)::int from public.journal_entries), 0, 'failed postings leave no residual journal rows');

select * from finish();
rollback;
