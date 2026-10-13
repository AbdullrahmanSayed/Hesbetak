begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(15);

select tests.create_user('61000000-0000-0000-0000-000000000001', 'reversal-owner@example.com');
select tests.authenticate_as('61000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('reversal-tenant', 'Reversal Tenant') $$, 'reversal tenant bootstraps');

-- Create an entry to reverse
create temp table original_entry (result jsonb);
insert into original_entry
select tests.post_manual_entry(
  (select id from public.tenants where slug = 'reversal-tenant'),
  '61000000-0000-0000-0000-000000000010',
  date '2026-06-01',
  '61000000-0000-0000-0000-000000000011',
  'Entry to reverse',
  jsonb_build_array(
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'reversal-tenant') and system_key = 'cash_main'), 'debit', '8000', 'credit', '0', 'memo', 'original cash'),
    jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'reversal-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '8000', 'memo', 'original sales')
  )
);
select is((select count(*)::int from public.journal_entries where tenant_id = (select id from public.tenants where slug = 'reversal-tenant')), 1, 'original entry created');

-- Reverse the entry
create temp table reversal_entry (result jsonb);
insert into reversal_entry
select tests.reverse_entry(
  (select id from public.tenants where slug = 'reversal-tenant'),
  '61000000-0000-0000-0000-000000000020',
  (select (result->>'entry_id')::uuid from original_entry),
  date '2026-06-02',
  'Correcting error'
);
select is((select count(*)::int from public.journal_entries where tenant_id = (select id from public.tenants where slug = 'reversal-tenant')), 2, 'reversal creates second entry');

-- Verify mirror lines
select is(
  (select sum(debit)::text from public.journal_lines where entry_id = (select (result->>'entry_id')::uuid from reversal_entry)),
  '8000',
  'reversal debit equals original credit'
);
select is(
  (select sum(credit)::text from public.journal_lines where entry_id = (select (result->>'entry_id')::uuid from reversal_entry)),
  '8000',
  'reversal credit equals original debit'
);

-- Verify bidirectional links
select ok(
  (select reverses_entry_id is not null from public.journal_entries where id = (select (result->>'entry_id')::uuid from reversal_entry)),
  'reversal points to original'
);
select ok(
  (select reversed_by_entry_id is not null from public.journal_entries where id = (select (result->>'entry_id')::uuid from original_entry)),
  'original points to reversal'
);

-- Net zero check
select is(
  (select coalesce(sum(debit - credit), 0)::text
   from public.journal_lines
   where tenant_id = (select id from public.tenants where slug = 'reversal-tenant')),
  '0',
  'original plus reversal net to zero'
);

-- Cannot reverse again
select throws_ok($q$
  select tests.reverse_entry(
    (select id from public.tenants where slug = 'reversal-tenant'),
    gen_random_uuid(),
    (select (result->>'entry_id')::uuid from original_entry),
    date '2026-06-03',
    'Double reversal'
  )
$q$, '23514', null, 'already reversed entry cannot be reversed again');

-- Cannot reverse the reversal
select throws_ok($q$
  select tests.reverse_entry(
    (select id from public.tenants where slug = 'reversal-tenant'),
    gen_random_uuid(),
    (select (result->>'entry_id')::uuid from reversal_entry),
    date '2026-06-03',
    'Reversal of reversal'
  )
$q$, '23514', null, 'reversal cannot be reversed');

-- Must provide reason
select throws_ok($q$
  select tests.reverse_entry(
    (select id from public.tenants where slug = 'reversal-tenant'),
    gen_random_uuid(),
    gen_random_uuid(),
    date '2026-06-03',
    ''
  )
$q$, '23514', null, 'empty reason is rejected');

-- Locked date reversal fails
select lives_ok($$ select public.set_lock_date((select id from public.tenants where slug = 'reversal-tenant'), date '2026-06-30') $$, 'set lock date');
-- Create another entry to test lock on reversal
select lives_ok($q$
  select tests.post_manual_entry(
    (select id from public.tenants where slug = 'reversal-tenant'),
    gen_random_uuid(),
    date '2026-07-01',
    gen_random_uuid(),
    'Entry for lock test',
    jsonb_build_array(
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'reversal-tenant') and system_key = 'cash_main'), 'debit', '1000', 'credit', '0'),
      jsonb_build_object('account_id', (select id from public.accounts where tenant_id = (select id from public.tenants where slug = 'reversal-tenant') and system_key = 'sales'), 'debit', '0', 'credit', '1000')
    )
  )
$q$, 'entry for lock reversal test');

select throws_ok($q$
  select tests.reverse_entry(
    (select id from public.tenants where slug = 'reversal-tenant'),
    gen_random_uuid(),
    (select id from public.journal_entries where tenant_id = (select id from public.tenants where slug = 'reversal-tenant') and reverses_entry_id is null and reversed_by_entry_id is null order by created_at desc limit 1),
    date '2026-06-15',
    'Late reversal'
  )
$q$, '55000', null, 'reversal on locked date fails');

-- Reversal is audited
select tests.reset_authentication();
select ok(
  exists (select 1 from public.audit_log where tenant_id = (select id from public.tenants where slug = 'reversal-tenant') and action = 'journal.reversal'),
  'reversal is audited'
);

select * from finish();
rollback;
