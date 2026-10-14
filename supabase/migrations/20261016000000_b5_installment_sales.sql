-- B5: Installment sales — contracts, schedules, preview RPC, and posting with attachment validation.

-- Contract status enum
create type public.contract_status as enum (
  'active',
  'settled',
  'early_settled',
  'rescheduled',
  'written_off',
  'cancelled'
);

-- Installment status enum
create type public.installment_status as enum (
  'pending',
  'partially_paid',
  'paid',
  'frozen',
  'written_off',
  'cancelled'
);

-- Installment contracts table
create table public.installment_contracts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  doc_no bigint not null check (doc_no > 0),
  doc_date date not null,
  sales_invoice_id uuid not null,
  customer_id uuid not null,
  -- Guarantor snapshot (copied at contract time)
  guarantor_name text,
  guarantor_phone text,
  guarantor_national_id text,
  -- Financial fields (all in piasters)
  cash_total bigint not null check (cash_total > 0),
  down_payment bigint not null check (down_payment >= 0),
  financed_base bigint not null check (financed_base > 0),
  margin_total bigint not null check (margin_total >= 0),
  receivable bigint not null check (receivable > 0),
  months integer not null check (months >= 1 and months <= 60),
  factor_bp integer check (factor_bp is null or (factor_bp >= 0 and factor_bp <= 10000)),
  manual_price boolean not null default false,
  rounding_step bigint not null default 100 check (rounding_step in (100, 500, 1000)),
  first_due_date date not null,
  status public.contract_status not null default 'active',
  parent_contract_id uuid,
  request_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  -- Constraints
  unique (tenant_id, id),
  unique (tenant_id, request_id),
  foreign key (tenant_id, sales_invoice_id) references public.sales_invoices(tenant_id, id),
  foreign key (tenant_id, customer_id) references public.customers(tenant_id, id),
  foreign key (tenant_id, parent_contract_id) references public.installment_contracts(tenant_id, id),
  check (financed_base = cash_total - down_payment),
  check (receivable = financed_base + margin_total)
);

create unique index installment_contracts_tenant_year_doc_key
  on public.installment_contracts (tenant_id, extract(year from doc_date), doc_no);
create index installment_contracts_tenant_customer_idx
  on public.installment_contracts (tenant_id, customer_id, status);
create index installment_contracts_tenant_status_idx
  on public.installment_contracts (tenant_id, status, doc_date);

-- Installments table (schedule rows)
create table public.installments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  contract_id uuid not null,
  installment_no integer not null check (installment_no >= 1),
  due_date date not null,
  amount bigint not null check (amount > 0),
  principal bigint not null check (principal >= 0),
  margin bigint not null check (margin >= 0),
  paid_amount bigint not null default 0 check (paid_amount >= 0),
  paid_principal bigint not null default 0 check (paid_principal >= 0),
  paid_margin bigint not null default 0 check (paid_margin >= 0),
  status public.installment_status not null default 'pending',
  unique (tenant_id, id),
  unique (contract_id, installment_no),
  foreign key (tenant_id, contract_id) references public.installment_contracts(tenant_id, id),
  check (amount = principal + margin),
  check (paid_amount <= amount),
  check (paid_principal <= principal),
  check (paid_margin <= margin)
);

create index installments_tenant_contract_idx
  on public.installments (tenant_id, contract_id, installment_no);
create index installments_tenant_due_status_idx
  on public.installments (tenant_id, due_date, status)
  where status in ('pending', 'partially_paid');

-- Enable RLS
alter table public.installment_contracts enable row level security;
alter table public.installments enable row level security;

-- RLS policies
create policy installment_contracts_select_member on public.installment_contracts
  for select to authenticated using (app.is_member(tenant_id));
create policy installments_select_member on public.installments
  for select to authenticated using (app.is_member(tenant_id));

-- Mutation guards
create trigger guard_installment_contracts_mutation
  before update or delete on public.installment_contracts
  for each row execute function app.reject_mutation();
create trigger guard_installments_mutation
  before update or delete on public.installments
  for each row execute function app.reject_mutation();

