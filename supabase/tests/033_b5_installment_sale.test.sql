begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc
select no_plan();

-- Setup tenant and data
select tests.create_user('b5000000-0000-0000-0000-000000000001', 'b5-owner@example.com');
select tests.create_user('b5000000-0000-0000-0000-000000000002', 'b5-cashier@example.com');
select tests.authenticate_as('b5000000-0000-0000-0000-000000000001');
select lives_ok($$select public.bootstrap_tenant('b5-installment', 'B5 Installment Test')$$, 'tenant bootstraps');

-- Add cashier
select lives_ok($$select public.manage_membership(
  (select id from public.tenants where slug='b5-installment'),
  'b5000000-0000-0000-0000-000000000002', 'cashier', true)$$, 'cashier added');

-- Create supplier
select lives_ok($$select public.manage_supplier(
  (select id from public.tenants where slug='b5-installment'), null,
  'مورد تقسيط', '01012345678', null, null, true)$$, 'supplier created');

-- Create cash account
select lives_ok($$select public.manage_cash_account(
  (select id from public.tenants where slug='b5-installment'), null,
  'الخزنة', 'cash', true)$$, 'cash account created');

-- Create serial product (fridge)
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b5-installment'), null,
  'ثلاجة تقسيط', 'Installment fridge', null, null, 'FR-INST', null,
  'serial', 2000000, 0, 24, true)$$, 'serial product created');

-- Create customer with phone and address (required for installment)
select lives_ok($$select public.manage_customer(
  (select id from public.tenants where slug='b5-installment'),
  null,
  'عميل تقسيط', '01234567890', null, null,
  'القاهرة - مصر الجديدة', null, null,
  null, null, null, null, null, false, true)$$, 'customer with address created');

-- Disable attachment requirement for T03 test (T25 tests this separately)
select tests.authenticate_as_service_role();
update public.tenants set settings = jsonb_build_object('require_customer_id_images', false) where slug = 'b5-installment';
select tests.authenticate_as('b5000000-0000-0000-0000-000000000001');

-- Purchase inventory (cost 16,000)
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b5-installment'),
  'b5000000-0000-0000-0000-000000000101',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b5-installment')),
  (now() at time zone 'Africa/Cairo')::date, 'PO-1',
  jsonb_build_array(jsonb_build_object(
    'product_id', (select id from public.products where tenant_id=(select id from public.tenants where slug='b5-installment')),
    'qty', 1, 'unit_cost', 1600000, 'serials', jsonb_build_array('B5-FRIDGE-001')
  )), 0, 0, null)$$, 'inventory purchased');

--------------------------------------------------------------------------------
-- T03: Installment sale (example from spec 7.3-B)
-- cash_price 20,000, plan 10 months, factor 40%, down payment 5,000
-- → financed_base 15,000, margin 6,000, receivable 21,000
-- → 10 installments of 2,100 (principal 1,500 + margin 600)
--------------------------------------------------------------------------------

-- First test preview_installment_schedule
select is(
  (public.preview_installment_schedule('2000000', '500000', 10, 4000, null, 100, null)->>'financed_base'),
  '1500000',
  'T03 preview: financed_base = 15,000 EGP'
);
select is(
  (public.preview_installment_schedule('2000000', '500000', 10, 4000, null, 100, null)->>'margin_total'),
  '600000',
  'T03 preview: margin_total = 6,000 EGP'
);
select is(
  (public.preview_installment_schedule('2000000', '500000', 10, 4000, null, 100, null)->>'receivable'),
  '2100000',
  'T03 preview: receivable = 21,000 EGP'
);
select is(
  jsonb_array_length(public.preview_installment_schedule('2000000', '500000', 10, 4000, null, 100, null)->'schedule'),
  10,
  'T03 preview: 10 installments'
);
select is(
  (public.preview_installment_schedule('2000000', '500000', 10, 4000, null, 100, null)->'schedule'->0->>'amount'),
  '210000',
  'T03 preview: each installment = 2,100 EGP'
);
select is(
  (public.preview_installment_schedule('2000000', '500000', 10, 4000, null, 100, null)->'schedule'->0->>'principal'),
  '150000',
  'T03 preview: principal per installment = 1,500 EGP'
);
select is(
  (public.preview_installment_schedule('2000000', '500000', 10, 4000, null, 100, null)->'schedule'->0->>'margin'),
  '60000',
  'T03 preview: margin per installment = 600 EGP'
);

