begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(9);

select tests.create_user('71000000-0000-0000-0000-000000000001', 'vault-owner@example.com');
select tests.create_user('71000000-0000-0000-0000-000000000002', 'vault-manager@example.com');
select tests.authenticate_as('71000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('vault-tenant', 'Vault Tenant') $$, 'vault tenant bootstraps');
select lives_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'vault-tenant'), '71000000-0000-0000-0000-000000000002', 'manager', true) $$,
  'manager added'
);

-- Owner can create a secret reference
select lives_ok(
  $$ select public.manage_tenant_secret_ref(
    (select id from public.tenants where slug = 'vault-tenant'),
    'whatsapp',
    '11111111-1111-1111-1111-111111111111'
  ) $$,
  'owner creates whatsapp secret reference'
);

-- Owner can see the reference
select is(
  (select count(*)::int from public.tenant_secret_refs where tenant_id = (select id from public.tenants where slug = 'vault-tenant')),
  1,
  'owner sees secret reference'
);

-- One row per tenant/kind uniqueness
select throws_ok(
  $$ insert into public.tenant_secret_refs (tenant_id, kind, vault_secret_id, created_by)
     values ((select id from public.tenants where slug = 'vault-tenant'), 'whatsapp', gen_random_uuid(), auth.uid()) $$,
  '42501',
  null,
  'direct insert rejected - must use operation'
);

-- Owner can update reference (replaces)
select lives_ok(
  $$ select public.manage_tenant_secret_ref(
    (select id from public.tenants where slug = 'vault-tenant'),
    'whatsapp',
    '22222222-2222-2222-2222-222222222222'
  ) $$,
  'owner replaces whatsapp secret reference'
);

select is(
  (select vault_secret_id::text from public.tenant_secret_refs where tenant_id = (select id from public.tenants where slug = 'vault-tenant') and kind = 'whatsapp'),
  '22222222-2222-2222-2222-222222222222',
  'reference is updated to new value'
);

-- Manager cannot see secret references
select tests.reset_authentication();
select tests.authenticate_as('71000000-0000-0000-0000-000000000002');
select is(
  (select count(*)::int from public.tenant_secret_refs),
  0,
  'manager cannot see tenant secret references'
);

-- Manager cannot manage secret references
select throws_ok(
  $$ select public.manage_tenant_secret_ref(
    (select id from public.tenants where slug = 'vault-tenant'),
    'n8n',
    gen_random_uuid()
  ) $$,
  '42501',
  null,
  'manager cannot manage secret references'
);

select * from finish();
rollback;