-- Revoke direct writes
revoke insert, update, delete, truncate on public.installment_contracts, public.installments
  from authenticated;
grant select on public.installment_contracts, public.installments to authenticated;

--------------------------------------------------------------------------------
-- Preview installment schedule (pure function, no writes)
--------------------------------------------------------------------------------
create or replace function public.preview_installment_schedule(
  p_cash_total text,
  p_down_payment text,
  p_months integer,
  p_factor_bp integer default null,
  p_manual_deferred_price text default null,
  p_rounding_step bigint default 100,
  p_first_due_date date default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_cash_total bigint;
  v_down_payment bigint;
  v_financed_base bigint;
  v_margin_total bigint;
  v_receivable bigint;
  v_base_amount bigint;
  v_last_amount bigint;
  v_first_due date;
  v_schedule jsonb := '[]'::jsonb;
  v_principal_sum bigint := 0;
  v_margin_sum bigint := 0;
  v_amount bigint;
  v_principal bigint;
  v_margin bigint;
  v_due_date date;
  i integer;
begin
  -- Parse money values
  v_cash_total := app.money_from_text(p_cash_total, 'cash_total', false);
  v_down_payment := app.money_from_text(p_down_payment, 'down_payment', true);
  
  -- Validate months
  if p_months is null or p_months < 1 or p_months > 60 then
    raise exception using errcode = '22023', message = 'عدد الأقساط يجب أن يكون بين 1 و 60';
  end if;
  
  -- Validate rounding step
  if p_rounding_step not in (100, 500, 1000) then
    raise exception using errcode = '22023', message = 'خطوة التقريب يجب أن تكون 100 أو 500 أو 1000 قرش';
  end if;
  
  -- Calculate financed base
  v_financed_base := v_cash_total - v_down_payment;
  if v_financed_base <= 0 then
    raise exception using errcode = '22023', message = 'المبلغ المؤجل يجب أن يكون أكبر من صفر';
  end if;
  
  -- Calculate margin
  if p_manual_deferred_price is not null then
    declare
      v_deferred_price bigint;
    begin
      v_deferred_price := app.money_from_text(p_manual_deferred_price, 'deferred_price', false);
      v_margin_total := v_deferred_price - v_cash_total;
      if v_margin_total < 0 then
        raise exception using errcode = '22023', message = 'السعر الآجل يجب أن يكون أكبر من أو يساوي سعر الكاش';
      end if;
    end;
  else
    if p_factor_bp is null or p_factor_bp < 0 or p_factor_bp > 10000 then
      raise exception using errcode = '22023', message = 'معامل الآجل غير صحيح';
    end if;
    -- round_half_up: (value + 5000) / 10000 * 10000 doesn't work for arbitrary values
    -- Use: round(financed_base * factor_bp / 10000.0)
    v_margin_total := round(v_financed_base::numeric * p_factor_bp / 10000.0)::bigint;
  end if;
  
  v_receivable := v_financed_base + v_margin_total;
  
  -- Calculate base amount (ceil to step)
  -- ceil_to_step(x, step) = ceil(x / step) * step
  v_base_amount := (((v_receivable + p_months - 1) / p_months + p_rounding_step - 1) / p_rounding_step) * p_rounding_step;
  
  -- Last installment
  v_last_amount := v_receivable - v_base_amount * (p_months - 1);
  if v_last_amount <= 0 then
    raise exception using errcode = '22023', message = 'القسط الأخير صفر أو سالب — قلل عدد الأقساط أو خطوة التقريب';
  end if;
  
  -- First due date
  v_first_due := coalesce(p_first_due_date, (now() at time zone 'Africa/Cairo')::date + interval '1 month');
  
  -- Build schedule
  for i in 1..p_months loop
    if i < p_months then
      v_amount := v_base_amount;
    else
      v_amount := v_last_amount;
    end if;
    
    -- Calculate principal/margin split
    if i < p_months then
      v_principal := (v_financed_base * v_amount) / v_receivable;
      v_margin := v_amount - v_principal;
    else
      -- Last installment takes remainder
      v_principal := v_financed_base - v_principal_sum;
      v_margin := v_margin_total - v_margin_sum;
    end if;
    
    v_principal_sum := v_principal_sum + v_principal;
    v_margin_sum := v_margin_sum + v_margin;
    
    -- Calculate due date
    v_due_date := (v_first_due + ((i - 1) || ' months')::interval)::date;
    
    v_schedule := v_schedule || jsonb_build_array(jsonb_build_object(
      'installment_no', i,
      'due_date', v_due_date::text,
      'amount', v_amount::text,
      'principal', v_principal::text,
      'margin', v_margin::text
    ));
  end loop;
  
  -- Invariant assertions
  if v_principal_sum <> v_financed_base then
    raise exception using errcode = 'P0001', message = 'خطأ داخلي: مجموع الأصل لا يساوي المبلغ المؤجل';
  end if;
  if v_margin_sum <> v_margin_total then
    raise exception using errcode = 'P0001', message = 'خطأ داخلي: مجموع الهامش لا يساوي إجمالي الهامش';
  end if;
  
  return jsonb_build_object(
    'cash_total', v_cash_total::text,
    'down_payment', v_down_payment::text,
    'financed_base', v_financed_base::text,
    'margin_total', v_margin_total::text,
    'receivable', v_receivable::text,
    'months', p_months,
    'first_due_date', v_first_due::text,
    'rounding_step', p_rounding_step::text,
    'schedule', v_schedule
  );
end;
$$;

--------------------------------------------------------------------------------
-- Post installment sale
--------------------------------------------------------------------------------
create or replace function public.post_installment_sale(
  p_tenant_id uuid,
  p_request_id uuid,
  p_doc_date date,
  p_customer_id uuid,
  p_lines jsonb,
  p_down_payment text,
  p_down_payment_cash_account_id uuid,
  p_months integer,
  p_factor_bp integer default null,
  p_manual_deferred_price text default null,
  p_rounding_step bigint default 100,
  p_first_due_date date default null,
  p_upload_session_id uuid default null
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
  v_require_customer_id boolean;
  v_require_guarantor_id boolean;
  v_require_signed_contract boolean;
  v_min_down_payment_bp integer;
  v_role public.membership_role;
  v_cashier_discount_bp integer;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
  v_invoice_id uuid := gen_random_uuid();
  v_contract_id uuid := gen_random_uuid();
  v_invoice_doc_no bigint;
  v_contract_doc_no bigint;
  v_customer public.customers%rowtype;
  v_down_payment bigint;
  v_line jsonb;
  v_product public.products%rowtype;
  v_unit public.inventory_units%rowtype;
  v_balance public.stock_balances%rowtype;
  v_line_no integer := 0;
  v_qty integer;
  v_cash_price bigint;
  v_line_discount bigint;
  v_gross bigint;
  v_line_net bigint;
  v_cost bigint;
  v_gross_total bigint := 0;
  v_discount_total bigint := 0;
  v_cash_total bigint;
  v_financed_base bigint;
  v_margin_total bigint;
  v_receivable bigint;
  v_base_amount bigint;
  v_last_amount bigint;
  v_first_due date;
  v_amount bigint;
  v_principal bigint;
  v_margin bigint;
  v_principal_sum bigint := 0;
  v_margin_sum bigint := 0;
  v_due_date date;
  v_cash_gl_account_id uuid;
  v_sales_account_id uuid;
  v_discount_account_id uuid;
  v_cogs_account_id uuid;
  v_inventory_account_id uuid;
  v_receivable_account_id uuid;
  v_unearned_account_id uuid;
  v_je_lines jsonb := '[]'::jsonb;
  v_total_cost bigint := 0;
  v_result jsonb;
  i integer;
begin
  -- Basic validation
  if p_request_id is null or p_doc_date is null or p_customer_id is null then
    raise exception using errcode = '22023', message = 'بيانات العقد غير مكتملة';
  end if;
  if not app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'لا تملك صلاحية البيع بالتقسيط';
  end if;
  
  -- Idempotency lock
  perform pg_advisory_xact_lock(hashtextextended(p_tenant_id::text || ':' || p_request_id::text, 0));
  v_payload_hash := encode(extensions.digest(convert_to(
    p_doc_date::text || '|' || p_customer_id::text || '|' || p_lines::text || '|' ||
    p_down_payment || '|' || coalesce(p_down_payment_cash_account_id::text, '') || '|' ||
    p_months::text || '|' || coalesce(p_factor_bp::text, '') || '|' ||
    coalesce(p_manual_deferred_price, '') || '|' || p_rounding_step::text || '|' ||
    coalesce(p_first_due_date::text, ''),
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
  
  -- Load tenant settings
  select t.status, t.lock_date, m.role,
         coalesce((t.settings->>'require_customer_id_images')::boolean, true),
         coalesce((t.settings->>'require_guarantor_id_images')::boolean, false),
         coalesce((t.settings->>'require_signed_contract_upload')::boolean, false),
         coalesce((t.settings->>'min_down_payment_bp')::integer, 0),
         coalesce((t.settings->>'max_cashier_discount_bp')::integer, 0)
  into v_tenant_status, v_lock_date, v_role,
       v_require_customer_id, v_require_guarantor_id, v_require_signed_contract,
       v_min_down_payment_bp, v_cashier_discount_bp
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
  
  -- Validate customer
  select * into v_customer from public.customers
  where tenant_id = p_tenant_id and id = p_customer_id and is_active;
  if not found then
    raise exception using errcode = '22023', message = 'العميل غير موجود أو غير نشط';
  end if;
  if v_customer.phone1 is null or v_customer.address is null then
    raise exception using errcode = '22023', message = 'العميل يجب أن يكون له رقم هاتف وعنوان للبيع بالتقسيط';
  end if;
  
  -- Check required attachments (T25)
  if v_require_customer_id and p_upload_session_id is not null then
    if not exists (
      select 1 from public.attachments
      where tenant_id = p_tenant_id
        and upload_session_id = p_upload_session_id
        and owner_type = 'customer'
        and kind in ('national_id_front', 'national_id_back')
        and status = 'pending'
      having count(distinct kind) >= 2
    ) then
      raise exception using errcode = '22023', message = 'يجب رفع صورة البطاقة الشخصية للعميل (أمام وخلف)';
    end if;
  elsif v_require_customer_id and p_upload_session_id is null then
    -- Check if customer already has ID images
    if not exists (
      select 1 from public.attachments
      where tenant_id = p_tenant_id
        and owner_type = 'customer'
        and owner_id = p_customer_id
        and kind in ('national_id_front', 'national_id_back')
        and status = 'active'
      having count(distinct kind) >= 2
    ) then
      raise exception using errcode = '22023', message = 'يجب رفع صورة البطاقة الشخصية للعميل (أمام وخلف)';
    end if;
  end if;
  
  if v_require_guarantor_id and v_customer.guarantor_name is not null then
    -- Guarantor ID images would need to be attached
    -- For now, we check if the upload session has them
    if p_upload_session_id is not null and not exists (
      select 1 from public.attachments
      where tenant_id = p_tenant_id
        and upload_session_id = p_upload_session_id
        and owner_type = 'guarantor'
        and kind in ('national_id_front', 'national_id_back')
        and status = 'pending'
      having count(distinct kind) >= 2
    ) then
      raise exception using errcode = '22023', message = 'يجب رفع صورة البطاقة الشخصية للضامن (أمام وخلف)';
    end if;
  end if;
  
  -- Validate lines
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = '22023', message = 'يجب إضافة منتج واحد على الأقل';
  end if;
  
  -- Parse down payment
  v_down_payment := app.money_from_text(p_down_payment, 'down_payment', true);
  
  -- Validate cash account for down payment
  if v_down_payment > 0 then
    if p_down_payment_cash_account_id is null then
      raise exception using errcode = '22023', message = 'يجب تحديد حساب استلام المقدم';
    end if;
    select gl_account_id into v_cash_gl_account_id from public.cash_accounts
    where tenant_id = p_tenant_id and id = p_down_payment_cash_account_id and is_active;
    if not found then
      raise exception using errcode = '22023', message = 'حساب استلام المقدم غير موجود أو غير نشط';
    end if;
  end if;
  
  -- Check for duplicate units
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
  
  -- Calculate line totals (first pass)
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
    v_discount_total := v_discount_total + v_line_discount;
  end loop;
  
  v_cash_total := v_gross_total - v_discount_total;
  
  -- Validate discount for cashier
  if v_role = 'cashier' and v_discount_total * 10000 > v_gross_total * v_cashier_discount_bp then
    raise exception using errcode = '42501', message = 'الخصم يتجاوز الحد المسموح للكاشير';
  end if;
  
  -- Calculate installment schedule
  v_financed_base := v_cash_total - v_down_payment;
  if v_financed_base <= 0 then
    raise exception using errcode = '22023', message = 'المبلغ المؤجل يجب أن يكون أكبر من صفر';
  end if;
  
  -- Check minimum down payment
  if v_min_down_payment_bp > 0 and v_down_payment * 10000 < v_cash_total * v_min_down_payment_bp then
    raise exception using errcode = '22023', message = 'المقدم أقل من الحد الأدنى المطلوب';
  end if;
  
  -- Calculate margin
  if p_manual_deferred_price is not null then
    declare
      v_deferred_price bigint;
    begin
      v_deferred_price := app.money_from_text(p_manual_deferred_price, 'deferred_price', false);
      v_margin_total := v_deferred_price - v_cash_total;
      if v_margin_total < 0 then
        raise exception using errcode = '22023', message = 'السعر الآجل يجب أن يكون أكبر من أو يساوي سعر الكاش';
      end if;
    end;
  else
    if p_factor_bp is null or p_factor_bp < 0 or p_factor_bp > 10000 then
      raise exception using errcode = '22023', message = 'معامل الآجل غير صحيح';
    end if;
    v_margin_total := round(v_financed_base::numeric * p_factor_bp / 10000.0)::bigint;
  end if;
  
  v_receivable := v_financed_base + v_margin_total;
  
  -- Validate months
  if p_months < 1 or p_months > 60 then
    raise exception using errcode = '22023', message = 'عدد الأقساط يجب أن يكون بين 1 و 60';
  end if;
  
  -- Calculate base amount
  v_base_amount := (((v_receivable + p_months - 1) / p_months + p_rounding_step - 1) / p_rounding_step) * p_rounding_step;
  v_last_amount := v_receivable - v_base_amount * (p_months - 1);
  if v_last_amount <= 0 then
    raise exception using errcode = '22023', message = 'القسط الأخير صفر أو سالب — قلل عدد الأقساط أو خطوة التقريب';
  end if;
  
  v_first_due := coalesce(p_first_due_date, p_doc_date + interval '1 month');
  
  -- Lock inventory rows
  perform 1 from public.inventory_units iu
  where iu.tenant_id = p_tenant_id
    and iu.id in (
      select (value->>'unit_id')::uuid
      from jsonb_array_elements(p_lines)
      where jsonb_typeof(value->'unit_id') = 'string'
    )
  order by iu.id for update;
  
  perform 1 from public.stock_balances sb
  where sb.tenant_id = p_tenant_id
    and sb.product_id in (
      select (value->>'product_id')::uuid
      from jsonb_array_elements(p_lines)
    )
  order by sb.product_id for update;
  
  perform 1 from public.tenants where id = p_tenant_id for update;
  
  -- Verify inventory availability
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
  
  -- Get GL accounts
  select id into v_sales_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'sales';
  select id into v_discount_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'sales_discounts';
  select id into v_cogs_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'cogs';
  select id into v_receivable_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'installment_receivable';
  select id into v_unearned_account_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'unearned_margin';
  
  -- Create document numbers
  v_invoice_doc_no := app.next_document_number(
    p_tenant_id, 'installment_sale', extract(year from p_doc_date)::integer, v_actor
  );
  v_contract_doc_no := app.next_document_number(
    p_tenant_id, 'installment_contract', extract(year from p_doc_date)::integer, v_actor
  );
  
  -- Create sales invoice
  insert into public.sales_invoices (
    id, tenant_id, doc_no, doc_date, customer_id, kind,
    gross_total, discount_total, net_total, request_id, created_by
  ) values (
    v_invoice_id, p_tenant_id, v_invoice_doc_no, p_doc_date, p_customer_id, 'installment',
    v_gross_total, v_discount_total, v_cash_total, p_request_id, v_actor
  );
  
  -- Create invoice lines and process inventory
  v_line_no := 0;
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_line_no := v_line_no + 1;
    v_qty := (v_line->>'qty')::integer;
    v_cash_price := app.money_from_json(v_line->'cash_price', 'cash_price', false);
    v_line_discount := app.money_from_json(coalesce(v_line->'discount', '"0"'::jsonb), 'discount', true);
    v_gross := v_cash_price * v_qty;
    v_line_net := v_gross - v_line_discount;
    
    select * into v_product from public.products
      where tenant_id = p_tenant_id and id = (v_line->>'product_id')::uuid;
    
    if v_product.tracking = 'serial' then
      select * into v_unit from public.inventory_units
      where tenant_id = p_tenant_id and id = (v_line->>'unit_id')::uuid for update;
      v_cost := v_unit.unit_cost;
      v_inventory_account_id := app.get_inventory_account_id(p_tenant_id, v_unit.condition);
      update public.inventory_units set status = 'sold'
      where tenant_id = p_tenant_id and id = v_unit.id and status = 'in_stock';
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
    
    v_total_cost := v_total_cost + v_cost;
    
    insert into public.sales_invoice_lines (
      tenant_id, invoice_id, line_no, product_id, unit_id, qty,
      cash_price, gross_amount, discount, net_amount, cost_snapshot
    ) values (
      p_tenant_id, v_invoice_id, v_line_no, v_product.id,
      nullif(v_line->>'unit_id', '')::uuid, v_qty,
      v_cash_price, v_gross, v_line_discount, v_line_net, v_cost
    );
    
    -- Journal lines for sales (Cr Sales at gross, Dr Discount)
    v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_sales_account_id::text, 'debit', '0', 'credit', v_gross::text,
      'customer_id', p_customer_id::text, 'product_id', v_product.id::text,
      'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
    ));
    if v_line_discount > 0 then
      v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
        'account_id', v_discount_account_id::text, 'debit', v_line_discount::text, 'credit', '0',
        'customer_id', p_customer_id::text, 'product_id', v_product.id::text,
        'category_id', coalesce(v_product.category_id::text, ''), 'user_id', v_actor::text
      ));
    end if;
    -- COGS / Inventory
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
  
  -- Create down payment record if any
  if v_down_payment > 0 then
    insert into public.sales_payments (tenant_id, invoice_id, cash_account_id, amount)
    values (p_tenant_id, v_invoice_id, p_down_payment_cash_account_id, v_down_payment);
    
    -- Dr Cash for down payment
    v_je_lines := v_je_lines || jsonb_build_array(jsonb_build_object(
      'account_id', v_cash_gl_account_id::text, 'debit', v_down_payment::text, 'credit', '0',
      'customer_id', p_customer_id::text,
      'cash_account_id', p_down_payment_cash_account_id::text, 'user_id', v_actor::text
    ));
  end if;
  
  -- Dr Installment Receivable, Cr Unearned Margin
  v_je_lines := v_je_lines || jsonb_build_array(
    jsonb_build_object(
      'account_id', v_receivable_account_id::text, 'debit', v_receivable::text, 'credit', '0',
      'customer_id', p_customer_id::text, 'contract_id', v_contract_id::text, 'user_id', v_actor::text
    ),
    jsonb_build_object(
      'account_id', v_unearned_account_id::text, 'debit', '0', 'credit', v_margin_total::text,
      'customer_id', p_customer_id::text, 'contract_id', v_contract_id::text, 'user_id', v_actor::text
    )
  );
  
  -- Create contract
  insert into public.installment_contracts (
    id, tenant_id, doc_no, doc_date, sales_invoice_id, customer_id,
    guarantor_name, guarantor_phone, guarantor_national_id,
    cash_total, down_payment, financed_base, margin_total, receivable,
    months, factor_bp, manual_price, rounding_step, first_due_date,
    request_id, created_by
  ) values (
    v_contract_id, p_tenant_id, v_contract_doc_no, p_doc_date, v_invoice_id, p_customer_id,
    v_customer.guarantor_name, v_customer.guarantor_phone, v_customer.guarantor_national_id,
    v_cash_total, v_down_payment, v_financed_base, v_margin_total, v_receivable,
    p_months, p_factor_bp, (p_manual_deferred_price is not null), p_rounding_step, v_first_due,
    p_request_id, v_actor
  );
  
  -- Create installments
  for i in 1..p_months loop
    if i < p_months then
      v_amount := v_base_amount;
      v_principal := (v_financed_base * v_amount) / v_receivable;
      v_margin := v_amount - v_principal;
    else
      v_amount := v_last_amount;
      v_principal := v_financed_base - v_principal_sum;
      v_margin := v_margin_total - v_margin_sum;
    end if;
    
    v_principal_sum := v_principal_sum + v_principal;
    v_margin_sum := v_margin_sum + v_margin;
    v_due_date := (v_first_due + ((i - 1) || ' months')::interval)::date;
    
    insert into public.installments (
      tenant_id, contract_id, installment_no, due_date, amount, principal, margin
    ) values (
      p_tenant_id, v_contract_id, i, v_due_date, v_amount, v_principal, v_margin
    );
  end loop;
  
  -- Invariant assertions
  if v_principal_sum <> v_financed_base then
    raise exception using errcode = 'P0001', message = 'خطأ داخلي: مجموع الأصل لا يساوي المبلغ المؤجل';
  end if;
  if v_margin_sum <> v_margin_total then
    raise exception using errcode = 'P0001', message = 'خطأ داخلي: مجموع الهامش لا يساوي إجمالي الهامش';
  end if;
  
  -- Create journal entry
  perform app.create_journal_entry(
    p_tenant_id, v_contract_id, p_doc_date, 'installment_contract', v_contract_id,
    'عقد بيع تقسيط رقم ' || v_contract_doc_no, v_je_lines
  );
  
  -- Link pending attachments
  if p_upload_session_id is not null then
    update public.attachments
    set owner_id = p_customer_id, status = 'active'
    where tenant_id = p_tenant_id
      and upload_session_id = p_upload_session_id
      and owner_type = 'customer'
      and status = 'pending';
    
    update public.attachments
    set owner_id = v_contract_id, status = 'active'
    where tenant_id = p_tenant_id
      and upload_session_id = p_upload_session_id
      and owner_type in ('guarantor', 'installment_contract')
      and status = 'pending';
  end if;
  
  -- Save result
  v_result := jsonb_build_object(
    'invoice_id', v_invoice_id::text,
    'invoice_doc_no', v_invoice_doc_no::text,
    'contract_id', v_contract_id::text,
    'contract_doc_no', v_contract_doc_no::text
  );
  
  insert into public.posting_requests (
    tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at
  ) values (
    p_tenant_id, p_request_id, 'post_installment_sale', v_payload_hash,
    'completed', v_result, v_actor, now()
  );
  
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, request_id, after_data)
  values (
    p_tenant_id, v_actor, 'installment_sale.post', 'installment_contract', v_contract_id, p_request_id,
    jsonb_build_object(
      'invoice_doc_no', v_invoice_doc_no::text,
      'contract_doc_no', v_contract_doc_no::text,
      'cash_total', v_cash_total::text,
      'receivable', v_receivable::text
    )
  );
  
  return v_result;
end;
$$;

-- Grant execute permissions
revoke all on function public.preview_installment_schedule(text, text, integer, integer, text, bigint, date)
  from public, anon, authenticated;
grant execute on function public.preview_installment_schedule(text, text, integer, integer, text, bigint, date)
  to authenticated;

revoke all on function public.post_installment_sale(uuid, uuid, date, uuid, jsonb, text, uuid, integer, integer, text, bigint, date, uuid)
  from public, anon, authenticated;
grant execute on function public.post_installment_sale(uuid, uuid, date, uuid, jsonb, text, uuid, integer, integer, text, bigint, date, uuid)
  to authenticated;