-- Post the actual installment sale
select tests.authenticate_as('b5000000-0000-0000-0000-000000000001');
select lives_ok($$select public.post_installment_sale(
  (select id from public.tenants where slug='b5-installment'),
  'b5000000-0000-0000-0000-000000000201',
  (now() at time zone 'Africa/Cairo')::date,
  (select id from public.customers where tenant_id=(select id from public.tenants where slug='b5-installment')),
  jsonb_build_array(jsonb_build_object(
    'product_id', (select id from public.products where tenant_id=(select id from public.tenants where slug='b5-installment')),
    'unit_id', (select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b5-installment') and serial_no='B5-FRIDGE-001'),
    'qty', 1, 'cash_price', '2000000', 'discount', '0'
  )),
  '500000',
  (select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b5-installment')),
  10, 4000, null, 100, null, null
)$$, 'T03 installment sale posts');

-- Verify contract created
select is(
  (select count(*)::integer from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')),
  1, 'T03 contract created'
);
select is(
  (select cash_total from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')),
  2000000::bigint, 'T03 contract cash_total = 20,000'
);
select is(
  (select down_payment from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')),
  500000::bigint, 'T03 contract down_payment = 5,000'
);
select is(
  (select financed_base from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')),
  1500000::bigint, 'T03 contract financed_base = 15,000'
);
select is(
  (select margin_total from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')),
  600000::bigint, 'T03 contract margin_total = 6,000'
);
select is(
  (select receivable from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')),
  2100000::bigint, 'T03 contract receivable = 21,000'
);

-- Verify installments created
select is(
  (select count(*)::integer from public.installments where contract_id=(
    select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')
  )),
  10, 'T03 creates 10 installments'
);

-- Verify each installment has correct amount/principal/margin
select is(
  (select amount from public.installments where contract_id=(
    select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')
  ) and installment_no=1),
  210000::bigint, 'T03 installment 1 amount = 2,100'
);
select is(
  (select principal from public.installments where contract_id=(
    select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')
  ) and installment_no=1),
  150000::bigint, 'T03 installment 1 principal = 1,500'
);
select is(
  (select margin from public.installments where contract_id=(
    select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')
  ) and installment_no=1),
  60000::bigint, 'T03 installment 1 margin = 600'
);

-- Verify invariants: sum of principals = financed_base
select is(
  (select sum(principal)::bigint from public.installments where contract_id=(
    select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')
  )),
  1500000::bigint, 'T03 sum of principals = financed_base'
);
-- Verify invariants: sum of margins = margin_total
select is(
  (select sum(margin)::bigint from public.installments where contract_id=(
    select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')
  )),
  600000::bigint, 'T03 sum of margins = margin_total'
);
-- Verify invariants: sum of amounts = receivable
select is(
  (select sum(amount)::bigint from public.installments where contract_id=(
    select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment')
  )),
  2100000::bigint, 'T03 sum of amounts = receivable'
);

-- Verify journal entries
-- Dr Cash 5,000 (down payment) - check via cash_account_id dimension
select is(
  (select sum(jl.debit)::bigint from public.journal_lines jl
   join public.journal_entries je on je.id=jl.entry_id
   where je.source_id=(select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment'))
     and jl.cash_account_id is not null),
  500000::bigint, 'T03 cash debit = 5,000 (down payment)'
);
-- Dr Receivable 21,000
select is(
  (select sum(jl.debit)::bigint from public.journal_lines jl
   join public.journal_entries je on je.id=jl.entry_id
   join public.accounts a on a.id=jl.account_id
   where je.source_id=(select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment'))
     and a.system_key='installment_receivable'),
  2100000::bigint, 'T03 receivable debit = 21,000'
);
-- Cr Sales 20,000
select is(
  (select sum(jl.credit)::bigint from public.journal_lines jl
   join public.journal_entries je on je.id=jl.entry_id
   join public.accounts a on a.id=jl.account_id
   where je.source_id=(select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment'))
     and a.system_key='sales'),
  2000000::bigint, 'T03 sales credit = 20,000'
);
-- Cr Unearned margin 6,000
select is(
  (select sum(jl.credit)::bigint from public.journal_lines jl
   join public.journal_entries je on je.id=jl.entry_id
   join public.accounts a on a.id=jl.account_id
   where je.source_id=(select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment'))
     and a.system_key='unearned_margin'),
  600000::bigint, 'T03 unearned margin credit = 6,000'
);
-- Dr COGS 16,000
select is(
  (select sum(jl.debit)::bigint from public.journal_lines jl
   join public.journal_entries je on je.id=jl.entry_id
   join public.accounts a on a.id=jl.account_id
   where je.source_id=(select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment'))
     and a.system_key='cogs'),
  1600000::bigint, 'T03 COGS debit = 16,000'
);
-- Cr Inventory 16,000
select is(
  (select sum(jl.credit)::bigint from public.journal_lines jl
   join public.journal_entries je on je.id=jl.entry_id
   join public.accounts a on a.id=jl.account_id
   where je.source_id=(select id from public.installment_contracts where tenant_id=(select id from public.tenants where slug='b5-installment'))
     and a.system_key='inventory_new'),
  1600000::bigint, 'T03 inventory credit = 16,000'
);

-- Verify unit sold
select is(
  (select status from public.inventory_units where serial_no='B5-FRIDGE-001'),
  'sold'::public.unit_status, 'T03 unit marked as sold'
);

select * from finish();
rollback;
