begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select plan(15);

-- Setup all users at the beginning (before any authenticate_as)
select tests.create_user('81000000-0000-0000-0000-000000000001', 'attach-owner@example.com');
select tests.create_user('81000000-0000-0000-0000-000000000002', 'attach-manager@example.com');
select tests.create_user('81000000-0000-0000-0000-000000000003', 'attach-cashier@example.com');
select tests.create_user('81000000-0000-0000-0000-000000000099', 'other-owner@example.com');

select tests.authenticate_as('81000000-0000-0000-0000-000000000001');
select lives_ok($$ select public.bootstrap_tenant('attach-test', 'Attachment Test') $$, 'tenant bootstraps');

select lives_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'attach-test'), '81000000-0000-0000-0000-000000000002', 'manager', true) $$,
  'manager added'
);
select lives_ok(
  $$ select public.manage_membership((select id from public.tenants where slug = 'attach-test'), '81000000-0000-0000-0000-000000000003', 'cashier', true) $$,
  'cashier added'
);

-- Create a customer for attachment target
select lives_ok(
  $$ select public.manage_customer(
    (select id from public.tenants where slug = 'attach-test'),
    null, 'Test Customer', '01012345678',
    null, null, null, null, null, null, null, null, null, null, false, true
  ) $$,
  'customer created'
);

-- T26: Cashier uploads customer ID, cannot get URL
select tests.reset_authentication();
select tests.authenticate_as('81000000-0000-0000-0000-000000000003');

-- Cashier CAN upload customer attachments
select lives_ok(
  $$ select public.register_attachment(
    (select id from public.tenants where slug = 'attach-test'),
    'customer',
    'national_id_front',
    gen_random_uuid(),
    'customer-documents',
    'test/path/image.webp',
    'image/webp',
    50000,
    'id_front.jpg'
  ) $$,
  'T26: cashier registers customer attachment'
);

-- Cashier CANNOT view customer attachments (only owner/manager can)
-- First, make it active by attaching to document
select tests.reset_authentication();
select tests.authenticate_as('81000000-0000-0000-0000-000000000001');

-- Owner attaches to customer
select lives_ok(
  $$ select public.attach_to_document(
    (select id from public.tenants where slug = 'attach-test'),
    (select id from public.attachments where tenant_id = (select id from public.tenants where slug = 'attach-test') limit 1),
    (select id from public.customers where tenant_id = (select id from public.tenants where slug = 'attach-test') limit 1)
  ) $$,
  'owner attaches to customer'
);

-- Now cashier tries to view
select tests.reset_authentication();
select tests.authenticate_as('81000000-0000-0000-0000-000000000003');

select throws_ok(
  $$ select public.get_attachment_url(
    (select id from public.tenants where slug = 'attach-test'),
    (select id from public.attachments where tenant_id = (select id from public.tenants where slug = 'attach-test') limit 1)
  ) $$,
  '42501',
  null,
  'T26: cashier cannot get attachment URL'
);

-- T27: Cross-tenant attachment access denied
select tests.reset_authentication();
select tests.authenticate_as('81000000-0000-0000-0000-000000000099');
select lives_ok($$ select public.bootstrap_tenant('other-tenant', 'Other Tenant') $$, 'other tenant bootstraps');

-- Try to access attach-test's attachment from other-tenant
select throws_ok(
  $$ select public.get_attachment_url(
    (select id from public.tenants where slug = 'attach-test'),
    (select id from public.attachments where tenant_id = (select id from public.tenants where slug = 'attach-test') limit 1)
  ) $$,
  '42501',
  null,
  'T27: cross-tenant attachment access denied'
);

-- T28: Owner views attachment, URL works, audit logged
select tests.reset_authentication();
select tests.authenticate_as('81000000-0000-0000-0000-000000000001');

select lives_ok(
  $$ select public.get_attachment_url(
    (select id from public.tenants where slug = 'attach-test'),
    (select id from public.attachments where tenant_id = (select id from public.tenants where slug = 'attach-test') limit 1)
  ) $$,
  'T28: owner gets attachment URL'
);

select is(
  (select count(*)::int from public.audit_log where tenant_id = (select id from public.tenants where slug = 'attach-test') and action = 'attachment.viewed'),
  1,
  'T28: attachment view is audited'
);

-- T29: Attachment status flow (pending → active → superseded)
select lives_ok(
  $$ select public.supersede_attachment(
    (select id from public.tenants where slug = 'attach-test'),
    (select id from public.attachments where tenant_id = (select id from public.tenants where slug = 'attach-test') limit 1),
    'Replaced with better image'
  ) $$,
  'T29: owner supersedes attachment'
);

select is(
  (select status::text from public.attachments where tenant_id = (select id from public.tenants where slug = 'attach-test') limit 1),
  'superseded',
  'T29: attachment status is superseded'
);

-- T30: Pending attachments cleanup (mock by checking old pending)
-- Create a pending attachment
select lives_ok(
  $$ select public.register_attachment(
    (select id from public.tenants where slug = 'attach-test'),
    'expense',
    'receipt',
    gen_random_uuid(),
    'business-documents',
    'test/pending/receipt.webp',
    'image/webp',
    30000,
    'receipt.jpg'
  ) $$,
  'T30: create pending attachment'
);

-- In production, a cleanup job would delete pending > 24h
-- Here we just verify the index exists for efficient cleanup
select has_index('public', 'attachments', 'attachments_pending_cleanup_idx', 'T30: cleanup index exists');

select * from finish();
rollback;
