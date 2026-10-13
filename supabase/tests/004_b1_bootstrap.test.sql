begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(11);

select tests.create_user('10000000-0000-0000-0000-000000000001', 'owner1@example.com');
select tests.authenticate_as('10000000-0000-0000-0000-000000000001');

select lives_ok(
  $$ select public.bootstrap_tenant('alpha-showroom', 'معرض ألفا') $$,
  'authenticated user can bootstrap a tenant'
);

select tests.reset_authentication();

select is((select count(*)::int from public.tenants where slug = 'alpha-showroom'), 1, 'bootstrap creates exactly one tenant');
select is(
  (select count(*)::int from public.memberships m join public.tenants t on t.id = m.tenant_id where t.slug = 'alpha-showroom' and m.user_id = '10000000-0000-0000-0000-000000000001' and m.role = 'owner' and m.is_active),
  1,
  'bootstrap creates one active owner membership'
);
select is(
  (select count(*)::int from public.accounts a join public.tenants t on t.id = a.tenant_id where t.slug = 'alpha-showroom'),
  33,
  'bootstrap seeds exactly the 33 Section 7.1 accounts'
);
select is(
  (select count(*)::int from public.accounts a join public.tenants t on t.id = a.tenant_id where t.slug = 'alpha-showroom' and a.system_key is not null),
  26,
  'bootstrap seeds all 26 stable system keys'
);
select is(
  (select a.code from public.accounts a join public.tenants t on t.id = a.tenant_id where t.slug = 'alpha-showroom' and a.system_key = 'cash_main'),
  '1110',
  'cash_main resolves independently of application hardcoding'
);
select ok(
  (select a.is_header from public.accounts a join public.tenants t on t.id = a.tenant_id where t.slug = 'alpha-showroom' and a.code = '1100'),
  'cash-equivalents parent is a header account'
);
select is(
  (select p.code from public.accounts a join public.accounts p on p.id = a.parent_id join public.tenants t on t.id = a.tenant_id where t.slug = 'alpha-showroom' and a.code = '1110'),
  '1100',
  'main cash account has the expected tenant-local parent'
);
select is((select count(*)::int from public.audit_log a join public.tenants t on t.id = a.tenant_id where t.slug = 'alpha-showroom' and a.action = 'tenant.bootstrap'), 1, 'bootstrap is audited');

select tests.authenticate_as('10000000-0000-0000-0000-000000000001');
select throws_ok(
  $$ select public.bootstrap_tenant('alpha-showroom', 'معرض مكرر') $$,
  '23505',
  null,
  'duplicate slug cannot bootstrap a second partial tenant'
);
select tests.reset_authentication();
select is((select count(*)::int from public.tenants where slug = 'alpha-showroom'), 1, 'failed duplicate leaves the original tenant only');

select * from finish();
rollback;
