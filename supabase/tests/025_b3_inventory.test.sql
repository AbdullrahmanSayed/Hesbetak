begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(12);

-- Setup
select tests.create_user('91000000-0000-0000-0000-000000000001', 'inv-owner@example.com');
select tests.authenticate_as('91000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('inv-test', 'Inventory Test') $$, 'tenant bootstraps');

-- Create supplier
select lives_ok(
  $$ select public.manage_supplier(
    (select id from public.tenants where slug = 'inv-test'),
    null, 'مورد', '01098765432', null, null, true
  ) $$,
  'create supplier'
);

-- Create cash account
select lives_ok(
  $$ select public.manage_cash_account(
    (select id from public.tenants where slug = 'inv-test'),
    null, 'خزنة', 'cash', true
  ) $$,
  'create cash account'
);

-- Create quantity product
select lives_ok(
  $$ select public.manage_product(
    (select id from public.tenants where slug = 'inv-test'),
    null, 'كابل HDMI', 'HDMI Cable', null, null, null, null, 'quantity', 2000, 0, 0, true
  ) $$,
  'create quantity product'
);

-- T14: Weighted average test
-- Purchase 1: 20 units @ 1000
select lives_ok(
  $$ select public.post_purchase_invoice(
    (select id from public.tenants where slug = 'inv-test'),
    'c0000001-0000-0000-0000-000000000001'::uuid,
    (select id from public.suppliers where tenant_id = (select id from public.tenants where slug = 'inv-test') limit 1),
    current_date,
    null,
    jsonb_build_array(jsonb_build_object(
      'product_id', (select id from public.products where tenant_id = (select id from public.tenants where slug = 'inv-test') and name_ar = 'كابل HDMI'),
      'qty', 20,
      'unit_cost', 1000
    )),
    0, 20000,
    (select id from public.cash_accounts where tenant_id = (select id from public.tenants where slug = 'inv-test') limit 1)
  ) $$,
  'T14: purchase 20 @ 1000'
);

select is(
  (select avg_cost from public.stock_balances 
   where tenant_id = (select id from public.tenants where slug = 'inv-test')
   and product_id = (select id from public.products where tenant_id = (select id from public.tenants where slug = 'inv-test') and name_ar = 'كابل HDMI')),
  1000::bigint,
  'avg_cost is 1000 after first purchase'
);

-- Purchase 2: 10 units @ 1300
select lives_ok(
  $$ select public.post_purchase_invoice(
    (select id from public.tenants where slug = 'inv-test'),
    'c0000002-0000-0000-0000-000000000001'::uuid,
    (select id from public.suppliers where tenant_id = (select id from public.tenants where slug = 'inv-test') limit 1),
    current_date,
    null,
    jsonb_build_array(jsonb_build_object(
      'product_id', (select id from public.products where tenant_id = (select id from public.tenants where slug = 'inv-test') and name_ar = 'كابل HDMI'),
      'qty', 10,
      'unit_cost', 1300
    )),
    0, 13000,
    (select id from public.cash_accounts where tenant_id = (select id from public.tenants where slug = 'inv-test') limit 1)
  ) $$,
  'T14: purchase 10 @ 1300'
);

-- New avg = (20*1000 + 10*1300) / 30 = 33000/30 = 1100
select is(
  (select avg_cost from public.stock_balances 
   where tenant_id = (select id from public.tenants where slug = 'inv-test')
   and product_id = (select id from public.products where tenant_id = (select id from public.tenants where slug = 'inv-test') and name_ar = 'كابل HDMI')),
  1100::bigint,
  'T14: weighted avg = (20*1000+10*1300)/30 = 1100'
);

select is(
  (select qty from public.stock_balances 
   where tenant_id = (select id from public.tenants where slug = 'inv-test')
   and product_id = (select id from public.products where tenant_id = (select id from public.tenants where slug = 'inv-test') and name_ar = 'كابل HDMI')),
  30,
  'T14: qty is 30'
);

-- Inventory adjustment (add 5 units found)
select lives_ok(
  $$ select public.post_inventory_adjustment(
    (select id from public.tenants where slug = 'inv-test'),
    'd0000001-0000-0000-0000-000000000001'::uuid,
    current_date,
    'جرد: وجدنا 5 كابلات إضافية',
    jsonb_build_array(jsonb_build_object(
      'product_id', (select id from public.products where tenant_id = (select id from public.tenants where slug = 'inv-test') and name_ar = 'كابل HDMI'),
      'qty_change', 5,
      'cost', 1100
    ))
  ) $$,
  'post positive inventory adjustment'
);

-- New qty should be 35
select is(
  (select qty from public.stock_balances 
   where tenant_id = (select id from public.tenants where slug = 'inv-test')
   and product_id = (select id from public.products where tenant_id = (select id from public.tenants where slug = 'inv-test') and name_ar = 'كابل HDMI')),
  35,
  'qty is 35 after positive adjustment'
);

-- Verify stock movements
select is(
  (select count(*)::int from public.stock_movements 
   where tenant_id = (select id from public.tenants where slug = 'inv-test')),
  3,
  'three stock movements recorded (2 purchases + 1 adjustment)'
);

select * from finish();
rollback;
