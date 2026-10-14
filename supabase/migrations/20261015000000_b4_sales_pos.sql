-- B4: cash sales (POS), split payments, cash-sale returns, and cost-data isolation.

create type public.sale_kind as enum ('cash', 'installment');

create table public.sales_invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  doc_no bigint not null check (doc_no > 0),
  doc_date date not null,
  customer_id uuid,
  kind public.sale_kind not null default 'cash',
  gross_total bigint not null check (gross_total > 0),
  discount_total bigint not null default 0 check (discount_total >= 0),
  net_total bigint not null check (net_total > 0),
  status text not null default 'posted' check (status in ('posted', 'reversed')),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  unique (tenant_id, request_id),
  foreign key (tenant_id, customer_id) references public.customers(tenant_id, id),
  check (gross_total = discount_total + net_total)
);
create unique index sales_invoices_tenant_year_doc_key
  on public.sales_invoices (tenant_id, extract(year from doc_date), doc_no);
create index sales_invoices_tenant_date_idx on public.sales_invoices (tenant_id, doc_date, doc_no);
create index sales_invoices_tenant_customer_idx
  on public.sales_invoices (tenant_id, customer_id, doc_date) where customer_id is not null;

create table public.sales_invoice_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  invoice_id uuid not null,
  line_no integer not null check (line_no > 0),
  product_id uuid not null,
  unit_id uuid,
  qty integer not null check (qty > 0),
  cash_price bigint not null check (cash_price > 0),
  gross_amount bigint not null check (gross_amount > 0),
  discount bigint not null default 0 check (discount >= 0),
  net_amount bigint not null check (net_amount > 0),
  cost_snapshot bigint not null check (cost_snapshot >= 0),
  unique (tenant_id, id),
  unique (invoice_id, line_no),
  foreign key (tenant_id, invoice_id) references public.sales_invoices(tenant_id, id),
  foreign key (tenant_id, product_id) references public.products(tenant_id, id),
  foreign key (tenant_id, unit_id) references public.inventory_units(tenant_id, id),
  check (gross_amount = cash_price * qty),
  check (gross_amount = discount + net_amount)
);
create index sales_invoice_lines_tenant_product_idx
  on public.sales_invoice_lines (tenant_id, product_id, invoice_id);
create index sales_invoice_lines_tenant_unit_idx
  on public.sales_invoice_lines (tenant_id, unit_id) where unit_id is not null;

create table public.sales_payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  invoice_id uuid not null,
  cash_account_id uuid not null,
  amount bigint not null check (amount > 0),
  unique (tenant_id, id),
  foreign key (tenant_id, invoice_id) references public.sales_invoices(tenant_id, id),
  foreign key (tenant_id, cash_account_id) references public.cash_accounts(tenant_id, id)
);
create index sales_payments_tenant_invoice_idx
  on public.sales_payments (tenant_id, invoice_id);

create table public.sales_returns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  doc_no bigint not null check (doc_no > 0),
  doc_date date not null,
  original_invoice_id uuid not null,
  customer_id uuid,
  gross_total bigint not null check (gross_total > 0),
  discount_total bigint not null default 0 check (discount_total >= 0),
  total_refund bigint not null check (total_refund > 0),
  refund_cash_account_id uuid not null,
  reason text not null check (btrim(reason) <> ''),
  status text not null default 'posted' check (status in ('posted', 'reversed')),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  unique (tenant_id, request_id),
  foreign key (tenant_id, original_invoice_id) references public.sales_invoices(tenant_id, id),
  foreign key (tenant_id, customer_id) references public.customers(tenant_id, id),
  foreign key (tenant_id, refund_cash_account_id) references public.cash_accounts(tenant_id, id),
  check (gross_total = discount_total + total_refund)
);
create unique index sales_returns_tenant_year_doc_key
  on public.sales_returns (tenant_id, extract(year from doc_date), doc_no);
create index sales_returns_tenant_invoice_idx
  on public.sales_returns (tenant_id, original_invoice_id, doc_date);

create table public.sales_return_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  return_id uuid not null,
  original_line_id uuid not null,
  unit_id uuid,
  qty integer not null check (qty > 0),
  gross_amount bigint not null check (gross_amount > 0),
  discount bigint not null default 0 check (discount >= 0),
  refund_amount bigint not null check (refund_amount > 0),
  cost_snapshot bigint not null check (cost_snapshot >= 0),
  return_condition public.unit_condition not null default 'new',
  unique (tenant_id, id),
  unique (return_id, original_line_id),
  foreign key (tenant_id, return_id) references public.sales_returns(tenant_id, id)
    deferrable initially deferred,
  foreign key (tenant_id, original_line_id) references public.sales_invoice_lines(tenant_id, id),
  foreign key (tenant_id, unit_id) references public.inventory_units(tenant_id, id),
  check (gross_amount = discount + refund_amount)
);
create index sales_return_lines_tenant_original_idx
  on public.sales_return_lines (tenant_id, original_line_id);

