begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc
select no_plan();

select tests.create_user('b4000000-0000-0000-0000-000000000001', 'b4-owner@example.com');
select tests.create_user('b4000000-0000-0000-0000-000000000002', 'b4-cashier@example.com');
select tests.authenticate_as('b4000000-0000-0000-0000-000000000001');
select lives_ok($$select public.bootstrap_tenant('b4-cash-sale', 'B4 Cash Sale')$$, 'tenant bootstraps');
select lives_ok($$select public.manage_membership(
  (select id from public.tenants where slug='b4-cash-sale'),
  'b4000000-0000-0000-0000-000000000002', 'cashier', true)$$, 'cashier is added');
select lives_ok($$select public.manage_supplier(
  (select id from public.tenants where slug='b4-cash-sale'), null,
  'مورد المبيعات', '01012345678', null, null, true)$$, 'supplier is created');
select lives_ok($$select public.manage_cash_account(
  (select id from public.tenants where slug='b4-cash-sale'), null,
  'الخزنة', 'cash', true)$$, 'cash account is created');
select lives_ok($$select public.manage_cash_account(
  (select id from public.tenants where slug='b4-cash-sale'), null,
  'إنستاباي', 'wallet', true)$$, 'wallet account is created');
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b4-cash-sale'), null,
  'ثلاجة اختبار', 'Test fridge', null, null, 'FR-20', null,
  'serial', 2000000, 0, 24, true)$$, 'serial product is created');
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b4-cash-sale'), null,
  'ريموت اختبار', 'Test remote', null, null, 'RM-1', null,
  'quantity', 20000, 0, 0, true)$$, 'quantity product is created');

select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b4-cash-sale'),
  'b4000000-0000-0000-0000-000000000101',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b4-cash-sale')),
  (now() at time zone 'Africa/Cairo')::date, 'SER-1',
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ثلاجة اختبار'),
    'qty',2,'unit_cost',1600000,'serials',jsonb_build_array('B4-SN-1','B4-SN-2'))),
  0,0,null)$$, 'serial inventory is purchased');
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b4-cash-sale'),
  'b4000000-0000-0000-0000-000000000102',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b4-cash-sale')),
  (now() at time zone 'Africa/Cairo')::date, 'QTY-1',
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ريموت اختبار'),
    'qty',10,'unit_cost',10000)),0,0,null)$$, 'first quantity batch is purchased');
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b4-cash-sale'),
  'b4000000-0000-0000-0000-000000000103',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b4-cash-sale')),
  (now() at time zone 'Africa/Cairo')::date, 'QTY-2',
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ريموت اختبار'),
    'qty',10,'unit_cost',13000)),0,0,null)$$, 'second quantity batch is purchased');
select is((select avg_cost from public.stock_balances where tenant_id=(select id from public.tenants where slug='b4-cash-sale')), 11500::bigint, 'T14 purchase average is exactly 115 EGP');

-- T01: cashier posts 20,000 sale of a 16,000 serial unit.
select tests.authenticate_as('b4000000-0000-0000-0000-000000000002');
select lives_ok($$select public.post_cash_sale(
  (select id from public.tenants where slug='b4-cash-sale'),
  'b4000000-0000-0000-0000-000000000201',
  (now() at time zone 'Africa/Cairo')::date, null,
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ثلاجة اختبار'),
    'unit_id',(select id from public.pos_inventory_units where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and serial_no='B4-SN-1'),
    'qty',1,'cash_price','2000000','discount','0')),
  jsonb_build_array(jsonb_build_object(
    'cash_account_id',(select id from public.pos_cash_accounts where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name='الخزنة'),
    'amount','2000000')),'0')$$, 'T01 cash sale posts');
