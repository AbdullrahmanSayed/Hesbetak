-- B3: Purchases & Inventory system
-- Serial tracking, weighted average costing, purchase documents, supplier payments, adjustments

-- Ensure pgcrypto is available
create extension if not exists pgcrypto with schema extensions;

--------------------------------------------------------------------------------
-- ENUMS
--------------------------------------------------------------------------------

create type public.unit_condition as enum ('new', 'used', 'open_box');
create type public.unit_status as enum ('in_stock', 'sold', 'returned_to_supplier', 'written_off');
create type public.movement_type as enum ('purchase', 'sale', 'return_in', 'return_out', 'adjustment', 'opening');

--------------------------------------------------------------------------------
-- INVENTORY TABLES
--------------------------------------------------------------------------------

-- Serial-tracked units (specific identification costing)
create table public.inventory_units (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  product_id uuid not null,
  serial_no text not null check (btrim(serial_no) <> ''),
  condition public.unit_condition not null default 'new',
  status public.unit_status not null default 'in_stock',
  unit_cost bigint not null check (unit_cost >= 0),
  source_type text not null,
  source_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  foreign key (tenant_id, product_id) references public.products(tenant_id, id)
);

create unique index inventory_units_tenant_product_serial_key 
  on public.inventory_units (tenant_id, product_id, lower(serial_no));
create index inventory_units_tenant_status_idx 
  on public.inventory_units (tenant_id, status) where status = 'in_stock';

alter table public.inventory_units enable row level security;
create policy inventory_units_tenant_isolation on public.inventory_units
  for all to authenticated using (app.is_member(tenant_id));

-- Quantity-tracked balances (weighted average costing)
create table public.stock_balances (
  tenant_id uuid not null references public.tenants(id),
  product_id uuid not null,
  qty integer not null default 0 check (qty >= 0),
  avg_cost bigint not null default 0 check (avg_cost >= 0),
  updated_at timestamptz not null default now(),
  primary key (tenant_id, product_id),
  foreign key (tenant_id, product_id) references public.products(tenant_id, id)
);

alter table public.stock_balances enable row level security;
create policy stock_balances_tenant_isolation on public.stock_balances
  for all to authenticated using (app.is_member(tenant_id));

-- Stock movements (audit trail)
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  product_id uuid not null,
  unit_id uuid references public.inventory_units(id),
  movement_type public.movement_type not null,
  qty integer not null,
  unit_cost bigint not null check (unit_cost >= 0),
  document_type text not null,
  document_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  foreign key (tenant_id, product_id) references public.products(tenant_id, id)
);

create index stock_movements_document_idx on public.stock_movements (document_type, document_id);

alter table public.stock_movements enable row level security;
create policy stock_movements_tenant_isolation on public.stock_movements
  for all to authenticated using (app.is_member(tenant_id));

--------------------------------------------------------------------------------
-- PURCHASE DOCUMENTS
--------------------------------------------------------------------------------

create table public.purchase_invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  doc_no bigint not null,
  invoice_date date not null,
  supplier_id uuid not null,
  supplier_invoice_no text,
  subtotal bigint not null check (subtotal >= 0),
  discount bigint not null default 0 check (discount >= 0),
  total bigint not null check (total >= 0),
  paid_amount bigint not null default 0 check (paid_amount >= 0),
  cash_account_id uuid,
  status text not null default 'posted' check (status in ('posted', 'reversed')),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, doc_no),
  unique (tenant_id, id),
  foreign key (tenant_id, supplier_id) references public.suppliers(tenant_id, id),
  foreign key (tenant_id, cash_account_id) references public.cash_accounts(tenant_id, id)
);

alter table public.purchase_invoices enable row level security;
create policy purchase_invoices_tenant_isolation on public.purchase_invoices
  for select to authenticated using (app.is_member(tenant_id));

