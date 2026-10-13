begin;

create extension if not exists pgtap with schema extensions;

select plan(34);

select has_schema('app', 'app schema exists');
select has_type('public', 'membership_role', 'membership_role enum exists');
select has_type('public', 'tenant_status', 'tenant_status enum exists');
select has_type('public', 'account_type', 'account_type enum exists');
select has_type('public', 'normal_side', 'normal_side enum exists');
select has_type('public', 'secret_kind', 'secret_kind enum exists');
select has_type('public', 'posting_request_status', 'posting_request_status enum exists');

select has_table('public', 'tenants', 'tenants table exists');
select has_table('public', 'memberships', 'memberships table exists');
select has_table('public', 'accounts', 'accounts table exists');
select has_table('public', 'journal_entries', 'journal_entries table exists');
select has_table('public', 'journal_lines', 'journal_lines table exists');
select has_table('public', 'document_counters', 'document_counters table exists');
select has_table('public', 'posting_requests', 'posting_requests table exists');
select has_table('public', 'audit_log', 'audit_log table exists');
select has_table('public', 'tenant_secret_refs', 'tenant_secret_refs table exists');

select col_type_is('public', 'tenants', 'lock_date', 'date', 'tenant lock_date is a date');
select col_type_is('public', 'tenants', 'settings', 'jsonb', 'tenant settings are jsonb');
select col_type_is('public', 'memberships', 'role', 'membership_role', 'membership role uses enum');
select col_type_is('public', 'accounts', 'system_key', 'text', 'account system_key is text');
select col_type_is('public', 'journal_entries', 'entry_no', 'bigint', 'journal entry number is bigint');
select col_type_is('public', 'journal_entries', 'entry_date', 'date', 'journal entry date is date');
select col_type_is('public', 'journal_lines', 'debit', 'bigint', 'journal debit is bigint piasters');
select col_type_is('public', 'journal_lines', 'credit', 'bigint', 'journal credit is bigint piasters');
select col_type_is('public', 'document_counters', 'last_no', 'bigint', 'counter value is bigint');
select col_type_is('public', 'posting_requests', 'payload_hash', 'text', 'request fingerprint is text');
select col_type_is('public', 'tenant_secret_refs', 'vault_secret_id', 'uuid', 'Vault reference is UUID only');

select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'tenants'), false), 'tenants has RLS enabled');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'memberships'), false), 'memberships has RLS enabled');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'accounts'), false), 'accounts has RLS enabled');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'journal_entries'), false), 'journal_entries has RLS enabled');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'journal_lines'), false), 'journal_lines has RLS enabled');

select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and tablename in (
    'categories', 'brands', 'products', 'customers', 'suppliers', 'partners', 'cash_accounts',
    'expense_categories', 'installment_plan_templates', 'sales_invoices', 'purchase_invoices'
  )),
  0,
  'no B2+ tables exist'
);

select is(
  (select count(*)::int from information_schema.columns where table_schema = 'public' and table_name = 'tenants' and column_name = 'tenant_id'),
  0,
  'root tenants table does not duplicate tenant identity'
);

select * from finish();
rollback;
