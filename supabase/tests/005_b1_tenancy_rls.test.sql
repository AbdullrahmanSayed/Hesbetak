begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(11);

select tests.create_user('20000000-0000-0000-0000-000000000001', 'owner-a@example.com');
select tests.create_user('20000000-0000-0000-0000-000000000002', 'owner-b@example.com');
select tests.create_user('20000000-0000-0000-0000-000000000003', 'outsider@example.com');
select tests.create_user('20000000-0000-0000-0000-000000000004', 'inactive@example.com');

select tests.authenticate_as('20000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('tenant-a', 'Tenant A') $$, 'owner A bootstraps tenant A');
select tests.reset_authentication();
select tests.authenticate_as('20000000-0000-0000-0000-000000000002');
select lives_ok($$ select public.bootstrap_tenant('tenant-b', 'Tenant B') $$, 'owner B bootstraps tenant B');
select tests.reset_authentication();

insert into public.memberships (tenant_id, user_id, role, is_active, created_by)
select id, '20000000-0000-0000-0000-000000000004', 'accountant', false, '20000000-0000-0000-0000-000000000001'
from public.tenants where slug = 'tenant-a';

select tests.authenticate_as('20000000-0000-0000-0000-000000000001');
select is((select count(*)::int from public.tenants), 1, 'owner sees only own tenant');
select is((select count(*)::int from public.accounts), 33, 'owner sees only own chart');
select is((select count(*)::int from public.memberships), 2, 'owner sees own active and inactive memberships');
select tests.reset_authentication();

select tests.authenticate_as('20000000-0000-0000-0000-000000000002');
select is((select count(*)::int from public.tenants), 1, 'other owner sees only tenant B');
select is((select count(*)::int from public.accounts), 33, 'other owner cannot see tenant A chart');
select tests.reset_authentication();

select tests.authenticate_as('20000000-0000-0000-0000-000000000003');
select is((select count(*)::int from public.tenants), 0, 'non-member sees no tenants');
select is((select count(*)::int from public.accounts), 0, 'non-member sees no accounts');
select tests.reset_authentication();

select tests.authenticate_as('20000000-0000-0000-0000-000000000004');
select is((select count(*)::int from public.tenants), 0, 'inactive member sees no tenant');
select is((select count(*)::int from public.memberships), 0, 'inactive member cannot use membership to inspect rows');

select * from finish();
rollback;
