begin;

create extension if not exists pgtap with schema extensions;

select plan(9);

select has_function('app', 'is_member', array['uuid'], 'app.is_member exists');
select has_function('app', 'has_role', array['uuid', 'membership_role[]'], 'app.has_role exists');

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name in ('journal_entries', 'journal_lines', 'document_counters', 'posting_requests', 'audit_log')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  'authenticated has no direct financial or audit write grant'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('app', 'public')
      and p.prosecdef
      and not coalesce(p.proconfig, '{}'::text[]) @> array['search_path=public, pg_temp']
  ),
  'all B1 security-definer functions fix search_path to public, pg_temp'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app'
      and has_function_privilege(0::oid, p.oid, 'EXECUTE')
  ),
  'PUBLIC cannot execute app functions'
);

select has_trigger('public', 'journal_entries', 'guard_journal_entry_mutation', 'journal entry mutation guard exists');
select has_trigger('public', 'journal_lines', 'guard_journal_line_mutation', 'journal line mutation guard exists');
select has_trigger('public', 'journal_lines', 'check_journal_entry_balanced', 'deferred journal balance trigger exists');
select has_trigger('public', 'audit_log', 'guard_audit_log_mutation', 'audit mutation guard exists');

select * from finish();
rollback;
