begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc
select no_plan();

--------------------------------------------------------------------------------
-- T25: Installment sale with require_customer_id_images ON and no ID images
-- posting rejected with Arabic error; nothing written
--------------------------------------------------------------------------------

-- Setup tenant with require_customer_id_images = true
select tests.create_user('b5250000-0000-0000-0000-000000000001', 'b5t25-owner@example.com');
select tests.authenticate_as('b5250000-0000-0000-0000-000000000001');
select lives_ok($$select public.bootstrap_tenant('b5-t25-test', 'B5 T25 Attachment Test')$$, 'tenant bootstraps');

-- Enable require_customer_id_images (use service role)
select tests.authenticate_as_service_role();
update public.tenants
set settings = jsonb_build_object('require_customer_id_images', true)
where slug = 'b5-t25-test';
select tests.authenticate_as('b5250000-0000-0000-0000-000000000001');

-- Create supplier
select lives_ok($$select public.manage_supplier(
  (select id from public.tenants where slug='b5-t25-test'), null,
  'مورد', '01012345678', null, null, true)$$, 'supplier created');

-- Create cash account
select lives_ok($$select public.manage_cash_account(
  (select id from public.tenants where slug='b5-t25-test'), null,
  'الخزنة', 'cash', true)$$, 'cash account created');

-- Create product
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b5-t25-test'), null,
  'ثلاجة', 'Fridge', null, null, 'FR-T25', null,
  'serial', 2000000, 0, 24, true)$$, 'product created');

-- Create customer (no ID images)
select lives_ok($$select public.manage_customer(
  (select id from public.tenants where slug='b5-t25-test'),
  null,
  'عميل بدون بطاقة', '01234567890', null, null,
  'القاهرة', null, null,
  null, null, null, null, null, false, true)$$, 'customer created');

-- Purchase inventory
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b5-t25-test'),
  'b5250000-0000-0000-0000-000000000101',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
  (now() at time zone 'Africa/Cairo')::date, 'PO-1',
  jsonb_build_array(jsonb_build_object(
    'product_id', (select id from public.products where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
    'qty', 1, 'unit_cost', 1600000, 'serials', jsonb_build_array('T25-SN-001')
  )), 0, 0, null)$$, 'inventory purchased');