create table public.purchase_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  invoice_id uuid not null,
  product_id uuid not null,
  qty integer not null check (qty > 0),
  unit_cost bigint not null check (unit_cost >= 0),
  line_total bigint not null check (line_total >= 0),
  unique (tenant_id, id),
  foreign key (tenant_id, invoice_id) references public.purchase_invoices(tenant_id, id),
  foreign key (tenant_id, product_id) references public.products(tenant_id, id)
);

alter table public.purchase_invoice_lines enable row level security;
create policy purchase_invoice_lines_tenant_isolation on public.purchase_invoice_lines
  for select to authenticated using (app.is_member(tenant_id));

create table public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  doc_no bigint not null,
  payment_date date not null,
  supplier_id uuid not null,
  cash_account_id uuid not null,
  amount bigint not null check (amount > 0),
  note text,
  status text not null default 'posted' check (status in ('posted', 'reversed')),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, doc_no),
  unique (tenant_id, id),
  foreign key (tenant_id, supplier_id) references public.suppliers(tenant_id, id),
  foreign key (tenant_id, cash_account_id) references public.cash_accounts(tenant_id, id)
);

alter table public.supplier_payments enable row level security;
create policy supplier_payments_tenant_isolation on public.supplier_payments
  for select to authenticated using (app.is_member(tenant_id));

create table public.inventory_adjustments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  doc_no bigint not null,
  adjustment_date date not null,
  reason text not null check (btrim(reason) <> ''),
  total_adjustment bigint not null,
  status text not null default 'posted' check (status in ('posted', 'reversed')),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, doc_no),
  unique (tenant_id, id)
);

alter table public.inventory_adjustments enable row level security;
create policy inventory_adjustments_tenant_isolation on public.inventory_adjustments
  for select to authenticated using (app.is_member(tenant_id));

create table public.inventory_adjustment_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  adjustment_id uuid not null,
  product_id uuid not null,
  unit_id uuid,
  qty_change integer not null,
  cost bigint not null check (cost >= 0),
  unique (tenant_id, id),
  foreign key (tenant_id, adjustment_id) references public.inventory_adjustments(tenant_id, id),
  foreign key (tenant_id, product_id) references public.products(tenant_id, id),
  foreign key (tenant_id, unit_id) references public.inventory_units(tenant_id, id)
);

alter table public.inventory_adjustment_lines enable row level security;
create policy inventory_adjustment_lines_tenant_isolation on public.inventory_adjustment_lines
  for select to authenticated using (app.is_member(tenant_id));

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Calculate weighted average cost
create or replace function app.calc_weighted_avg(
  p_old_qty integer,
  p_old_avg bigint,
  p_new_qty integer,
  p_new_cost bigint
)
returns bigint
language sql
immutable
as $$
  select case
    when p_old_qty + p_new_qty = 0 then 0::bigint
    else ((p_old_qty::bigint * p_old_avg) + (p_new_qty::bigint * p_new_cost)) / (p_old_qty + p_new_qty)
  end
$$;

-- Get inventory GL account based on condition
create or replace function app.get_inventory_account_id(p_tenant_id uuid, p_condition public.unit_condition)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select id from public.accounts
  where tenant_id = p_tenant_id
    and system_key = case p_condition
      when 'new' then 'inventory_new'
      when 'used' then 'inventory_used'
      when 'open_box' then 'inventory_new'
    end
$$;

