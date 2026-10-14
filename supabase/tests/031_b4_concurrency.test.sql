create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
\ir helpers/b1.inc

begin;
select tests.create_user('b4c00000-0000-0000-0000-000000000001', 'b4-concurrency-owner@example.com');
select tests.create_user('b4c00000-0000-0000-0000-000000000002', 'b4-concurrency-cashier-1@example.com');
select tests.create_user('b4c00000-0000-0000-0000-000000000003', 'b4-concurrency-cashier-2@example.com');
select tests.authenticate_as('b4c00000-0000-0000-0000-000000000001');
select public.bootstrap_tenant('b4-concurrency', 'B4 Concurrency');
select public.manage_membership(
  (select id from public.tenants where slug='b4-concurrency'),
  'b4c00000-0000-0000-0000-000000000002', 'cashier', true);
select public.manage_membership(
  (select id from public.tenants where slug='b4-concurrency'),
  'b4c00000-0000-0000-0000-000000000003', 'cashier', true);
select public.manage_supplier(
  (select id from public.tenants where slug='b4-concurrency'), null,
  'مورد التزامن', '01012345678', null, null, true);
select public.manage_cash_account(
  (select id from public.tenants where slug='b4-concurrency'), null,
  'خزنة التزامن', 'cash', true);
select public.manage_product(
  (select id from public.tenants where slug='b4-concurrency'), null,
  'ثلاجة التزامن', 'Concurrency fridge', null, null, 'CON-1', null,
  'serial', 100000, 0, 0, true);
select public.post_purchase_invoice(
  (select id from public.tenants where slug='b4-concurrency'),
  'b4c00000-0000-0000-0000-000000000101',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b4-concurrency')),
  (now() at time zone 'Africa/Cairo')::date, 'CON-PI',
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-concurrency')),
    'qty',1,'unit_cost',50000,'serials',jsonb_build_array('CON-SN-1'))),0,0,null);
commit;

begin;
create or replace function tests.run_b4_concurrent_sale(
  p_user_id uuid,
  p_tenant_id uuid,
  p_request_id uuid,
  p_product_id uuid,
  p_unit_id uuid,
  p_cash_account_id uuid
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user_id::text, false);
  perform set_config('request.jwt.claim.role', 'authenticated', false);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id::text, 'role', 'authenticated')::text,
    false
  );
  begin
    perform public.post_cash_sale(
      p_tenant_id, p_request_id, (now() at time zone 'Africa/Cairo')::date, null,
      jsonb_build_array(jsonb_build_object(
        'product_id',p_product_id,'unit_id',p_unit_id,
        'qty',1,'cash_price','100000','discount','0')),
      jsonb_build_array(jsonb_build_object(
        'cash_account_id',p_cash_account_id,'amount','100000')),
      '0'
    );
    perform pg_sleep(1);
    return 'success';
  exception when others then
    return sqlstate || ':' || sqlerrm;
  end;
end;
$$;

create temporary table b4_concurrency_context as
select t.id as tenant_id,
       (select id from public.products where tenant_id=t.id) as product_id,
       (select id from public.inventory_units where tenant_id=t.id) as unit_id,
       (select id from public.cash_accounts where tenant_id=t.id) as cash_account_id
from public.tenants t where t.slug='b4-concurrency';
commit;

select extensions.dblink_connect('b4_sale_1', 'host=host.docker.internal port=54322 dbname=' || current_database() || ' user=supabase_admin password=postgres');
select extensions.dblink_connect('b4_sale_2', 'host=host.docker.internal port=54322 dbname=' || current_database() || ' user=supabase_admin password=postgres');
select extensions.dblink_send_query('b4_sale_1', format(
  'select tests.run_b4_concurrent_sale(%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::uuid)',
  'b4c00000-0000-0000-0000-000000000002', (select tenant_id::text from b4_concurrency_context),
  'b4c00000-0000-0000-0000-000000000201',
  (select product_id::text from b4_concurrency_context),
  (select unit_id::text from b4_concurrency_context),
  (select cash_account_id::text from b4_concurrency_context)
));
select extensions.dblink_send_query('b4_sale_2', format(
  'select tests.run_b4_concurrent_sale(%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::uuid)',
  'b4c00000-0000-0000-0000-000000000003', (select tenant_id::text from b4_concurrency_context),
  'b4c00000-0000-0000-0000-000000000202',
  (select product_id::text from b4_concurrency_context),
  (select unit_id::text from b4_concurrency_context),
  (select cash_account_id::text from b4_concurrency_context)
));

create temporary table b4_concurrency_outcomes(outcome text);
insert into b4_concurrency_outcomes select outcome from extensions.dblink_get_result('b4_sale_1') as t(outcome text);
insert into b4_concurrency_outcomes select outcome from extensions.dblink_get_result('b4_sale_2') as t(outcome text);
select extensions.dblink_disconnect('b4_sale_1');
select extensions.dblink_disconnect('b4_sale_2');

select plan(4);
select is((select count(*)::integer from b4_concurrency_outcomes where outcome='success'), 1, 'T18 exactly one concurrent cashier succeeds');
select is((select count(*)::integer from b4_concurrency_outcomes where outcome like '40001:%'), 1, 'T18 losing cashier receives serialization conflict');
select is((select count(*)::integer from public.sales_invoices where tenant_id=(select tenant_id from b4_concurrency_context)), 1, 'T18 creates exactly one invoice');
select is((select status from public.inventory_units where id=(select unit_id from b4_concurrency_context)), 'sold'::public.unit_status, 'T18 serial ends sold exactly once');
select * from finish();

-- This suite commits only to make fixtures visible to dblink sessions, then removes every fixture.
reset role;
create temporary table b4_cleanup_tenant(id uuid);
insert into b4_cleanup_tenant select tenant_id from b4_concurrency_context;
set session_replication_role = replica;
do $$
declare
  v_table record;
  v_tenant_id uuid := (select id from b4_cleanup_tenant);
begin
  for v_table in
    select c.table_schema, c.table_name
    from information_schema.columns c
    join information_schema.tables t
      on t.table_schema = c.table_schema and t.table_name = c.table_name
    where c.table_schema = 'public' and c.column_name = 'tenant_id'
      and t.table_type = 'BASE TABLE'
    group by c.table_schema, c.table_name
  loop
    execute format('delete from %I.%I where tenant_id = %L::uuid', v_table.table_schema, v_table.table_name, v_tenant_id);
  end loop;
  delete from public.tenants where id = v_tenant_id;
end;
$$;
delete from auth.users where id in (
  'b4c00000-0000-0000-0000-000000000001',
  'b4c00000-0000-0000-0000-000000000002',
  'b4c00000-0000-0000-0000-000000000003'
);
set session_replication_role = origin;
drop schema tests cascade;
