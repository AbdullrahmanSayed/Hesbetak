begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc

select no_plan();

select has_enum('public', 'sale_kind', 'sale_kind enum exists');
select enum_has_labels('public', 'sale_kind', array['cash', 'installment'], 'sale_kind labels are exact');

select has_table('public', 'sales_invoices', 'sales_invoices exists');
select has_table('public', 'sales_invoice_lines', 'sales_invoice_lines exists');
select has_table('public', 'sales_payments', 'sales_payments exists');
select has_table('public', 'sales_returns', 'sales_returns exists');
select has_table('public', 'sales_return_lines', 'sales_return_lines exists');

select has_column('public', 'sales_invoices', 'request_id', 'invoice stores request_id');
select has_column('public', 'sales_invoice_lines', 'cost_snapshot', 'invoice line stores cost snapshot');
select has_column('public', 'sales_invoice_lines', 'discount', 'invoice line stores allocated discount');
select has_column('public', 'sales_payments', 'cash_account_id', 'payment stores cash account');
select has_column('public', 'sales_return_lines', 'original_line_id', 'return line links original line');

select ok((select relrowsecurity from pg_class where oid = 'public.sales_invoices'::regclass), 'sales_invoices has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.sales_invoice_lines'::regclass), 'sales_invoice_lines has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.sales_payments'::regclass), 'sales_payments has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.sales_returns'::regclass), 'sales_returns has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.sales_return_lines'::regclass), 'sales_return_lines has RLS');

select has_trigger('public', 'sales_invoices', 'guard_sales_invoices_mutation', 'invoice mutation guard exists');
select has_trigger('public', 'sales_invoice_lines', 'guard_sales_invoice_lines_mutation', 'invoice-line mutation guard exists');
select has_trigger('public', 'sales_payments', 'guard_sales_payments_mutation', 'payment mutation guard exists');
select has_trigger('public', 'sales_returns', 'guard_sales_returns_mutation', 'return mutation guard exists');
select has_trigger('public', 'sales_return_lines', 'guard_sales_return_lines_mutation', 'return-line mutation guard exists');

select has_view('public', 'sales_invoice_lines_no_cost', 'safe sales-line view exists');
select has_view('public', 'sales_return_lines_no_cost', 'safe return-line view exists');
select has_view('public', 'pos_products', 'POS products view exists');
select has_view('public', 'pos_inventory_units', 'POS serial-unit view exists');
select has_view('public', 'pos_cash_accounts', 'POS cash-account view exists');

select has_function('public', 'post_cash_sale', array['uuid','uuid','date','uuid','jsonb','jsonb','text'], 'post_cash_sale signature exists');
select has_function('public', 'post_sales_return', array['uuid','uuid','uuid','date','jsonb','uuid','text'], 'post_sales_return signature exists');

select ok(not has_table_privilege('authenticated', 'public.sales_invoices', 'INSERT'), 'authenticated cannot insert invoices');
select ok(not has_table_privilege('authenticated', 'public.sales_invoices', 'UPDATE'), 'authenticated cannot update invoices');
select ok(not has_table_privilege('authenticated', 'public.sales_invoices', 'DELETE'), 'authenticated cannot delete invoices');
select ok(has_function_privilege('authenticated', 'public.post_cash_sale(uuid,uuid,date,uuid,jsonb,jsonb,text)', 'EXECUTE'), 'authenticated can execute cash sale RPC');
select ok(has_function_privilege('authenticated', 'public.post_sales_return(uuid,uuid,uuid,date,jsonb,uuid,text)', 'EXECUTE'), 'authenticated can execute return RPC');
select ok(not has_function_privilege('authenticated', 'app.money_from_json(jsonb,text,boolean)', 'EXECUTE'), 'money parser stays internal');

select * from finish();
rollback;
