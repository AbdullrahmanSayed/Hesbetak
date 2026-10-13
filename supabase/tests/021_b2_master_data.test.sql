begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(21);

-- Setup users
select tests.create_user('80000000-0000-0000-0000-000000000001', 'b2-owner@example.com');
select tests.create_user('80000000-0000-0000-0000-000000000002', 'b2-manager@example.com');
select tests.create_user('80000000-0000-0000-0000-000000000003', 'b2-cashier@example.com');

-- Bootstrap tenant
select tests.authenticate_as('80000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('b2-test', 'B2 Test Tenant') $$, 'tenant bootstraps');

-- Verify bootstrap seeds categories and brands
select ok(
  (select count(*)::int from public.categories where tenant_id = (select id from public.tenants where slug = 'b2-test')) >= 6,
  'bootstrap seeds default categories'
);
select ok(
  (select count(*)::int from public.brands where tenant_id = (select id from public.tenants where slug = 'b2-test')) >= 12,
  'bootstrap seeds default brands'
);

-- Add manager and cashier
select lives_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'b2-test'), '80000000-0000-0000-0000-000000000002', 'manager', true) $$,
  'manager added'
);
select lives_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'b2-test'), '80000000-0000-0000-0000-000000000003', 'cashier', true) $$,
  'cashier added'
);

-- Categories (use unique names since bootstrap already seeds defaults)
select lives_ok(
  $$ select public.manage_category((select id from public.tenants where slug = 'b2-test'), null, 'أجهزة منزلية', 'Home Appliances', 10, true) $$,
  'owner creates category'
);

select tests.reset_authentication();
select tests.authenticate_as('80000000-0000-0000-0000-000000000002');
select lives_ok(
  $$ select public.manage_category((select id from public.tenants where slug = 'b2-test'), null, 'إلكترونيات', 'Electronics', 11, true) $$,
  'manager creates category'
);

select tests.reset_authentication();
select tests.authenticate_as('80000000-0000-0000-0000-000000000003');
select throws_ok(
  $$ select public.manage_category((select id from public.tenants where slug = 'b2-test'), null, 'شاشات', 'TVs', 3, true) $$,
  '42501',
  null,
  'cashier cannot create category'
);

-- Brands (use unique name since bootstrap already seeds defaults)
select tests.reset_authentication();
select tests.authenticate_as('80000000-0000-0000-0000-000000000001');
select lives_ok(
  $$ select public.manage_brand((select id from public.tenants where slug = 'b2-test'), null, 'Bosch', null, true) $$,
  'owner creates brand'
);

-- Products (use seeded category/brand)
select lives_ok(
  $$ select public.manage_product(
    (select id from public.tenants where slug = 'b2-test'),
    null,
    'ثلاجة شارب 18 قدم',
    'Sharp 18ft Refrigerator',
    (select id from public.categories where tenant_id = (select id from public.tenants where slug = 'b2-test') and name_ar = 'ثلاجات'),
    (select id from public.brands where tenant_id = (select id from public.tenants where slug = 'b2-test') and name = 'Sharp'),
    'SJ-48',
    '123456789',
    'serial',
    1500000,
    5,
    24,
    true
  ) $$,
  'owner creates product'
);

-- Customers
select lives_ok(
  $$ select public.manage_customer(
    (select id from public.tenants where slug = 'b2-test'),
    null,
    'أحمد محمد',
    '01012345678',
    null, null, 'القاهرة', null, null, null, null, null, null, null, false, true
  ) $$,
  'owner creates customer'
);

-- Phone validation
select throws_ok(
  $$ select public.manage_customer(
    (select id from public.tenants where slug = 'b2-test'),
    null,
    'Invalid Phone',
    '12345',
    null, null, null, null, null, null, null, null, null, null, false, true
  ) $$,
  '23514',
  null,
  'invalid phone rejected'
);

-- Suppliers
select lives_ok(
  $$ select public.manage_supplier((select id from public.tenants where slug = 'b2-test'), null, 'توكيل شارب', '0223456789', 'المهندسين', null, true) $$,
  'owner creates supplier'
);

-- Cash Accounts (creates GL account automatically)
select lives_ok(
  $$ select public.manage_cash_account((select id from public.tenants where slug = 'b2-test'), null, 'الخزنة الفرعية', 'cash', true) $$,
  'owner creates cash account'
);
select is(
  (select count(*)::int from public.accounts where tenant_id = (select id from public.tenants where slug = 'b2-test') and name_ar = 'الخزنة الفرعية'),
  1,
  'GL account created for cash account'
);

-- Expense Categories (creates GL account automatically)
select lives_ok(
  $$ select public.manage_expense_category((select id from public.tenants where slug = 'b2-test'), null, 'صيانة', 'Maintenance', true) $$,
  'owner creates expense category'
);
select is(
  (select count(*)::int from public.accounts where tenant_id = (select id from public.tenants where slug = 'b2-test') and name_ar = 'صيانة'),
  1,
  'GL account created for expense category'
);

-- Partners (creates 3 GL accounts)
select lives_ok(
  $$ select public.manage_partner((select id from public.tenants where slug = 'b2-test'), null, 'أحمد', 5000, true) $$,
  'owner creates partner with 50% share'
);
select is(
  (select count(*)::int from public.accounts where tenant_id = (select id from public.tenants where slug = 'b2-test') and name_ar like '%أحمد%'),
  3,
  '3 GL accounts created for partner'
);

-- Share validation
select throws_ok(
  $$ select public.manage_partner((select id from public.tenants where slug = 'b2-test'), null, 'محمد', 6000, true) $$,
  '23514',
  null,
  'partner share exceeding 100% rejected'
);

-- Plan Templates
select lives_ok(
  $$ select public.manage_plan_template((select id from public.tenants where slug = 'b2-test'), null, '12 شهر', 12, 2000, 2000, true) $$,
  'owner creates plan template'
);

select * from finish();
rollback;
