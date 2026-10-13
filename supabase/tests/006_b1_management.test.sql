begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(11);

select tests.create_user('30000000-0000-0000-0000-000000000001', 'owner@example.com');
select tests.create_user('30000000-0000-0000-0000-000000000002', 'manager@example.com');
select tests.authenticate_as('30000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('managed-tenant', 'Managed Tenant') $$, 'owner bootstraps managed tenant');

select lives_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'managed-tenant'), '30000000-0000-0000-0000-000000000002', 'manager', true) $$,
  'owner can add an active manager'
);
select is(
  (select role::text from public.memberships where user_id = '30000000-0000-0000-0000-000000000002'),
  'manager',
  'membership operation stores the requested role'
);
select throws_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'managed-tenant'), '30000000-0000-0000-0000-000000000001', 'owner', false) $$,
  '23514',
  null,
  'tenant cannot lose its final active owner'
);
select lives_ok(
  $$ select public.set_lock_date((select id from public.tenants where slug = 'managed-tenant'), date '2026-01-31') $$,
  'owner can set lock date'
);
select is((select lock_date from public.tenants where slug = 'managed-tenant'), date '2026-01-31', 'lock date is stored exactly');
select tests.reset_authentication();
select is(
  (select count(*)::int from public.audit_log a join public.tenants t on t.id = a.tenant_id where t.slug = 'managed-tenant' and a.action in ('membership.upsert', 'tenant.lock_date')),
  2,
  'membership and lock-date changes are audited'
);

select tests.authenticate_as('30000000-0000-0000-0000-000000000002');
select throws_ok(
  $$ select public.set_lock_date((select id from public.tenants where slug = 'managed-tenant'), date '2026-02-28') $$,
  '42501',
  null,
  'manager cannot change lock date'
);
select tests.reset_authentication();
update public.tenants set status = 'suspended' where slug = 'managed-tenant';
select tests.authenticate_as('30000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'managed-tenant'), '30000000-0000-0000-0000-000000000002', 'manager', false) $$,
  '55000',
  null,
  'suspended tenant rejects membership writes'
);
select is((select count(*)::int from public.tenants), 1, 'suspended tenant remains readable to active owner');
select tests.reset_authentication();
select ok(
  not exists (select 1 from public.audit_log where before_data ? 'secret' or after_data ? 'secret'),
  'management audit contains no secret field'
);

select * from finish();
rollback;
