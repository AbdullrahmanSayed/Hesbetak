begin;
create extension if not exists pgtap with schema extensions;

select plan(20);

-- B2 Tables exist
select has_table('public', 'categories', 'categories table exists');
select has_table('public', 'brands', 'brands table exists');
select has_table('public', 'products', 'products table exists');
select has_table('public', 'customers', 'customers table exists');
select has_table('public', 'suppliers', 'suppliers table exists');
select has_table('public', 'cash_accounts', 'cash_accounts table exists');
select has_table('public', 'expense_categories', 'expense_categories table exists');
select has_table('public', 'partners', 'partners table exists');
select has_table('public', 'plan_templates', 'plan_templates table exists');
select has_table('public', 'attachments', 'attachments table exists');

-- B2 Enums exist
select has_enum('public', 'tracking_type', 'tracking_type enum exists');
select has_enum('public', 'cash_account_type', 'cash_account_type enum exists');
select has_enum('public', 'attachment_owner_type', 'attachment_owner_type enum exists');
select has_enum('public', 'attachment_kind', 'attachment_kind enum exists');
select has_enum('public', 'attachment_status', 'attachment_status enum exists');

-- All tables have tenant_id
select has_column('public', 'categories', 'tenant_id', 'categories has tenant_id');
select has_column('public', 'products', 'tenant_id', 'products has tenant_id');
select has_column('public', 'customers', 'tenant_id', 'customers has tenant_id');
select has_column('public', 'attachments', 'tenant_id', 'attachments has tenant_id');

-- RLS enabled
select ok(
  (select relrowsecurity from pg_class where relname = 'categories'),
  'categories has RLS enabled'
);

select * from finish();
rollback;
