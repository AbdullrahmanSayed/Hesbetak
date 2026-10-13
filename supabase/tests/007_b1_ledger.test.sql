begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(11);

select tests.create_user('40000000-0000-0000-0000-000000000001', 'ledger-owner@example.com');
select tests.authenticate_as('40000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('ledger-tenant', 'Ledger Tenant') $$, 'ledger tenant bootstraps');

create temp table captured_results (result jsonb);
select lives_ok($post$
  insert into captured_results
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'ledger-tenant'),
    '40000000-0000-0000-0000-000000000010',
    date '2026-02-01',
    '40000000-0000-0000-0000-000000000011',
    'Balanced test entry',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where system_key = 'cash_main'), 'debit', '2000000', 'credit', '0', 'memo', 'cash'),
      jsonb_build_object('account_id', (select id from public.accounts where system_key = 'sales'), 'debit', '0', 'credit', '2000000', 'memo', 'sale')
    )
  )
$post$, 'balanced two-line entry posts');
select is((select count(*)::int from public.journal_entries), 1, 'one journal entry is stored');
select is((select count(*)::int from public.journal_lines), 2, 'two journal lines are stored');
select is((select sum(debit)::text from public.journal_lines), '2000000', 'exact debit piasters are stored');
select is((select sum(credit)::text from public.journal_lines), '2000000', 'exact credit piasters are stored');
select is((select result->>'total_debit' from captured_results limit 1), '2000000', 'financial result returns debit as decimal string');
select is((select result->>'entry_no' from captured_results limit 1), '1', 'entry number returns as decimal string');

select lives_ok($post$
  insert into captured_results
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'ledger-tenant'),
    '40000000-0000-0000-0000-000000000020',
    date '9999-12-31',
    '40000000-0000-0000-0000-000000000021',
    'High exact amount and future date',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where system_key = 'cash_main'), 'debit', '9007199254740993', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where system_key = 'other_income'), 'debit', '0', 'credit', '9007199254740993')
    )
  )
$post$, 'amount above JavaScript safe integer and valid future date post exactly');
select is((select max(debit)::text from public.journal_lines), '9007199254740993', 'high piaster value has no precision loss');
select is((select max(result->>'total_debit') from captured_results), '9007199254740993', 'high result remains a decimal string');

select * from finish();
rollback;