alter table public.sales_invoices enable row level security;
alter table public.sales_invoice_lines enable row level security;
alter table public.sales_payments enable row level security;
alter table public.sales_returns enable row level security;
alter table public.sales_return_lines enable row level security;

create policy sales_invoices_select_member on public.sales_invoices
  for select to authenticated using (app.is_member(tenant_id));
create policy sales_invoice_lines_select_cost_role on public.sales_invoice_lines
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );
create policy sales_payments_select_member on public.sales_payments
  for select to authenticated using (app.is_member(tenant_id));
create policy sales_returns_select_member on public.sales_returns
  for select to authenticated using (app.is_member(tenant_id));
create policy sales_return_lines_select_cost_role on public.sales_return_lines
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );

create trigger guard_sales_invoices_mutation
  before update or delete on public.sales_invoices
  for each row execute function app.reject_mutation();
create trigger guard_sales_invoice_lines_mutation
  before update or delete on public.sales_invoice_lines
  for each row execute function app.reject_mutation();
create trigger guard_sales_payments_mutation
  before update or delete on public.sales_payments
  for each row execute function app.reject_mutation();
create trigger guard_sales_returns_mutation
  before update or delete on public.sales_returns
  for each row execute function app.reject_mutation();
create trigger guard_sales_return_lines_mutation
  before update or delete on public.sales_return_lines
  for each row execute function app.reject_mutation();

-- B4 closes the B3 cost leak. Privileged users use base tables; POS users use safe views below.
drop policy if exists inventory_units_tenant_isolation on public.inventory_units;
drop policy if exists stock_balances_tenant_isolation on public.stock_balances;
drop policy if exists stock_movements_tenant_isolation on public.stock_movements;
drop policy if exists purchase_invoices_tenant_isolation on public.purchase_invoices;
drop policy if exists purchase_invoice_lines_tenant_isolation on public.purchase_invoice_lines;
create policy inventory_units_select_cost_role on public.inventory_units
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );
create policy stock_balances_select_cost_role on public.stock_balances
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );
create policy stock_movements_select_cost_role on public.stock_movements
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );
create policy purchase_invoices_select_purchase_role on public.purchase_invoices
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );
create policy purchase_invoice_lines_select_cost_role on public.purchase_invoice_lines
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );

