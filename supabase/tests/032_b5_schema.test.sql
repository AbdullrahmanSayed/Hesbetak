begin;
create extension if not exists pgtap with schema extensions;
\ir helpers/b1.inc
select plan(26);

-- Contract status enum
select has_enum('public', 'contract_status', 'contract_status enum exists');
select enum_has_labels('public', 'contract_status',
  array['active', 'settled', 'early_settled', 'rescheduled', 'written_off', 'cancelled'],
  'contract_status has all expected labels');

-- Installment status enum
select has_enum('public', 'installment_status', 'installment_status enum exists');
select enum_has_labels('public', 'installment_status',
  array['pending', 'partially_paid', 'paid', 'frozen', 'written_off', 'cancelled'],
  'installment_status has all expected labels');

-- Tables exist
select has_table('public', 'installment_contracts', 'installment_contracts table exists');
select has_table('public', 'installments', 'installments table exists');

-- installment_contracts columns
select has_column('public', 'installment_contracts', 'tenant_id', 'contracts has tenant_id');
select has_column('public', 'installment_contracts', 'doc_no', 'contracts has doc_no');
select has_column('public', 'installment_contracts', 'customer_id', 'contracts has customer_id');
select has_column('public', 'installment_contracts', 'guarantor_name', 'contracts has guarantor snapshot');
select has_column('public', 'installment_contracts', 'cash_total', 'contracts has cash_total');
select has_column('public', 'installment_contracts', 'down_payment', 'contracts has down_payment');
select has_column('public', 'installment_contracts', 'financed_base', 'contracts has financed_base');
select has_column('public', 'installment_contracts', 'margin_total', 'contracts has margin_total');
select has_column('public', 'installment_contracts', 'receivable', 'contracts has receivable');
select has_column('public', 'installment_contracts', 'months', 'contracts has months');
select has_column('public', 'installment_contracts', 'status', 'contracts has status');

-- installments columns
select has_column('public', 'installments', 'contract_id', 'installments has contract_id');
select has_column('public', 'installments', 'installment_no', 'installments has installment_no');
select has_column('public', 'installments', 'due_date', 'installments has due_date');
select has_column('public', 'installments', 'amount', 'installments has amount');
select has_column('public', 'installments', 'principal', 'installments has principal');
select has_column('public', 'installments', 'margin', 'installments has margin');
select has_column('public', 'installments', 'paid_amount', 'installments has paid_amount');
select has_column('public', 'installments', 'status', 'installments has status');

-- Functions exist
select has_function('public', 'preview_installment_schedule', 'preview_installment_schedule exists');

select * from finish();
rollback;
