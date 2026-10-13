begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(16);

-- Setup users
select tests.create_user('90000000-0000-0000-0000-000000000001', 'b3-owner@example.com');
select tests.create_user('90000000-0000-0000-0000-000000000002', 'b3-manager@example.com');
select tests.create_user('90000000-0000-0000-0000-000000000003', 'b3-cashier@example.com');

-- Bootstrap tenant
select tests.authenticate_as('90000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('b3-test', 'B3 Test Tenant') $$, 'tenant bootstraps');

-- Add manager membership
select lives_ok(
  $$ select public.manage_membership(
    (select id from public.tenants where slug = 'b3-test'),
    '90000000-0000-0000-0000-000000000002',
    'manager', true
  ) $$,
  'add manager'
);

-- Create supplier
select lives_ok(
  $$ select public.manage_supplier(
    (select id from public.tenants where slug = 'b3-test'),
    null, 'مورد تجريبي', '01012345678', 'العنوان', null, true
  ) $$,
  'create supplier'
);

-- Create cash account
select lives_ok(
  $$ select public.manage_cash_account(
    (select id from public.tenants where slug = 'b3-test'),
    null, 'الخزنة الرئيسية', 'cash', true
  ) $$,
  'create cash account'
);

-- Create serial product (refrigerator)
select lives_ok(
  $$ select public.manage_product(
    (select id from public.tenants where slug = 'b3-test'),
    null, 'ثلاجة شارب 18 قدم', 'Sharp Refrigerator 18ft',
    (select id from public.categories where tenant_id = (select id from public.tenants where slug = 'b3-test') and name_ar = 'ثلاجات'),
    (select id from public.brands where tenant_id = (select id from public.tenants where slug = 'b3-test') and name = 'Sharp'),
    'SJ-18', null, 'serial', 1600000, 0, 24, true
  ) $$,
  'create serial product'
);

-- Create quantity product (accessory)
select lives_ok(
  $$ select public.manage_product(
    (select id from public.tenants where slug = 'b3-test'),
    null, 'ريموت كنترول', 'Remote Control',
    null, null, null, null, 'quantity', 5000, 0, 0, true
  ) $$,
  'create quantity product'
);

-- Post purchase invoice with serial product
select lives_ok(
  $$ select public.post_purchase_invoice(
    (select id from public.tenants where slug = 'b3-test'),
    'a0000001-0000-0000-0000-000000000001'::uuid,
    (select id from public.suppliers where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1),
    current_date,
    'SUP-INV-001',
    jsonb_build_array(
      jsonb_build_object(
        'product_id', (select id from public.products where tenant_id = (select id from public.tenants where slug = 'b3-test') and name_ar = 'ثلاجة شارب 18 قدم'),
        'qty', 2,
        'unit_cost', 1200000,
        'serials', jsonb_build_array('SN001', 'SN002')
      )
    ),
    0,
    1200000,
    (select id from public.cash_accounts where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1)
  ) $$,
  'post purchase invoice with serials'
);

-- Verify inventory units created
select is(
  (select count(*)::int from public.inventory_units 
   where tenant_id = (select id from public.tenants where slug = 'b3-test') 
   and status = 'in_stock'),
  2,
  'two inventory units created'
);

-- Verify stock movement
select is(
  (select count(*)::int from public.stock_movements 
   where tenant_id = (select id from public.tenants where slug = 'b3-test') 
   and movement_type = 'purchase'),
  2,
  'two stock movements created for serial purchase'
);

-- Post purchase with quantity product
select lives_ok(
  $$ select public.post_purchase_invoice(
    (select id from public.tenants where slug = 'b3-test'),
    'a0000002-0000-0000-0000-000000000001'::uuid,
    (select id from public.suppliers where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1),
    current_date,
    'SUP-INV-002',
    jsonb_build_array(
      jsonb_build_object(
        'product_id', (select id from public.products where tenant_id = (select id from public.tenants where slug = 'b3-test') and name_ar = 'ريموت كنترول'),
        'qty', 10,
        'unit_cost', 4000
      )
    ),
    0,
    40000,
    (select id from public.cash_accounts where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1)
  ) $$,
  'post purchase invoice with quantity product'
);

-- Verify stock balance
select is(
  (select qty from public.stock_balances 
   where tenant_id = (select id from public.tenants where slug = 'b3-test')
   and product_id = (select id from public.products where tenant_id = (select id from public.tenants where slug = 'b3-test') and name_ar = 'ريموت كنترول')),
  10,
  'stock balance qty is 10'
);

select is(
  (select avg_cost from public.stock_balances 
   where tenant_id = (select id from public.tenants where slug = 'b3-test')
   and product_id = (select id from public.products where tenant_id = (select id from public.tenants where slug = 'b3-test') and name_ar = 'ريموت كنترول')),
  4000::bigint,
  'avg_cost is 4000'
);

-- T13: Purchase on credit + supplier payment
-- First purchase on credit (no payment)
select lives_ok(
  $$ select public.post_purchase_invoice(
    (select id from public.tenants where slug = 'b3-test'),
    'a0000003-0000-0000-0000-000000000001'::uuid,
    (select id from public.suppliers where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1),
    current_date,
    'SUP-INV-003',
    jsonb_build_array(
      jsonb_build_object(
        'product_id', (select id from public.products where tenant_id = (select id from public.tenants where slug = 'b3-test') and name_ar = 'ريموت كنترول'),
        'qty', 5,
        'unit_cost', 4500
      )
    ),
    0,
    0,
    null
  ) $$,
  'T13: purchase on credit'
);

-- Verify weighted average recalculated: (10*4000 + 5*4500) / 15 = 62500/15 = 4166
select is(
  (select avg_cost from public.stock_balances 
   where tenant_id = (select id from public.tenants where slug = 'b3-test')
   and product_id = (select id from public.products where tenant_id = (select id from public.tenants where slug = 'b3-test') and name_ar = 'ريموت كنترول')),
  4166::bigint,
  'T13: weighted avg recalculated correctly'
);

-- Supplier payment
select lives_ok(
  $$ select public.post_supplier_payment(
    (select id from public.tenants where slug = 'b3-test'),
    'b0000001-0000-0000-0000-000000000001'::uuid,
    (select id from public.suppliers where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1),
    current_date,
    (select id from public.cash_accounts where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1),
    22500,
    'سداد فاتورة 003'
  ) $$,
  'T13: post supplier payment'
);

-- Idempotency test (same request_id, same payload → same result)
select is(
  (select (public.post_supplier_payment(
    (select id from public.tenants where slug = 'b3-test'),
    'b0000001-0000-0000-0000-000000000001'::uuid,
    (select id from public.suppliers where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1),
    current_date,
    (select id from public.cash_accounts where tenant_id = (select id from public.tenants where slug = 'b3-test') limit 1),
    22500,
    'سداد فاتورة 003'
  ))->>'doc_no')::bigint,
  1::bigint,
  'idempotent supplier payment returns same doc_no'
);

select * from finish();
rollback;