drop policy if exists journal_lines_select_member on public.journal_lines;
create policy journal_lines_select_financial_role on public.journal_lines
  for select to authenticated using (
    app.has_role(tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
  );

create view public.sales_invoice_lines_no_cost
with (security_barrier = true)
as
select id, tenant_id, invoice_id, line_no, product_id, unit_id, qty,
       cash_price, gross_amount, discount, net_amount
from public.sales_invoice_lines
where app.is_member(tenant_id);

create view public.sales_return_lines_no_cost
with (security_barrier = true)
as
select id, tenant_id, return_id, original_line_id, unit_id, qty,
       gross_amount, discount, refund_amount, return_condition
from public.sales_return_lines
where app.is_member(tenant_id);

create view public.pos_products
with (security_barrier = true)
as
select p.id,
       p.tenant_id,
       p.name_ar,
       p.model,
       p.barcode,
       p.tracking,
       p.default_price::text as default_price,
       p.category_id,
       p.brand_id,
       case
         when p.tracking = 'serial' then (
           select count(*)::integer
           from public.inventory_units iu
           where iu.tenant_id = p.tenant_id
             and iu.product_id = p.id
             and iu.status = 'in_stock'
         )
         else coalesce((
           select sb.qty
           from public.stock_balances sb
           where sb.tenant_id = p.tenant_id and sb.product_id = p.id
         ), 0)
       end as available_qty
from public.products p
where p.is_active
  and app.has_role(p.tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[]);

create view public.pos_inventory_units
with (security_barrier = true)
as
select iu.id, iu.tenant_id, iu.product_id, iu.serial_no, iu.condition
from public.inventory_units iu
where iu.status = 'in_stock'
  and app.has_role(iu.tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[]);

create view public.pos_cash_accounts
with (security_barrier = true)
as
select ca.id, ca.tenant_id, ca.name, ca.type
from public.cash_accounts ca
where ca.is_active
  and app.has_role(ca.tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[]);

create or replace function app.money_from_json(p_value jsonb, p_field text, p_allow_zero boolean)
returns bigint
language plpgsql
immutable
set search_path = public, pg_temp
as $$
declare
  v_text text;
begin
  if p_value is null or jsonb_typeof(p_value) <> 'string' then
    raise exception using errcode = '22023', message = p_field || ' must be a decimal string';
  end if;
  v_text := p_value #>> '{}';
  if v_text !~ '^(0|[1-9][0-9]*)$' then
    raise exception using errcode = '22023', message = p_field || ' must be a canonical non-negative decimal string';
  end if;
  begin
    if not p_allow_zero and v_text = '0' then
      raise exception using errcode = '22023', message = p_field || ' must be greater than zero';
    end if;
    return v_text::bigint;
  exception when numeric_value_out_of_range then
    raise exception using errcode = '22003', message = p_field || ' is outside bigint range';
  end;
end;
$$;

create or replace function app.money_from_text(p_value text, p_field text, p_allow_zero boolean)
returns bigint
language plpgsql
immutable
set search_path = public, pg_temp
as $$
begin
  return app.money_from_json(to_jsonb(p_value), p_field, p_allow_zero);
end;
$$;

create or replace function public.post_cash_sale(
  p_tenant_id uuid,
  p_request_id uuid,
  p_doc_date date,
  p_customer_id uuid default null,
  p_lines jsonb default '[]'::jsonb,
  p_payments jsonb default '[]'::jsonb,
  p_invoice_discount text default '0'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_tenant_status public.tenant_status;
  v_lock_date date;
  v_cashier_discount_bp integer;
  v_role public.membership_role;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
  v_invoice_id uuid := gen_random_uuid();
  v_doc_no bigint;
  v_line jsonb;
  v_payment jsonb;
  v_product public.products%rowtype;
  v_unit public.inventory_units%rowtype;
  v_balance public.stock_balances%rowtype;
  v_line_no integer := 0;
  v_qty integer;
  v_cash_price bigint;
  v_line_discount bigint;
  v_invoice_discount bigint;
  v_invoice_discount_allocated bigint := 0;
  v_invoice_discount_share bigint;
  v_gross bigint;
  v_pre_invoice_net bigint := 0;
  v_line_net_before_invoice bigint;
  v_line_net bigint;
  v_cost bigint;
  v_gross_total bigint := 0;
  v_line_discount_total bigint := 0;
  v_discount_total bigint;
  v_net_total bigint;
  v_payment_total bigint := 0;
  v_cash_gl_account_id uuid;
  v_sales_account_id uuid;
  v_discount_account_id uuid;
  v_cogs_account_id uuid;
  v_inventory_account_id uuid;
  v_je_lines jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if p_request_id is null or p_doc_date is null then
    raise exception using errcode = '22023', message = 'بيانات الفاتورة غير مكتملة';
  end if;
  if not app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'لا تملك صلاحية البيع';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text || ':' || p_request_id::text, 0));
  v_payload_hash := encode(extensions.digest(convert_to(
    p_doc_date::text || '|' || coalesce(p_customer_id::text, '') || '|' ||
    p_lines::text || '|' || p_payments::text || '|' || coalesce(p_invoice_discount, ''),
    'UTF8'
  ), 'sha256'), 'hex');
  select result, payload_hash into v_existing_result, v_existing_hash
  from public.posting_requests
  where tenant_id = p_tenant_id and request_id = p_request_id and status = 'completed';
  if found then
    if v_existing_hash <> v_payload_hash then
      raise exception using errcode = '23514', message = 'request_id مستخدم ببيانات مختلفة';
    end if;
    return v_existing_result;
  end if;

  select t.status, t.lock_date, m.role,
         coalesce((t.settings->>'max_cashier_discount_bp')::integer, 0)
  into v_tenant_status, v_lock_date, v_role, v_cashier_discount_bp
  from public.tenants t
  join public.memberships m on m.tenant_id = t.id and m.user_id = v_actor and m.is_active
  where t.id = p_tenant_id;
  if v_tenant_status = 'suspended' then
    raise exception using errcode = '55000', message = 'المتجر موقوف مؤقتاً';
  end if;
  if v_lock_date is not null and p_doc_date <= v_lock_date then
    raise exception using errcode = '55000', message = 'لا يمكن الترحيل في تاريخ مقفل';
  end if;
  if p_doc_date > (now() at time zone 'Africa/Cairo')::date then
    raise exception using errcode = '22023', message = 'لا يمكن البيع بتاريخ مستقبلي';
  end if;
  if p_customer_id is not null and not exists (
    select 1 from public.customers c
    where c.tenant_id = p_tenant_id and c.id = p_customer_id and c.is_active
  ) then
    raise exception using errcode = '22023', message = 'العميل غير موجود أو غير نشط';
  end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = '22023', message = 'يجب إضافة منتج واحد على الأقل';
  end if;
  if jsonb_typeof(p_payments) <> 'array' or jsonb_array_length(p_payments) = 0 then
    raise exception using errcode = '22023', message = 'يجب تحديد طريقة الدفع';
  end if;
  v_invoice_discount := app.money_from_text(p_invoice_discount, 'invoice_discount', true);

  if exists (
    select 1
    from jsonb_array_elements(p_lines) with ordinality as a(value, ordinality)
    join jsonb_array_elements(p_lines) with ordinality as b(value, ordinality)
      on a.ordinality < b.ordinality
     and a.value->>'unit_id' is not null
     and a.value->>'unit_id' = b.value->>'unit_id'
  ) then
    raise exception using errcode = '22023', message = 'لا يمكن تكرار نفس الوحدة في الفاتورة';
  end if;

  v_line_no := 0;
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_line_no := v_line_no + 1;
    if jsonb_typeof(v_line) <> 'object'
       or jsonb_typeof(v_line->'product_id') <> 'string'
       or jsonb_typeof(v_line->'qty') <> 'number' then
      raise exception using errcode = '22023', message = 'بيانات الصنف غير صحيحة';
    end if;
    v_qty := (v_line->>'qty')::integer;
    if v_qty <= 0 or (v_line->>'qty')::numeric <> v_qty then
      raise exception using errcode = '22023', message = 'الكمية يجب أن تكون عدداً صحيحاً موجباً';
    end if;
    v_cash_price := app.money_from_json(v_line->'cash_price', 'cash_price', false);
    v_line_discount := app.money_from_json(coalesce(v_line->'discount', '"0"'::jsonb), 'discount', true);
    v_gross := v_cash_price * v_qty;
    if v_line_discount >= v_gross then
      raise exception using errcode = '22023', message = 'خصم الصنف يجب أن يكون أقل من إجمالي الصنف';
    end if;
    select * into v_product from public.products
    where tenant_id = p_tenant_id and id = (v_line->>'product_id')::uuid and is_active;
    if not found then
      raise exception using errcode = '22023', message = 'المنتج غير موجود أو غير نشط';
    end if;
    if v_product.tracking = 'serial' then
      if v_qty <> 1 or jsonb_typeof(v_line->'unit_id') <> 'string' then
        raise exception using errcode = '22023', message = 'الصنف المسلسل يتطلب وحدة واحدة محددة';
      end if;
    elsif v_line ? 'unit_id' and v_line->'unit_id' <> 'null'::jsonb then
      raise exception using errcode = '22023', message = 'لا يقبل صنف الكمية رقم وحدة';
    end if;
    v_gross_total := v_gross_total + v_gross;
    v_line_discount_total := v_line_discount_total + v_line_discount;
    v_pre_invoice_net := v_pre_invoice_net + v_gross - v_line_discount;
  end loop;

  if v_invoice_discount >= v_pre_invoice_net then
    raise exception using errcode = '22023', message = 'خصم الفاتورة يجب أن يكون أقل من الإجمالي بعد خصم الأصناف';
  end if;
  v_discount_total := v_line_discount_total + v_invoice_discount;
  v_net_total := v_gross_total - v_discount_total;
  if v_role = 'cashier' and v_discount_total * 10000 > v_gross_total * v_cashier_discount_bp then
    raise exception using errcode = '42501', message = 'الخصم يتجاوز الحد المسموح للكاشير';
  end if;

  for v_payment in select value from jsonb_array_elements(p_payments)
  loop
    if jsonb_typeof(v_payment) <> 'object'
       or jsonb_typeof(v_payment->'cash_account_id') <> 'string' then
      raise exception using errcode = '22023', message = 'بيانات الدفع غير صحيحة';
    end if;
    v_payment_total := v_payment_total + app.money_from_json(v_payment->'amount', 'payment.amount', false);
    if not exists (
      select 1 from public.cash_accounts ca
      where ca.tenant_id = p_tenant_id
        and ca.id = (v_payment->>'cash_account_id')::uuid
        and ca.is_active
    ) then
      raise exception using errcode = '22023', message = 'حساب الدفع غير موجود أو غير نشط';
    end if;
  end loop;
  if v_payment_total <> v_net_total then
    raise exception using errcode = '22023', message = 'إجمالي المدفوعات لا يساوي صافي الفاتورة';
  end if;

  -- Deterministic row locking prevents double-selling serials and overselling quantities.
  perform 1
  from public.inventory_units iu
  where iu.tenant_id = p_tenant_id
    and iu.id in (
      select (value->>'unit_id')::uuid
      from jsonb_array_elements(p_lines)
      where jsonb_typeof(value->'unit_id') = 'string'
    )
  order by iu.id
  for update;
  perform 1
  from public.stock_balances sb
  where sb.tenant_id = p_tenant_id
    and sb.product_id in (
      select (value->>'product_id')::uuid
      from jsonb_array_elements(p_lines)
    )
  order by sb.product_id
  for update;
  perform 1 from public.tenants where id = p_tenant_id for update;

  if exists (
    select 1
    from jsonb_array_elements(p_lines) l
    join public.products p on p.tenant_id = p_tenant_id and p.id = (l.value->>'product_id')::uuid
    left join public.inventory_units iu
      on iu.tenant_id = p_tenant_id and iu.id = nullif(l.value->>'unit_id', '')::uuid
    where p.tracking = 'serial'
      and (iu.id is null or iu.product_id <> p.id or iu.status <> 'in_stock')
  ) then
    raise exception using errcode = '40001', message = 'إحدى الوحدات المسلسلة لم تعد متاحة';
  end if;
  if exists (
    select 1
    from (
      select (l.value->>'product_id')::uuid as product_id,
             sum((l.value->>'qty')::integer)::integer as requested_qty
      from jsonb_array_elements(p_lines) l
      join public.products p on p.tenant_id = p_tenant_id and p.id = (l.value->>'product_id')::uuid
      where p.tracking = 'quantity'
      group by (l.value->>'product_id')::uuid
    ) requested
    left join public.stock_balances sb
      on sb.tenant_id = p_tenant_id and sb.product_id = requested.product_id
    where sb.product_id is null or sb.qty < requested.requested_qty
  ) then
    raise exception using errcode = '23514', message = 'الكمية المطلوبة غير متاحة';
  end if;

  select id into v_sales_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'sales';
  select id into v_discount_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'sales_discounts';
  select id into v_cogs_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'cogs';

  v_doc_no := app.next_document_number(
    p_tenant_id, 'cash_sale', extract(year from p_doc_date)::integer, v_actor
  );
  insert into public.sales_invoices (
    id, tenant_id, doc_no, doc_date, customer_id, kind,
    gross_total, discount_total, net_total, request_id, created_by
  ) values (
    v_invoice_id, p_tenant_id, v_doc_no, p_doc_date, p_customer_id, 'cash',
    v_gross_total, v_discount_total, v_net_total, p_request_id, v_actor
  );

  v_line_no := 0;
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_line_no := v_line_no + 1;
    v_qty := (v_line->>'qty')::integer;
    v_cash_price := app.money_from_json(v_line->'cash_price', 'cash_price', false);
    v_line_discount := app.money_from_json(coalesce(v_line->'discount', '"0"'::jsonb), 'discount', true);
    v_gross := v_cash_price * v_qty;
    v_line_net_before_invoice := v_gross - v_line_discount;
    if v_line_no = jsonb_array_length(p_lines) then
      v_invoice_discount_share := v_invoice_discount - v_invoice_discount_allocated;
    else
      v_invoice_discount_share := (v_invoice_discount * v_line_net_before_invoice) / v_pre_invoice_net;
      v_invoice_discount_allocated := v_invoice_discount_allocated + v_invoice_discount_share;
    end if;
    v_line_discount := v_line_discount + v_invoice_discount_share;
    v_line_net := v_gross - v_line_discount;

    select * into v_product from public.products
      where tenant_id = p_tenant_id and id = (v_line->>'product_id')::uuid;
    if v_product.tracking = 'serial' then
      select * into v_unit from public.inventory_units
      where tenant_id = p_tenant_id and id = (v_line->>'unit_id')::uuid
      for update;
      v_cost := v_unit.unit_cost;
      v_inventory_account_id := app.get_inventory_account_id(p_tenant_id, v_unit.condition);
      update public.inventory_units set status = 'sold'
      where tenant_id = p_tenant_id and id = v_unit.id and status = 'in_stock';
      if not found then
        raise exception using errcode = '40001', message = 'الوحدة المسلسلة بيعت بالفعل';
      end if;
      insert into public.stock_movements (
        tenant_id, product_id, unit_id, movement_type, qty, unit_cost,
        document_type, document_id, created_by
      ) values (
        p_tenant_id, v_product.id, v_unit.id, 'sale', -1, v_unit.unit_cost,
        'sales_invoice', v_invoice_id, v_actor
      );
    else
      select * into v_balance from public.stock_balances
      where tenant_id = p_tenant_id and product_id = v_product.id for update;
      v_cost := v_balance.avg_cost * v_qty;
      v_inventory_account_id := app.get_inventory_account_id(p_tenant_id, 'new');
      perform app.update_stock_balance(p_tenant_id, v_product.id, -v_qty, 0);
      insert into public.stock_movements (
        tenant_id, product_id, unit_id, movement_type, qty, unit_cost,
        document_type, document_id, created_by
      ) values (
        p_tenant_id, v_product.id, null, 'sale', -v_qty, v_balance.avg_cost,
        'sales_invoice', v_invoice_id, v_actor
      );
    end if;

    insert into public.sales_invoice_lines (
      tenant_id, invoice_id, line_no, product_id, unit_id, qty,
      cash_price, gross_amount, discount, net_amount, cost_snapshot
    ) values (
      p_tenant_id, v_invoice_id, v_line_no, v_product.id,
      nullif(v_line->>'unit_id', '')::uuid, v_qty,
      v_cash_price, v_gross, v_line_discount, v_line_net, v_cost
    );

    v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_sales_account_id::text, 'debit', '0', 'credit', v_gross::text,
      'customer_id', coalesce(p_customer_id::text, ''), 'product_id', v_product.id::text,
      'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
    ));
    if v_line_discount > 0 then
      v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
        'account_id', v_discount_account_id::text, 'debit', v_line_discount::text, 'credit', '0',
        'customer_id', coalesce(p_customer_id::text, ''), 'product_id', v_product.id::text,
        'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
      ));
    end if;
    if v_cost > 0 then
      v_je_lines := v_je_lines || jsonb_build_array(
        jsonb_build_object(
          'account_id', v_cogs_account_id::text, 'debit', v_cost::text, 'credit', '0',
          'product_id', v_product.id::text,
          'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
        ),
        jsonb_build_object(
          'account_id', v_inventory_account_id::text, 'debit', '0', 'credit', v_cost::text,
          'product_id', v_product.id::text,
          'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
        )
      );
    end if;
  end loop;

  for v_payment in select value from jsonb_array_elements(p_payments)
  loop
    select gl_account_id into v_cash_gl_account_id from public.cash_accounts
    where tenant_id = p_tenant_id and id = (v_payment->>'cash_account_id')::uuid;
    v_cost := app.money_from_json(v_payment->'amount', 'payment.amount', false);
    insert into public.sales_payments (tenant_id, invoice_id, cash_account_id, amount)
    values (p_tenant_id, v_invoice_id, (v_payment->>'cash_account_id')::uuid, v_cost);
    v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_cash_gl_account_id::text, 'debit', v_cost::text, 'credit', '0',
      'customer_id', coalesce(p_customer_id::text, ''),
      'cash_account_id', v_payment->>'cash_account_id', 'user_id', v_actor::text
    ));
  end loop;

  perform app.create_journal_entry(
    p_tenant_id, v_invoice_id, p_doc_date, 'sales_invoice', v_invoice_id,
    'فاتورة بيع كاش رقم ' || v_doc_no, v_je_lines
  );
  v_result := jsonb_build_object('id', v_invoice_id::text, 'doc_no', v_doc_no::text);
  insert into public.posting_requests (
    tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at
  ) values (
    p_tenant_id, p_request_id, 'post_cash_sale', v_payload_hash,
    'completed', v_result, v_actor, now()
  );
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, request_id, after_data)
  values (
    p_tenant_id, v_actor, 'cash_sale.post', 'sales_invoice', v_invoice_id, p_request_id,
    jsonb_build_object('doc_no', v_doc_no::text, 'net_total', v_net_total::text)
  );
  return v_result;
