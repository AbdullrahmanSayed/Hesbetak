begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(8);

select tests.create_user('70000000-0000-0000-0000-000000000001', 'audit-owner@example.com');
select tests.create_user('70000000-0000-0000-0000-000000000002', 'audit-cashier@example.com');
select tests.authenticate_as('70000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('audit-tenant', 'Audit Tenant') $$, 'audit tenant bootstraps');

-- Add cashier role
select lives_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'audit-tenant'), '70000000-0000-0000-0000-000000000002', 'cashier', true) $$,
  'cashier membership added'
);

-- Owner can see audit log
select is((select count(*)::int from public.audit_log), 2, 'owner sees bootstrap and membership audit entries');

-- Audit has required attribution
select ok(
  (select actor_id is not null and tenant_id is not null and action is not null from public.audit_log limit 1),
  'audit entries have actor, tenant, and action attribution'
);

-- Audit is immutable (RLS denies before trigger fires, which is correct)
select throws_ok(
  $$ update public.audit_log set action = 'hacked' where true $$,
  '42501',
  null,
  'authenticated cannot update audit_log'
);

select throws_ok(
  $$ delete from public.audit_log where true $$,
  '42501',
  null,
  'authenticated cannot delete from audit_log'
);

-- Cashier cannot see audit log
select tests.reset_authentication();
select tests.authenticate_as('70000000-0000-0000-0000-000000000002');
select is((select count(*)::int from public.audit_log), 0, 'cashier cannot see audit log (only owner/accountant)');

-- Audit does not contain secret values
select tests.reset_authentication();
select ok(
  not exists (
    select 1 from public.audit_log
    where before_data::text ~* 'secret|password|token|vault_secret_id'
       or after_data::text ~* 'secret|password|token|vault_secret_id'
  ),
  'audit entries do not contain secret-related fields'
);

select * from finish();
rollback;
