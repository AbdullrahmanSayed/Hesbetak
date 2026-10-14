begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc
select no_plan();

select tests.create_user('b4ae0000-0000-0000-0000-000000000001', 'b4-return-owner@example.com');
select tests.create_user('b4ae0000-0000-0000-0000-000000000002', 'b4-return-cashier@example.com');
select tests.authenticate_as('b4ae0000-0000-0000-0000-000000000001');
select lives_ok($$select public.bootstrap_tenant('b4-return', 'B4 Return')$$, 'tenant bootstraps');
select lives_ok($$select public.manage_membership(
  (select id from public.tenants where slug='b4-return'),
  'b4ae0000-0000-0000-0000-000000000002', 'cashier', true)$$, 'cashier is added');
select lives_ok($$select public.manage_supplier(
  (select id from public.tenants where slug='b4-return'), null,
  'مورد المرتجع', '01012345678', null, null, true)$$, 'supplier is created');
select lives_ok($$select public.manage_cash_account(
  (select id from public.tenants where slug='b4-return'), null,
  'خزنة المرتجع', 'cash', true)$$, 'cash account is created');
select lives_ok($$select public.manage_product(
  (select id from public.tenants where slug='b4-return'), null,
  'ثلاجة مرتجع', 'Return fridge', null, null, 'RET-1', null,
  'serial', 2000000, 0, 24, true)$$, 'product is created');
select lives_ok($$select public.post_purchase_invoice(
  (select id from public.tenants where slug='b4-return'),
  'b4ae0000-0000-0000-0000-000000000101',
  (select id from public.suppliers where tenant_id=(select id from public.tenants where slug='b4-return')),
  (now() at time zone 'Africa/Cairo')::date, 'RET-PI',
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-return')),
    'qty',1,'unit_cost',1600000,'serials',jsonb_build_array('RET-SN-1'))),0,0,null)$$, 'return unit is purchased');

select lives_ok($$select public.post_cash_sale(
  (select id from public.tenants where slug='b4-return'),
  'b4ae0000-0000-0000-0000-000000000201',
  (now() at time zone 'Africa/Cairo')::date, null,
  jsonb_build_array(jsonb_build_object(
    'product_id',(select id from public.products where tenant_id=(select id from public.tenants where slug='b4-return')),
    'unit_id',(select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b4-return') and serial_no='RET-SN-1'),
    'qty',1,'cash_price','2000000','discount','0')),
  jsonb_build_array(jsonb_build_object(
    'cash_account_id',(select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-return')),
    'amount','1950000')),'50000')$$, 'sale with invoice discount posts');
select is((select discount from public.sales_invoice_lines where invoice_id=(select id from public.sales_invoices where request_id='b4ae0000-0000-0000-0000-000000000201')), 50000::bigint, 'invoice discount is allocated to its line');

select lives_ok($$select public.post_sales_return(
  (select id from public.tenants where slug='b4-return'),
  'b4ae0000-0000-0000-0000-000000000301',
  (select id from public.sales_invoices where request_id='b4ae0000-0000-0000-0000-000000000201'),
  (now() at time zone 'Africa/Cairo')::date,
  jsonb_build_array(jsonb_build_object(
    'original_line_id',(select id from public.sales_invoice_lines where invoice_id=(select id from public.sales_invoices where request_id='b4ae0000-0000-0000-0000-000000000201')),
    'unit_id',(select id from public.inventory_units where tenant_id=(select id from public.tenants where slug='b4-return') and serial_no='RET-SN-1'),
    'qty',1,'return_condition','new')),
  (select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-return')),
  'مرتجع كامل')$$, 'T12 full cash-sale return posts');

select is((select status from public.inventory_units where serial_no='RET-SN-1'), 'in_stock'::public.unit_status, 'T12 serial returns to stock');
select is((select gross_total from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301'), 2000000::bigint, 'T12 gross return is 20,000');
select is((select discount_total from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301'), 50000::bigint, 'T12 reverses the exact 500 discount');
select is((select total_refund from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301'), 1950000::bigint, 'T12 refunds exactly 19,500');
select is((select sum(jl.debit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301') and a.system_key='sales_returns'), 2000000::bigint, 'T12 sales returns debit is 20,000');
select is((select sum(jl.credit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301') and a.system_key='sales_discounts'), 50000::bigint, 'T12 discount credit is 500');
select is((select sum(jl.credit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id
  where je.source_id=(select id from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301')
    and jl.account_id=(select gl_account_id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-return'))), 1950000::bigint, 'T12 cash credit is 19,500');
select is((select sum(jl.debit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301') and a.system_key='inventory_new'), 1600000::bigint, 'T12 inventory debit restores 16,000');
select is((select sum(jl.credit)::bigint from public.journal_lines jl join public.journal_entries je on je.id=jl.entry_id join public.accounts a on a.id=jl.account_id
  where je.source_id=(select id from public.sales_returns where request_id='b4ae0000-0000-0000-0000-000000000301') and a.system_key='cogs'), 1600000::bigint, 'T12 COGS credit reverses 16,000');

select throws_ok($$select public.post_sales_return(
  (select id from public.tenants where slug='b4-return'), gen_random_uuid(),
  (select id from public.sales_invoices where request_id='b4ae0000-0000-0000-0000-000000000201'),
  (now() at time zone 'Africa/Cairo')::date,
  jsonb_build_array(jsonb_build_object(
    'original_line_id',(select id from public.sales_invoice_lines where invoice_id=(select id from public.sales_invoices where request_id='b4ae0000-0000-0000-0000-000000000201')),
    'unit_id',(select id from public.inventory_units where serial_no='RET-SN-1'),
    'qty',1,'return_condition','new')),
  (select id from public.cash_accounts where tenant_id=(select id from public.tenants where slug='b4-return')),
  'مرتجع زائد')$$, '23514', 'كمية المرتجع تتجاوز الكمية المتبقية', 'cannot return more than the original quantity');

select tests.authenticate_as_service_role();
select throws_ok($$update public.sales_returns set reason='تعديل ممنوع'
  where request_id='b4ae0000-0000-0000-0000-000000000301'$$,
  '55000', 'sales_returns is append-only', 'posted return cannot be updated');

select tests.authenticate_as('b4ae0000-0000-0000-0000-000000000002');
select throws_ok($$select public.post_sales_return(
  (select id from public.tenants where slug='b4-return'), gen_random_uuid(),
  (select id from public.sales_invoices where request_id='b4ae0000-0000-0000-0000-000000000201'),
  (now() at time zone 'Africa/Cairo')::date, '[]'::jsonb,
  (select id from public.pos_cash_accounts where tenant_id=(select id from public.tenants where slug='b4-return')),
  'غير مسموح')$$, '42501', 'لا تملك صلاحية تنفيذ المرتجع', 'cashier cannot post returns');

select * from finish();
rollback;