end;
$$;

create or replace function public.post_sales_return(
  p_tenant_id uuid,
  p_request_id uuid,
  p_original_invoice_id uuid,
  p_doc_date date,
  p_lines jsonb,
  p_refund_cash_account_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_tenant_status public.tenant_status;
  v_lock_date date;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
  v_invoice public.sales_invoices%rowtype;
  v_original public.sales_invoice_lines%rowtype;
  v_product public.products%rowtype;
  v_line jsonb;
  v_return_id uuid := gen_random_uuid();
  v_doc_no bigint;
  v_qty integer;
  v_returned_qty integer;
  v_returned_gross bigint;
  v_returned_discount bigint;
  v_returned_cost bigint;
  v_remaining_qty integer;
  v_gross bigint;
  v_discount bigint;
  v_refund bigint;
  v_cost bigint;
  v_total_gross bigint := 0;
  v_total_discount bigint := 0;
  v_total_refund bigint := 0;
  v_cash_gl_account_id uuid;
  v_sales_return_account_id uuid;
  v_discount_account_id uuid;
  v_cogs_account_id uuid;
  v_inventory_account_id uuid;
  v_condition public.unit_condition;
  v_je_lines jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if p_request_id is null or p_original_invoice_id is null or p_doc_date is null
     or p_refund_cash_account_id is null or btrim(coalesce(p_reason, '')) = '' then
    raise exception using errcode = '22023', message = 'بيانات المرتجع غير مكتملة';
  end if;
  if not app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'لا تملك صلاحية تنفيذ المرتجع';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text || ':' || p_request_id::text, 0));
  v_payload_hash := encode(extensions.digest(convert_to(
    p_original_invoice_id::text || '|' || p_doc_date::text || '|' || p_lines::text || '|' ||
    p_refund_cash_account_id::text || '|' || btrim(p_reason), 'UTF8'
  ), 'sha256'), 'hex');
  select result, payload_hash into v_existing_result, v_existing_hash
  from public.posting_requests
  where tenant_id = p_tenant_id and request_id = p_request_id and status = 'completed';
  if found then
    if v_existing_hash <> v_payload_hash then
      raise exception using errcode = '23514', message = 'request_id مستخدم ببيانات مختلفة';
    end if;
    return v_existing_result;
  end if;

  select status, lock_date into v_tenant_status, v_lock_date
  from public.tenants where id = p_tenant_id;
  if v_tenant_status = 'suspended' then
    raise exception using errcode = '55000', message = 'المتجر موقوف مؤقتاً';
  end if;
  if v_lock_date is not null and p_doc_date <= v_lock_date then
    raise exception using errcode = '55000', message = 'لا يمكن الترحيل في تاريخ مقفل';
  end if;
  if p_doc_date > (now() at time zone 'Africa/Cairo')::date then
    raise exception using errcode = '22023', message = 'لا يمكن تنفيذ مرتجع بتاريخ مستقبلي';
  end if;
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = '22023', message = 'يجب تحديد صنف مرتجع واحد على الأقل';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_lines) with ordinality as a(value, ordinality)
    join jsonb_array_elements(p_lines) with ordinality as b(value, ordinality)
      on a.ordinality < b.ordinality
     and a.value->>'original_line_id' = b.value->>'original_line_id'
  ) then
    raise exception using errcode = '22023', message = 'لا يمكن تكرار سطر الفاتورة في المرتجع';
  end if;

  select * into v_invoice from public.sales_invoices
  where tenant_id = p_tenant_id and id = p_original_invoice_id
    and kind = 'cash' and status = 'posted'
  for update;
  if not found then
    raise exception using errcode = '22023', message = 'فاتورة البيع الكاش الأصلية غير موجودة';
  end if;
  select gl_account_id into v_cash_gl_account_id from public.cash_accounts
  where tenant_id = p_tenant_id and id = p_refund_cash_account_id and is_active;
  if not found then
    raise exception using errcode = '22023', message = 'حساب رد المبلغ غير موجود أو غير نشط';
  end if;

  perform 1 from public.sales_invoice_lines sil
  where sil.tenant_id = p_tenant_id
    and sil.invoice_id = p_original_invoice_id
    and sil.id in (
      select (value->>'original_line_id')::uuid from jsonb_array_elements(p_lines)
    )
  order by sil.id for update;
  perform 1 from public.tenants where id = p_tenant_id for update;

  select id into v_sales_return_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'sales_returns';
  select id into v_discount_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'sales_discounts';
  select id into v_cogs_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'cogs';

  v_doc_no := app.next_document_number(
    p_tenant_id, 'cash_sale_return', extract(year from p_doc_date)::integer, v_actor
  );
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    if jsonb_typeof(v_line) <> 'object'
       or jsonb_typeof(v_line->'original_line_id') <> 'string'
       or jsonb_typeof(v_line->'qty') <> 'number'
       or jsonb_typeof(v_line->'return_condition') <> 'string' then
      raise exception using errcode = '22023', message = 'بيانات سطر المرتجع غير صحيحة';
    end if;
    v_qty := (v_line->>'qty')::integer;
    if v_qty <= 0 or (v_line->>'qty')::numeric <> v_qty then
      raise exception using errcode = '22023', message = 'كمية المرتجع يجب أن تكون عدداً صحيحاً موجباً';
    end if;
    begin
      v_condition := (v_line->>'return_condition')::public.unit_condition;
    exception when invalid_text_representation then
      raise exception using errcode = '22023', message = 'حالة الوحدة المرتجعة غير صحيحة';
    end;
    select * into v_original from public.sales_invoice_lines
    where tenant_id = p_tenant_id and invoice_id = p_original_invoice_id
      and id = (v_line->>'original_line_id')::uuid
    for update;
    if not found then
      raise exception using errcode = '22023', message = 'سطر الفاتورة الأصلية غير موجود';
    end if;
    select coalesce(sum(srl.qty), 0)::integer,
           coalesce(sum(srl.gross_amount), 0)::bigint,
           coalesce(sum(srl.discount), 0)::bigint,
           coalesce(sum(srl.cost_snapshot), 0)::bigint
    into v_returned_qty, v_returned_gross, v_returned_discount, v_returned_cost
    from public.sales_return_lines srl
    join public.sales_returns sr
      on sr.tenant_id = srl.tenant_id and sr.id = srl.return_id
    where srl.tenant_id = p_tenant_id
      and srl.original_line_id = v_original.id
      and sr.status = 'posted';
    v_remaining_qty := v_original.qty - v_returned_qty;
    if v_qty > v_remaining_qty then
      raise exception using errcode = '23514', message = 'كمية المرتجع تتجاوز الكمية المتبقية';
    end if;
    if v_qty = v_remaining_qty then
      v_gross := v_original.gross_amount - v_returned_gross;
      v_discount := v_original.discount - v_returned_discount;
      v_cost := v_original.cost_snapshot - v_returned_cost;
    else
      v_gross := (v_original.gross_amount * v_qty) / v_original.qty;
      v_discount := (v_original.discount * v_qty) / v_original.qty;
      v_cost := (v_original.cost_snapshot * v_qty) / v_original.qty;
    end if;
    v_refund := v_gross - v_discount;
    if v_refund <= 0 then
      raise exception using errcode = '23514', message = 'قيمة المرتجع يجب أن تكون موجبة';
    end if;

    select * into v_product from public.products
    where tenant_id = p_tenant_id and id = v_original.product_id;
    if v_product.tracking = 'serial' then
      if v_qty <> 1
         or jsonb_typeof(v_line->'unit_id') <> 'string'
         or (v_line->>'unit_id')::uuid <> v_original.unit_id then
        raise exception using errcode = '22023', message = 'الوحدة المرتجعة لا تطابق وحدة البيع';
      end if;
      perform 1 from public.inventory_units
      where tenant_id = p_tenant_id and id = v_original.unit_id and status = 'sold'
      for update;
      if not found then
        raise exception using errcode = '40001', message = 'الوحدة المرتجعة ليست في حالة مباعة';
      end if;
      update public.inventory_units
      set status = 'in_stock', condition = v_condition
      where tenant_id = p_tenant_id and id = v_original.unit_id and status = 'sold';
      insert into public.stock_movements (
        tenant_id, product_id, unit_id, movement_type, qty, unit_cost,
        document_type, document_id, created_by
      ) values (
        p_tenant_id, v_product.id, v_original.unit_id, 'return_in', 1, v_cost,
        'sales_return', v_return_id, v_actor
      );
      v_inventory_account_id := app.get_inventory_account_id(p_tenant_id, v_condition);
    else
      if v_line ? 'unit_id' and v_line->'unit_id' <> 'null'::jsonb then
        raise exception using errcode = '22023', message = 'صنف الكمية لا يقبل رقم وحدة';
      end if;
      perform app.update_stock_balance(
        p_tenant_id, v_product.id, v_qty,
        case when v_qty = 0 then 0 else v_cost / v_qty end
      );
      insert into public.stock_movements (
        tenant_id, product_id, unit_id, movement_type, qty, unit_cost,
        document_type, document_id, created_by
      ) values (
        p_tenant_id, v_product.id, null, 'return_in', v_qty,
        case when v_qty = 0 then 0 else v_cost / v_qty end,
        'sales_return', v_return_id, v_actor
      );
      v_inventory_account_id := app.get_inventory_account_id(p_tenant_id, 'new');
    end if;

    insert into public.sales_return_lines (
      tenant_id, return_id, original_line_id, unit_id, qty,
      gross_amount, discount, refund_amount, cost_snapshot, return_condition
    ) values (
      p_tenant_id, v_return_id, v_original.id, v_original.unit_id, v_qty,
      v_gross, v_discount, v_refund, v_cost, v_condition
    );
    v_total_gross := v_total_gross + v_gross;
    v_total_discount := v_total_discount + v_discount;
    v_total_refund := v_total_refund + v_refund;

    v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_sales_return_account_id::text, 'debit', v_gross::text, 'credit', '0',
      'customer_id', coalesce(v_invoice.customer_id::text, ''), 'product_id', v_product.id::text,
      'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
    ));
    if v_discount > 0 then
      v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
        'account_id', v_discount_account_id::text, 'debit', '0', 'credit', v_discount::text,
        'customer_id', coalesce(v_invoice.customer_id::text, ''), 'product_id', v_product.id::text,
        'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
      ));
    end if;
    if v_cost > 0 then
      v_je_lines := v_je_lines || jsonb_build_array(
        jsonb_build_object(
          'account_id', v_inventory_account_id::text, 'debit', v_cost::text, 'credit', '0',
          'product_id', v_product.id::text,
          'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
        ),
        jsonb_build_object(
          'account_id', v_cogs_account_id::text, 'debit', '0', 'credit', v_cost::text,
          'product_id', v_product.id::text,
          'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
        )
      );
    end if;
  end loop;

  insert into public.sales_returns (
    id, tenant_id, doc_no, doc_date, original_invoice_id, customer_id,
    gross_total, discount_total, total_refund, refund_cash_account_id,
    reason, request_id, created_by
  ) values (
    v_return_id, p_tenant_id, v_doc_no, p_doc_date, p_original_invoice_id,
    v_invoice.customer_id, v_total_gross, v_total_discount, v_total_refund,
    p_refund_cash_account_id, btrim(p_reason), p_request_id, v_actor
  );

  v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
    'account_id', v_cash_gl_account_id::text, 'debit', '0', 'credit', v_total_refund::text,
    'customer_id', coalesce(v_invoice.customer_id::text, ''),
    'cash_account_id', p_refund_cash_account_id::text, 'user_id', v_actor::text
  ));
  perform app.create_journal_entry(
    p_tenant_id, v_return_id, p_doc_date, 'sales_return', v_return_id,
    'مرتجع بيع كاش رقم ' || v_doc_no, v_je_lines
  );
  v_result := jsonb_build_object('id', v_return_id::text, 'doc_no', v_doc_no::text);
  insert into public.posting_requests (
    tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at
  ) values (
    p_tenant_id, p_request_id, 'post_sales_return', v_payload_hash,
    'completed', v_result, v_actor, now()
  );
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, request_id, after_data)
  values (
    p_tenant_id, v_actor, 'cash_sale_return.post', 'sales_return', v_return_id, p_request_id,
    jsonb_build_object('doc_no', v_doc_no::text, 'total_refund', v_total_refund::text)
  );
  return v_result;
end;
$$;

revoke insert, update, delete, truncate on public.sales_invoices,
  public.sales_invoice_lines, public.sales_payments, public.sales_returns,
  public.sales_return_lines from authenticated;
grant select on public.sales_invoices, public.sales_invoice_lines, public.sales_payments,
  public.sales_returns, public.sales_return_lines to authenticated;
grant select on public.sales_invoice_lines_no_cost, public.sales_return_lines_no_cost,
  public.pos_products, public.pos_inventory_units, public.pos_cash_accounts to authenticated;

revoke all on function app.money_from_json(jsonb, text, boolean) from public, anon, authenticated;
revoke all on function app.money_from_text(text, text, boolean) from public, anon, authenticated;
revoke all on function public.post_cash_sale(uuid, uuid, date, uuid, jsonb, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.post_cash_sale(uuid, uuid, date, uuid, jsonb, jsonb, text)
  to authenticated;
revoke all on function public.post_sales_return(uuid, uuid, uuid, date, jsonb, uuid, text)
  from public, anon, authenticated;
grant execute on function public.post_sales_return(uuid, uuid, uuid, date, jsonb, uuid, text)
  to authenticated;
