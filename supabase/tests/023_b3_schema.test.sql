begin;
create extension if not exists pgtap with schema extensions;

select plan(22);

-- Enums
select has_type('public', 'unit_condition', 'unit_condition enum exists');
select has_type('public', 'unit_status', 'unit_status enum exists');
select has_type('public', 'movement_type', 'movement_type enum exists');

-- Inventory tables
select has_table('public', 'inventory_units', 'inventory_units table exists');
select has_table('public', 'stock_balances', 'stock_balances table exists');
select has_table('public', 'stock_movements', 'stock_movements table exists');

-- Purchase document tables
select has_table('public', 'purchase_invoices', 'purchase_invoices table exists');
select has_table('public', 'purchase_invoice_lines', 'purchase_invoice_lines table exists');
select has_table('public', 'supplier_payments', 'supplier_payments table exists');

-- Adjustment tables
select has_table('public', 'inventory_adjustments', 'inventory_adjustments table exists');
select has_table('public', 'inventory_adjustment_lines', 'inventory_adjustment_lines table exists');

-- RLS enabled
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'inventory_units'), false), 'inventory_units has RLS');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'stock_balances'), false), 'stock_balances has RLS');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'stock_movements'), false), 'stock_movements has RLS');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'purchase_invoices'), false), 'purchase_invoices has RLS');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'supplier_payments'), false), 'supplier_payments has RLS');
select ok(coalesce((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'inventory_adjustments'), false), 'inventory_adjustments has RLS');

-- Posting functions exist
select has_function('public', 'post_purchase_invoice', 'post_purchase_invoice exists');
select has_function('public', 'post_supplier_payment', 'post_supplier_payment exists');
select has_function('public', 'post_inventory_adjustment', 'post_inventory_adjustment exists');

-- Helper functions
select has_function('app', 'calc_weighted_avg', 'calc_weighted_avg exists');
select has_function('app', 'update_stock_balance', 'update_stock_balance exists');

select * from finish();
rollback;