-- Update stock balance with weighted average
create or replace function app.update_stock_balance(
  p_tenant_id uuid,
  p_product_id uuid,
  p_qty_change integer,
  p_unit_cost bigint
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current record;
  v_new_avg bigint;
begin
  select qty, avg_cost into v_current
  from public.stock_balances
  where tenant_id = p_tenant_id and product_id = p_product_id
  for update;

  if not found then
    insert into public.stock_balances (tenant_id, product_id, qty, avg_cost)
    values (p_tenant_id, p_product_id, p_qty_change, p_unit_cost);
  else
    if p_qty_change > 0 then
      v_new_avg := app.calc_weighted_avg(v_current.qty, v_current.avg_cost, p_qty_change, p_unit_cost);
      update public.stock_balances
      set qty = v_current.qty + p_qty_change, avg_cost = v_new_avg, updated_at = now()
      where tenant_id = p_tenant_id and product_id = p_product_id;
    else
      if v_current.qty + p_qty_change < 0 then
        raise exception using errcode = '23514', message = 'insufficient stock quantity';
      end if;
      update public.stock_balances
      set qty = v_current.qty + p_qty_change, updated_at = now()
      where tenant_id = p_tenant_id and product_id = p_product_id;
    end if;
  end if;
end;
$$;

--------------------------------------------------------------------------------
-- POSTING RPCs
--------------------------------------------------------------------------------

-- Post Purchase Invoice
create or replace function public.post_purchase_invoice(
  p_tenant_id uuid,
  p_request_id uuid,
  p_supplier_id uuid,
  p_invoice_date date,
  p_supplier_invoice_no text,
  p_lines jsonb,
  p_discount bigint default 0,
  p_paid_amount bigint default 0,
  p_cash_account_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_invoice_id uuid;
  v_doc_no bigint;
  v_subtotal bigint := 0;
  v_total bigint;
  v_remaining bigint;
  v_line jsonb;
  v_line_total bigint;
  v_product record;
  v_serial text;
  v_unit_id uuid;
  v_inventory_account_id uuid;
  v_payable_account_id uuid;
  v_cash_gl_account_id uuid;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
  v_je_lines jsonb := '[]'::jsonb;
  v_je_result jsonb;
  v_lock_date date;
begin
  -- Permission check
  if not app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner or manager role required';
  end if;
  v_actor := auth.uid();

  -- Payload hash for idempotency
  v_payload_hash := encode(extensions.digest(convert_to(
    p_supplier_id::text || '|' || p_invoice_date::text || '|' || coalesce(p_supplier_invoice_no, '') || '|' || 
    p_lines::text || '|' || p_discount::text || '|' || p_paid_amount::text,
    'UTF8'
  ), 'sha256'), 'hex');

  -- Idempotency check
  select result, payload_hash into v_existing_result, v_existing_hash
  from public.posting_requests
  where tenant_id = p_tenant_id and request_id = p_request_id and status = 'completed';
  
  if found then
    if v_existing_hash = v_payload_hash then
      return v_existing_result;
    else
      raise exception using errcode = '23514', message = 'request_id reuse with different payload';
    end if;
  end if;

  -- Validate supplier
  if not exists (select 1 from public.suppliers where tenant_id = p_tenant_id and id = p_supplier_id and is_active) then
    raise exception using errcode = '22023', message = 'invalid or inactive supplier';
  end if;

  -- Validate cash account if paying
  if p_paid_amount > 0 then
    if p_cash_account_id is null then
      raise exception using errcode = '22023', message = 'cash_account_id required when paid_amount > 0';
    end if;
    select gl_account_id into v_cash_gl_account_id
    from public.cash_accounts where tenant_id = p_tenant_id and id = p_cash_account_id and is_active;
    if not found then
      raise exception using errcode = '22023', message = 'invalid or inactive cash account';
    end if;
  end if;

  -- Lock date check
  select lock_date into v_lock_date from public.tenants where id = p_tenant_id;
  if v_lock_date is not null and p_invoice_date <= v_lock_date then
    raise exception using errcode = '55000', message = 'entry date is on or before lock date';
  end if;

  -- Get GL accounts
  select id into v_payable_account_id from public.accounts where tenant_id = p_tenant_id and system_key = 'accounts_payable';
  v_inventory_account_id := app.get_inventory_account_id(p_tenant_id, 'new');

  -- Calculate subtotal
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    v_line_total := (v_line->>'qty')::integer * (v_line->>'unit_cost')::bigint;
    v_subtotal := v_subtotal + v_line_total;
  end loop;

  v_total := v_subtotal - p_discount;
  if v_total < 0 then
    raise exception using errcode = '22023', message = 'discount cannot exceed subtotal';
  end if;
  if p_paid_amount > v_total then
    raise exception using errcode = '22023', message = 'paid amount cannot exceed total';
  end if;

  v_remaining := v_total - p_paid_amount;

  -- Generate document number
  v_doc_no := app.next_document_number(p_tenant_id, 'purchase_invoice', extract(year from p_invoice_date)::integer, v_actor);
  v_invoice_id := gen_random_uuid();

  -- Insert purchase invoice (no trigger guard - direct insert by security definer)
  insert into public.purchase_invoices (
    id, tenant_id, doc_no, invoice_date, supplier_id, supplier_invoice_no,
    subtotal, discount, total, paid_amount, cash_account_id, created_by
  ) values (
    v_invoice_id, p_tenant_id, v_doc_no, p_invoice_date, p_supplier_id, nullif(btrim(p_supplier_invoice_no), ''),
    v_subtotal, p_discount, v_total, p_paid_amount, p_cash_account_id, v_actor
  );

  -- Process lines
  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    v_line_total := (v_line->>'qty')::integer * (v_line->>'unit_cost')::bigint;
    
    select * into v_product from public.products where tenant_id = p_tenant_id and id = (v_line->>'product_id')::uuid;
    if not found then
      raise exception using errcode = '22023', message = 'product not found';
    end if;

    insert into public.purchase_invoice_lines (tenant_id, invoice_id, product_id, qty, unit_cost, line_total)
    values (p_tenant_id, v_invoice_id, v_product.id, (v_line->>'qty')::integer, (v_line->>'unit_cost')::bigint, v_line_total);

    if v_product.tracking = 'serial' then
      if v_line->'serials' is null or jsonb_array_length(v_line->'serials') != (v_line->>'qty')::integer then
        raise exception using errcode = '22023', message = 'serial count must match qty';
      end if;
      for v_serial in select * from jsonb_array_elements_text(v_line->'serials')
      loop
        v_unit_id := gen_random_uuid();
        insert into public.inventory_units (id, tenant_id, product_id, serial_no, condition, status, unit_cost, source_type, source_id, created_by)
        values (v_unit_id, p_tenant_id, v_product.id, btrim(v_serial), 'new', 'in_stock', (v_line->>'unit_cost')::bigint, 'purchase_invoice', v_invoice_id, v_actor);
        insert into public.stock_movements (tenant_id, product_id, unit_id, movement_type, qty, unit_cost, document_type, document_id, created_by)
        values (p_tenant_id, v_product.id, v_unit_id, 'purchase', 1, (v_line->>'unit_cost')::bigint, 'purchase_invoice', v_invoice_id, v_actor);
      end loop;
    else
      perform app.update_stock_balance(p_tenant_id, v_product.id, (v_line->>'qty')::integer, (v_line->>'unit_cost')::bigint);
      insert into public.stock_movements (tenant_id, product_id, unit_id, movement_type, qty, unit_cost, document_type, document_id, created_by)
      values (p_tenant_id, v_product.id, null, 'purchase', (v_line->>'qty')::integer, (v_line->>'unit_cost')::bigint, 'purchase_invoice', v_invoice_id, v_actor);
    end if;
  end loop;

  -- Build journal lines (values must be strings per B1 contract)
  v_je_lines := v_je_lines || jsonb_build_object('account_id', v_inventory_account_id::text, 'debit', v_total::text, 'credit', '0', 'supplier_id', p_supplier_id::text);
  if v_remaining > 0 then
    v_je_lines := v_je_lines || jsonb_build_object('account_id', v_payable_account_id::text, 'debit', '0', 'credit', v_remaining::text, 'supplier_id', p_supplier_id::text);
  end if;
  if p_paid_amount > 0 then
    v_je_lines := v_je_lines || jsonb_build_object('account_id', v_cash_gl_account_id::text, 'debit', '0', 'credit', p_paid_amount::text);
  end if;

  -- Create journal entry (use invoice_id as journal request_id to avoid duplicate)
  v_je_result := app.create_journal_entry(p_tenant_id, v_invoice_id, p_invoice_date, 'purchase_invoice', v_invoice_id, 'فاتورة شراء رقم ' || v_doc_no, v_je_lines);

  -- Save idempotency for the posting RPC
  insert into public.posting_requests (tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at)
  values (p_tenant_id, p_request_id, 'post_purchase_invoice', v_payload_hash, 'completed', jsonb_build_object('id', v_invoice_id, 'doc_no', v_doc_no), v_actor, now());

  -- Audit log
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, after_data)
  values (p_tenant_id, v_actor, 'purchase_invoice.post', 'purchase_invoice', v_invoice_id, jsonb_build_object('doc_no', v_doc_no, 'total', v_total));

  return jsonb_build_object('id', v_invoice_id, 'doc_no', v_doc_no);
end;
$$;

-- Post Supplier Payment
create or replace function public.post_supplier_payment(
  p_tenant_id uuid,
  p_request_id uuid,
  p_supplier_id uuid,
  p_payment_date date,
  p_cash_account_id uuid,
  p_amount bigint,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_payment_id uuid;
  v_doc_no bigint;
  v_payable_account_id uuid;
  v_cash_gl_account_id uuid;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
  v_je_lines jsonb := '[]'::jsonb;
  v_je_result jsonb;
  v_lock_date date;
begin
  if not app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner or manager role required';
  end if;
  v_actor := auth.uid();

  v_payload_hash := encode(extensions.digest(convert_to(
    p_supplier_id::text || '|' || p_payment_date::text || '|' || p_cash_account_id::text || '|' || p_amount::text,
    'UTF8'
  ), 'sha256'), 'hex');

  select result, payload_hash into v_existing_result, v_existing_hash
  from public.posting_requests where tenant_id = p_tenant_id and request_id = p_request_id and status = 'completed';
  if found then
    if v_existing_hash = v_payload_hash then return v_existing_result;
    else raise exception using errcode = '23514', message = 'request_id reuse with different payload';
    end if;
  end if;

  select lock_date into v_lock_date from public.tenants where id = p_tenant_id;
  if v_lock_date is not null and p_payment_date <= v_lock_date then
    raise exception using errcode = '55000', message = 'entry date is on or before lock date';
  end if;

  if not exists (select 1 from public.suppliers where tenant_id = p_tenant_id and id = p_supplier_id) then
    raise exception using errcode = '22023', message = 'invalid supplier';
  end if;

  select gl_account_id into v_cash_gl_account_id from public.cash_accounts where tenant_id = p_tenant_id and id = p_cash_account_id and is_active;
  if not found then raise exception using errcode = '22023', message = 'invalid cash account'; end if;

  select id into v_payable_account_id from public.accounts where tenant_id = p_tenant_id and system_key = 'accounts_payable';

  v_doc_no := app.next_document_number(p_tenant_id, 'supplier_payment', extract(year from p_payment_date)::integer, v_actor);
  v_payment_id := gen_random_uuid();

  insert into public.supplier_payments (id, tenant_id, doc_no, payment_date, supplier_id, cash_account_id, amount, note, created_by)
  values (v_payment_id, p_tenant_id, v_doc_no, p_payment_date, p_supplier_id, p_cash_account_id, p_amount, nullif(btrim(p_note), ''), v_actor);

  v_je_lines := v_je_lines || jsonb_build_object('account_id', v_payable_account_id::text, 'debit', p_amount::text, 'credit', '0', 'supplier_id', p_supplier_id::text);
  v_je_lines := v_je_lines || jsonb_build_object('account_id', v_cash_gl_account_id::text, 'debit', '0', 'credit', p_amount::text);

  v_je_result := app.create_journal_entry(p_tenant_id, v_payment_id, p_payment_date, 'supplier_payment', v_payment_id, 'سداد مورد رقم ' || v_doc_no, v_je_lines);

  insert into public.posting_requests (tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at)
  values (p_tenant_id, p_request_id, 'post_supplier_payment', v_payload_hash, 'completed', jsonb_build_object('id', v_payment_id, 'doc_no', v_doc_no), v_actor, now());

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, after_data)
  values (p_tenant_id, v_actor, 'supplier_payment.post', 'supplier_payment', v_payment_id, jsonb_build_object('doc_no', v_doc_no, 'amount', p_amount));

  return jsonb_build_object('id', v_payment_id, 'doc_no', v_doc_no);
end;
$$;

-- Post Inventory Adjustment
create or replace function public.post_inventory_adjustment(
  p_tenant_id uuid,
  p_request_id uuid,
  p_adjustment_date date,
  p_reason text,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_adjustment_id uuid;
  v_doc_no bigint;
  v_total_adjustment bigint := 0;
  v_line jsonb;
  v_product record;
  v_inventory_account_id uuid;
  v_adjustment_account_id uuid;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
  v_je_lines jsonb := '[]'::jsonb;
  v_je_result jsonb;
  v_lock_date date;
begin
  if not app.has_role(p_tenant_id, array['owner']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner role required';
  end if;
  v_actor := auth.uid();

  v_payload_hash := encode(extensions.digest(convert_to(
    p_adjustment_date::text || '|' || p_reason || '|' || p_lines::text,
    'UTF8'
  ), 'sha256'), 'hex');

  select result, payload_hash into v_existing_result, v_existing_hash
  from public.posting_requests where tenant_id = p_tenant_id and request_id = p_request_id and status = 'completed';
  if found then
    if v_existing_hash = v_payload_hash then return v_existing_result;
    else raise exception using errcode = '23514', message = 'request_id reuse with different payload';
    end if;
  end if;

  select lock_date into v_lock_date from public.tenants where id = p_tenant_id;
  if v_lock_date is not null and p_adjustment_date <= v_lock_date then
    raise exception using errcode = '55000', message = 'entry date is on or before lock date';
  end if;

  select id into v_adjustment_account_id from public.accounts where tenant_id = p_tenant_id and system_key = 'inventory_adjustments';
  v_inventory_account_id := app.get_inventory_account_id(p_tenant_id, 'new');

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    v_total_adjustment := v_total_adjustment + ((v_line->>'qty_change')::integer * (v_line->>'cost')::bigint);
  end loop;

  v_doc_no := app.next_document_number(p_tenant_id, 'inventory_adjustment', extract(year from p_adjustment_date)::integer, v_actor);
  v_adjustment_id := gen_random_uuid();

  insert into public.inventory_adjustments (id, tenant_id, doc_no, adjustment_date, reason, total_adjustment, created_by)
  values (v_adjustment_id, p_tenant_id, v_doc_no, p_adjustment_date, btrim(p_reason), v_total_adjustment, v_actor);

  for v_line in select * from jsonb_array_elements(p_lines)
  loop
    select * into v_product from public.products where tenant_id = p_tenant_id and id = (v_line->>'product_id')::uuid;

    insert into public.inventory_adjustment_lines (tenant_id, adjustment_id, product_id, unit_id, qty_change, cost)
    values (p_tenant_id, v_adjustment_id, v_product.id, (v_line->>'unit_id')::uuid, (v_line->>'qty_change')::integer, (v_line->>'cost')::bigint);

    if v_line->>'unit_id' is not null then
      update public.inventory_units set status = 'written_off' where id = (v_line->>'unit_id')::uuid and tenant_id = p_tenant_id;
      insert into public.stock_movements (tenant_id, product_id, unit_id, movement_type, qty, unit_cost, document_type, document_id, created_by)
      values (p_tenant_id, v_product.id, (v_line->>'unit_id')::uuid, 'adjustment', -1, (v_line->>'cost')::bigint, 'inventory_adjustment', v_adjustment_id, v_actor);
    else
      if (v_line->>'qty_change')::integer > 0 then
        perform app.update_stock_balance(p_tenant_id, v_product.id, (v_line->>'qty_change')::integer, (v_line->>'cost')::bigint);
      else
        perform app.update_stock_balance(p_tenant_id, v_product.id, (v_line->>'qty_change')::integer, 0);
      end if;
      insert into public.stock_movements (tenant_id, product_id, unit_id, movement_type, qty, unit_cost, document_type, document_id, created_by)
      values (p_tenant_id, v_product.id, null, 'adjustment', (v_line->>'qty_change')::integer, (v_line->>'cost')::bigint, 'inventory_adjustment', v_adjustment_id, v_actor);
    end if;
  end loop;

  if v_total_adjustment > 0 then
    v_je_lines := v_je_lines || jsonb_build_object('account_id', v_inventory_account_id::text, 'debit', v_total_adjustment::text, 'credit', '0');
    v_je_lines := v_je_lines || jsonb_build_object('account_id', v_adjustment_account_id::text, 'debit', '0', 'credit', v_total_adjustment::text);
  else
    v_je_lines := v_je_lines || jsonb_build_object('account_id', v_adjustment_account_id::text, 'debit', ((-v_total_adjustment)::text), 'credit', '0');
    v_je_lines := v_je_lines || jsonb_build_object('account_id', v_inventory_account_id::text, 'debit', '0', 'credit', ((-v_total_adjustment)::text));
  end if;

  v_je_result := app.create_journal_entry(p_tenant_id, v_adjustment_id, p_adjustment_date, 'inventory_adjustment', v_adjustment_id, 'تسوية مخزون: ' || btrim(p_reason), v_je_lines);

  insert into public.posting_requests (tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at)
  values (p_tenant_id, p_request_id, 'post_inventory_adjustment', v_payload_hash, 'completed', jsonb_build_object('id', v_adjustment_id, 'doc_no', v_doc_no), v_actor, now());

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, after_data)
  values (p_tenant_id, v_actor, 'inventory_adjustment.post', 'inventory_adjustment', v_adjustment_id, jsonb_build_object('doc_no', v_doc_no, 'total', v_total_adjustment));

  return jsonb_build_object('id', v_adjustment_id, 'doc_no', v_doc_no);
end;
$$;

--------------------------------------------------------------------------------
-- GRANTS
--------------------------------------------------------------------------------

grant select on public.inventory_units, public.stock_balances, public.stock_movements,
               public.purchase_invoices, public.purchase_invoice_lines,
               public.supplier_payments, public.inventory_adjustments,
               public.inventory_adjustment_lines to authenticated;

revoke all on function public.post_purchase_invoice(uuid, uuid, uuid, date, text, jsonb, bigint, bigint, uuid) from public, anon, authenticated;
grant execute on function public.post_purchase_invoice(uuid, uuid, uuid, date, text, jsonb, bigint, bigint, uuid) to authenticated;

revoke all on function public.post_supplier_payment(uuid, uuid, uuid, date, uuid, bigint, text) from public, anon, authenticated;
grant execute on function public.post_supplier_payment(uuid, uuid, uuid, date, uuid, bigint, text) to authenticated;

revoke all on function public.post_inventory_adjustment(uuid, uuid, date, text, jsonb) from public, anon, authenticated;
grant execute on function public.post_inventory_adjustment(uuid, uuid, date, text, jsonb) to authenticated;

-- Revoke PUBLIC from helper functions
revoke all on function app.calc_weighted_avg(integer, bigint, integer, bigint) from public;
revoke all on function app.get_inventory_account_id(uuid, public.unit_condition) from public;
revoke all on function app.update_stock_balance(uuid, uuid, integer, bigint) from public;