select tests.authenticate_as('b4000000-0000-0000-0000-000000000001');
select is((select status from public.inventory_units where serial_no='B4-SN-1'), 'sold'::public.unit_status, 'T01 serial is sold');
select is((select sum(jl.debit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000201')
    and jl.account_id=(select gl_account_id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name='الخزنة')), 2000000::bigint, 'T01 cash debit is 20,000');
select is((select sum(jl.credit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000201') and a.system_key='sales'), 2000000::bigint, 'T01 sales credit is 20,000');
select is((select sum(jl.debit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000201') and a.system_key='cogs'), 1600000::bigint, 'T01 COGS debit is 16,000');
select is((select sum(jl.credit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000201') and a.system_key='inventory_new'), 1600000::bigint, 'T01 inventory credit is 16,000');

-- T02: exact 20,000 gross, 500 discount, 19,500 split payment.
select lives_ok($$select public.post_cash_sale(
  (select id from public.tenants where slug='b4-cash-sale'),
  'b4000000-0000-0000-0000-000000000202',
  (now() at time zone 'Africa/Cairo')::date, null,
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ثلاجة اختبار'),
    'unit_id',(select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and serial_no='B4-SN-2'),
    'qty',1,'cash_price','2000000','discount','50000')),
  jsonb_build_array(
    jsonb_build_object('cash_account_id',(select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name='الخزنة'),'amount','1000000'),
    jsonb_build_object('cash_account_id',(select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name='إنستاباي'),'amount','950000')),
  '0')$$, 'T02 discounted split-payment sale posts');
select is((select discount_total from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000202'), 50000::bigint, 'T02 discount is exactly 500');
select is((select net_total from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000202'), 1950000::bigint, 'T02 net is exactly 19,500');
select is((select count(*)::integer from public.sales_payments where invoice_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000202')), 2, 'split payment stores two rows');
select is((select sum(amount)::bigint from public.sales_payments where invoice_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000202')), 1950000::bigint, 'split payment equals invoice net');
select is((select sum(jl.debit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000202') and a.system_key='sales_discounts'), 50000::bigint, 'T02 discount account debit is 500');
select is((select count(*)::integer from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000202') and jl.cash_account_id is not null), 2, 'split cash journal lines retain cash-account dimensions');

-- T14: sell five units at the moving average 115 EGP, COGS must be 575 EGP.
select lives_ok($$select public.post_cash_sale(
  (select id from public.tenants where slug='b4-cash-sale'),
  'b4000000-0000-0000-0000-000000000203',
  (now() at time zone 'Africa/Cairo')::date, null,
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ريموت اختبار'),
    'qty',5,'cash_price','20000','discount','0')),
  jsonb_build_array(jsonb_build_object(
    'cash_account_id',(select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name='الخزنة'),
    'amount','100000')),'0')$$, 'T14 quantity sale posts');
select is((select sum(jl.debit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000203') and a.system_key='cogs'), 57500::bigint, 'T14 COGS is exactly 575 EGP');
select is((select qty from public.stock_balances where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and product_id=(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ريموت اختبار')), 15, 'T14 quantity falls to 15');
select is((select count(*)::integer from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id
  where je.source_id=(select id from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000203') and jl.product_id is not null), 3, 'sale, COGS, and inventory lines retain product dimension');

select is(
  public.post_cash_sale(
    (select id from public.tenants where slug='b4-cash-sale'),
    'b4000000-0000-0000-0000-000000000203',
    (now() at time zone 'Africa/Cairo')::date, null,
    jsonb_build_array(jsonb_build_object(
      'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ريموت اختبار'),
      'qty',5,'cash_price','20000','discount','0')),
    jsonb_build_array(jsonb_build_object(
      'cash_account_id',(select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name='الخزنة'),
      'amount','100000')),'0'),
  (select jsonb_build_object('id', id::text, 'doc_no', doc_no::text)
   from public.sales_invoices where request_id='b4000000-0000-0000-0000-000000000203'),
  'identical retry returns the original result');
select is((select qty from public.stock_balances where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and product_id=(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ريموت اختبار')), 15, 'retry creates no second stock effect');

select throws_ok($$select public.post_cash_sale(
  (select id from public.tenants where slug='b4-cash-sale'), gen_random_uuid(),
  ((now() at time zone 'Africa/Cairo')::date + 1), null,
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name_ar='ريموت اختبار'),
    'qty',1,'cash_price','20000','discount','0')),
  jsonb_build_array(jsonb_build_object(
    'cash_account_id',(select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-cash-sale') and name='الخزنة'),
    'amount','20000')),'0')$$, '22023', 'لا يمكن البيع بتاريخ مستقبلي', 'future Cairo sale date is rejected');

select * from finish();
rollback;