-- T25: Attempt to post installment sale without ID images should fail
select throws_ok(
  $$select public.post_installment_sale(
    (select id from public.tenants where slug='b5-t25-test'),
    'b5250000-0000-0000-0000-000000000201',
    (now() at time zone 'Africa/Cairo')::date,
    (select id from public.customers where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
    jsonb_build_array(jsonb_build_object(
      'product_id', (select id from public.products where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
      'unit_id', (select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b5-t25-test') and serial_no='T25-SN-001'),
      'qty', 1, 'cash_price', '2000000', 'discount', '0'
    )),
    '500000',
    (select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
    10, 4000, null, 100, null, null
  )$$,
  '22023',
  'يجب رفع صورة البطاقة الشخصية للعميل (أمام وخلف)',
  'T25 sale without ID images rejected'
);

-- Verify nothing was written
select is(
  (select count(*)::integer from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
  0, 'T25 no contract created'
);
select is(
  (select count(*)::integer from public.installments where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
  0, 'T25 no installments created'
);
select is(
  (select status from public.inventory_units where serial_no='T25-SN-001'),
  'in_stock'::public.unit_status, 'T25 unit still in_stock'
);

--------------------------------------------------------------------------------
-- Now test with images attached to customer
--------------------------------------------------------------------------------

-- Simulate uploading ID images directly to customer (use service role)
select tests.authenticate_as_service_role();
insert into public.attachments (
  tenant_id, owner_type, owner_id, kind, bucket, object_path, mime_type, size_bytes,
  status, created_by
) values
(
  (select id from public.tenants where slug='b5-t25-test'),
  'customer',
  (select id from public.customers where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
  'national_id_front',
  'customer-documents',
  'test/front.webp',
  'image/webp',
  10000,
  'active',
  'b5250000-0000-0000-0000-000000000001'
),
(
  (select id from public.tenants where slug='b5-t25-test'),
  'customer',
  (select id from public.customers where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
  'national_id_back',
  'customer-documents',
  'test/back.webp',
  'image/webp',
  10000,
  'active',
  'b5250000-0000-0000-0000-000000000001'
);
select tests.authenticate_as('b5250000-0000-0000-0000-000000000001');

-- Now the sale should succeed
select lives_ok(
  $$select public.post_installment_sale(
    (select id from public.tenants where slug='b5-t25-test'),
    'b5250000-0000-0000-0000-000000000202',
    (now() at time zone 'Africa/Cairo')::date,
    (select id from public.customers where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
    jsonb_build_array(jsonb_build_object(
      'product_id', (select id from public.products where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
      'unit_id', (select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b5-t25-test') and serial_no='T25-SN-001'),
      'qty', 1, 'cash_price', '2000000', 'discount', '0'
    )),
    '500000',
    (select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
    10, 4000, null, 100, null, null
  )$$,
  'Sale with ID images succeeds'
);

-- Verify contract created
select is(
  (select count(*)::integer from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-t25-test')),
  1, 'Contract created after ID images added'
);

--------------------------------------------------------------------------------
-- Test: Disable requirement and sale should succeed without images
--------------------------------------------------------------------------------

-- Create another tenant with requirement OFF
select tests.reset_authentication();
select tests.create_user('b5250000-0000-0000-0000-000000000002', 'b5t25-owner2@example.com');
select tests.authenticate_as('b5250000-0000-0000-0000-000000000002');
select lives_ok($$select public.bootstrap_tenant('b5-t25-off', 'B5 T25 Disabled Test')$$, 'tenant 2 bootstraps');

-- Explicitly disable requirement (use service role)
select tests.authenticate_as_service_role();
update public.tenants
set settings = jsonb_build_object('require_customer_id_images', false)
where slug = 'b5-t25-off';
select tests.authenticate_as('b5250000-0000-0000-0000-000000000002');

-- Create supplier
select lives_ok($$select public.manage_supplier(
  (select id from public.tenants where slug='b5-t25-off'), null,
  'مورد', '01012345678', null, null, true)$$, 'supplier 2 created');

-- Create cash account
select lives_ok($$select public.manage_cash_account(
  (select id from public.tenants where slug='b5-t25-off'), null,
  'الخزنة', 'cash', true)$$, 'cash account 2 created');

-- Create product
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b5-t25-off'), null,
  'ثلاجة', 'Fridge', null, null, 'FR-OFF', null,
  'serial', 2000000, 0, 24, true)$$, 'product 2 created');

-- Create customer (no ID images)
select lives_ok($$select public.manage_customer(
  (select id from public.tenants where slug='b5-t25-off'),
  null,
  'عميل بدون بطاقة', '01234567890', null, null,
  'القاهرة', null, null,
  null, null, null, null, null, false, true)$$, 'customer 2 created');

-- Purchase inventory
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b5-t25-off'),
  'b5250000-0000-0000-0000-000000000301',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b5-t25-off')),
  (now() at time zone 'Africa/Cairo')::date, 'PO-1',
  jsonb_build_array(jsonb_build_object(
    'product_id', (select id from public.products where tenant_id=(select id from public.tenants where slug='b5-t25-off')),
    'qty', 1, 'unit_cost', 1600000, 'serials', jsonb_build_array('OFF-SN-001')
  )), 0, 0, null)$$, 'inventory 2 purchased');

-- Sale should succeed without ID images when requirement is OFF
select lives_ok(
  $$select public.post_installment_sale(
    (select id from public.tenants where slug='b5-t25-off'),
    'b5250000-0000-0000-0000-000000000401',
    (now() at time zone 'Africa/Cairo')::date,
    (select id from public.customers where tenant_id=(select id from public.tenants where slug='b5-t25-off')),
    jsonb_build_array(jsonb_build_object(
      'product_id', (select id from public.products where tenant_id=(select id from public.tenants where slug='b5-t25-off')),
      'unit_id', (select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b5-t25-off') and serial_no='OFF-SN-001'),
      'qty', 1, 'cash_price', '2000000', 'discount', '0'
    )),
    '500000',
    (select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b5-t25-off')),
    10, 4000, null, 100, null, null
  )$$,
  'Sale succeeds when ID images not required'
);

select * from finish();
rollback;
