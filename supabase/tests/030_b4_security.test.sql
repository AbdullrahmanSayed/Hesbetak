begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc
select no_plan();

select tests.create_user('b45ec000-0000-0000-0000-000000000001', 'b4-security-owner@example.com');
select tests.create_user('b45ec000-0000-0000-0000-000000000002', 'b4-security-cashier@example.com');
select tests.create_user('b45ec000-0000-0000-0000-000000000003', 'b4-security-outsider@example.com');
select tests.authenticate_as('b45ec000-0000-0000-0000-000000000001');
select lives_ok($$select public.bootstrap_tenant('b4-security', 'B4 Security')$$, 'tenant bootstraps');
select lives_ok($$select public.manage_membership(
  (select id from public.tenants where slug='b4-security'),
  'b45ec000-0000-0000-0000-000000000002', 'cashier', true)$$, 'cashier is added');
select lives_ok($$select public.manage_supplier(
  (select id from public.tenants where slug='b4-security'), null,
  'مورد الأمان', '01012345678', null, null, true)$$, 'supplier is created');
select lives_ok($$select public.manage_cash_account(
  (select id from public.tenants where slug='b4-security'), null,
  'خزنة الأمان', 'cash', true)$$, 'cash account is created');
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b4-security'), null,
  'منتج مسلسل آمن', 'Safe serial', null, null, 'SAFE-S', null,
  'serial', 100000, 0, 0, true)$$, 'serial product is created');
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b4-security'), null,
  'منتج كمية آمن', 'Safe quantity', null, null, 'SAFE-Q', null,
  'quantity', 10000, 0, 0, true)$$, 'quantity product is created');
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b4-security'),
  'b45ec000-0000-0000-0000-000000000101',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b4-security')),
  (now() at time zone 'Africa/Cairo')::date, 'SEC-PI-S',
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-security') and tracking='serial'),
    'qty',2,'unit_cost',50000,'serials',jsonb_build_array('SAFE-1','SAFE-2'))),0,0,null)$$, 'serial inventory is purchased');
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b4-security'),
  'b45ec000-0000-0000-0000-000000000102',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b4-security')),
  (now() at time zone 'Africa/Cairo')::date, 'SEC-PI-Q',
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-security') and tracking='quantity'),
    'qty',3,'unit_cost',5000)),0,0,null)$$, 'quantity inventory is purchased');
select lives_ok($$select public.post_cash_sale(
  (select id from public.tenants where slug='b4-security'),
  'b45ec000-0000-0000-0000-000000000201',
  (now() at time zone 'Africa/Cairo')::date, null,
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-security') and tracking='serial'),
    'unit_id',(select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b4-security') and serial_no='SAFE-1'),
    'qty',1,'cash_price','100000','discount','0')),
  jsonb_build_array(jsonb_build_object(
    'cash_account_id',(select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-security')),
    'amount','100000')),'0')$$, 'security fixture sale posts');
create temporary table b4_security_context as
select id as tenant_id from public.tenants where slug='b4-security';

-- T20: cashier gets safe POS data but no cost/profit-bearing base rows.
select tests.authenticate_as('b45ec000-0000-0000-0000-000000000002');
select is((select count(*)::integer from public.pos_products where tenant_id=(select tenant_id from b4_security_context)), 2, 'T20 cashier sees safe POS products');
select is((select count(*)::integer from public.pos_inventory_units where tenant_id=(select tenant_id from b4_security_context)), 1, 'T20 cashier sees only available safe serial data');
select is((select count(*)::integer from public.sales_invoice_lines_no_cost where tenant_id=(select tenant_id from b4_security_context)), 1, 'T20 cashier sees the no-cost sales view');
select is((select count(*)::integer from public.sales_invoice_lines where tenant_id=(select tenant_id from b4_security_context)), 0, 'T20 cashier cannot read cost_snapshot from base sales lines');
select is((select count(*)::integer from public.inventory_units where tenant_id=(select tenant_id from b4_security_context)), 0, 'T20 cashier cannot read serial unit_cost');
select is((select count(*)::integer from public.stock_balances where tenant_id=(select tenant_id from b4_security_context)), 0, 'T20 cashier cannot read avg_cost');
select is((select count(*)::integer from public.stock_movements where tenant_id=(select tenant_id from b4_security_context)), 0, 'T20 cashier cannot read movement cost');
select is((select count(*)::integer from public.purchase_invoices where tenant_id=(select tenant_id from b4_security_context)), 0, 'T20 cashier cannot read purchase totals');
select is((select count(*)::integer from public.purchase_invoice_lines where tenant_id=(select tenant_id from b4_security_context)), 0, 'T20 cashier cannot read purchase unit_cost');
select is((select count(*)::integer from public.journal_lines where tenant_id=(select tenant_id from b4_security_context)), 0, 'T20 cashier cannot request COGS/profit ledger lines');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='sales_invoice_lines_no_cost' and column_name='cost_snapshot'), 'safe sales view has no cost column');
select ok(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='pos_inventory_units' and column_name='unit_cost'), 'safe serial view has no cost column');

select throws_ok($$insert into public.sales_invoices(
  tenant_id,doc_no,doc_date,kind,gross_total,discount_total,net_total,request_id,created_by)
  values ('00000000-0000-0000-0000-000000000000',1,current_date,'cash',1,0,1,gen_random_uuid(),auth.uid())$$,
  '42501', null, 'direct invoice insert is denied');

-- A known tenant id is retained before switching to a non-member, so this is a real isolation test.
select tests.authenticate_as('b45ec000-0000-0000-0000-000000000003');
select is((select count(*)::integer from public.sales_invoices where tenant_id=(select tenant_id from b4_security_context)), 0, 'cross-tenant invoice read returns zero rows');
select is((select count(*)::integer from public.pos_products where tenant_id=(select tenant_id from b4_security_context)), 0, 'cross-tenant POS view returns zero rows');
select throws_ok(
  format($sql$select public.post_cash_sale(
    %L::uuid, gen_random_uuid(), (now() at time zone 'Africa/Cairo')::date, null,
    '[]'::jsonb, '[]'::jsonb, '0')$sql$,
    (select tenant_id::text from b4_security_context)),
  '42501', 'لا تملك صلاحية البيع', 'cross-tenant sale RPC is denied');

select * from finish();
rollback;
