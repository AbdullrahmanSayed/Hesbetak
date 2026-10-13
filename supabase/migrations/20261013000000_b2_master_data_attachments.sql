-- B2: master data tables and unified attachment system.

-- Enums
create type public.tracking_type as enum ('serial', 'quantity');
create type public.cash_account_type as enum ('cash', 'bank', 'wallet');
create type public.attachment_owner_type as enum (
  'customer', 'guarantor', 'installment_contract', 'purchase_invoice',
  'purchase_return', 'supplier_payment', 'expense', 'trade_in'
);
create type public.attachment_kind as enum (
  'national_id_front', 'national_id_back', 'signed_contract',
  'supplier_invoice', 'supplier_credit_note', 'payment_proof',
  'receipt', 'unit_photo', 'seller_national_id_front', 'seller_national_id_back', 'other'
);
create type public.attachment_status as enum ('pending', 'active', 'superseded');

-- Categories
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name_ar text not null check (btrim(name_ar) <> ''),
  name_en text not null check (btrim(name_en) <> ''),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id)
);
create unique index categories_tenant_name_ar_key on public.categories (tenant_id, lower(name_ar));
create index categories_tenant_active_idx on public.categories (tenant_id, is_active, sort_order);

-- Brands
create table public.brands (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null check (btrim(name) <> ''),
  logo_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id)
);
create unique index brands_tenant_name_key on public.brands (tenant_id, lower(name));
create index brands_tenant_active_idx on public.brands (tenant_id, is_active);

-- Products
create table public.products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  category_id uuid,
  brand_id uuid,
  name_ar text not null check (btrim(name_ar) <> ''),
  name_en text,
  model text,
  barcode text,
  tracking public.tracking_type not null default 'serial',
  default_price bigint not null default 0 check (default_price >= 0),
  min_stock integer not null default 0 check (min_stock >= 0),
  warranty_months integer not null default 0 check (warranty_months >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  foreign key (tenant_id, category_id) references public.categories(tenant_id, id),
  foreign key (tenant_id, brand_id) references public.brands(tenant_id, id)
);
create unique index products_tenant_barcode_key on public.products (tenant_id, barcode) where barcode is not null;
create index products_tenant_category_idx on public.products (tenant_id, category_id, is_active);
create index products_tenant_brand_idx on public.products (tenant_id, brand_id, is_active);

-- Customers
create table public.customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null check (btrim(name) <> ''),
  phone1 text not null check (phone1 ~ '^01[0125][0-9]{8}$'),
  phone2 text check (phone2 is null or phone2 ~ '^01[0125][0-9]{8}$'),
  national_id text check (national_id is null or national_id ~ '^[0-9]{14}$'),
  address text,
  area text,
  workplace text,
  guarantor_name text,
  guarantor_phone text check (guarantor_phone is null or guarantor_phone ~ '^01[0125][0-9]{8}$'),
  guarantor_national_id text check (guarantor_national_id is null or guarantor_national_id ~ '^[0-9]{14}$'),
  notes text,
  assigned_collector_id uuid references auth.users(id),
  risk_flag boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id)
);
create index customers_tenant_phone1_idx on public.customers (tenant_id, phone1);
create index customers_tenant_name_idx on public.customers (tenant_id, lower(name));
create index customers_tenant_collector_idx on public.customers (tenant_id, assigned_collector_id) where assigned_collector_id is not null;

-- Suppliers
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null check (btrim(name) <> ''),
  phone text,
  address text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id)
);
create unique index suppliers_tenant_name_key on public.suppliers (tenant_id, lower(name));
create index suppliers_tenant_active_idx on public.suppliers (tenant_id, is_active);

-- Cash Accounts
create table public.cash_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null check (btrim(name) <> ''),
  type public.cash_account_type not null,
  gl_account_id uuid not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  foreign key (tenant_id, gl_account_id) references public.accounts(tenant_id, id)
);
create unique index cash_accounts_tenant_name_key on public.cash_accounts (tenant_id, lower(name));
create index cash_accounts_tenant_active_idx on public.cash_accounts (tenant_id, is_active);

-- Expense Categories
create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name_ar text not null check (btrim(name_ar) <> ''),
  name_en text not null check (btrim(name_en) <> ''),
  gl_account_id uuid not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  foreign key (tenant_id, gl_account_id) references public.accounts(tenant_id, id)
);
create unique index expense_categories_tenant_name_ar_key on public.expense_categories (tenant_id, lower(name_ar));
create index expense_categories_tenant_active_idx on public.expense_categories (tenant_id, is_active);

-- Partners
create table public.partners (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null check (btrim(name) <> ''),
  share_bp integer not null check (share_bp >= 0 and share_bp <= 10000),
  capital_account_id uuid not null,
  current_account_id uuid not null,
  drawings_account_id uuid not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  foreign key (tenant_id, capital_account_id) references public.accounts(tenant_id, id),
  foreign key (tenant_id, current_account_id) references public.accounts(tenant_id, id),
  foreign key (tenant_id, drawings_account_id) references public.accounts(tenant_id, id)
);
create unique index partners_tenant_name_key on public.partners (tenant_id, lower(name));
create index partners_tenant_active_idx on public.partners (tenant_id, is_active);

-- Plan Templates
create table public.plan_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null check (btrim(name) <> ''),
  months integer not null check (months > 0 and months <= 60),
  factor_bp integer not null check (factor_bp >= 0 and factor_bp <= 10000),
  min_down_payment_bp integer not null check (min_down_payment_bp >= 0 and min_down_payment_bp <= 10000),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id)
);
create unique index plan_templates_tenant_name_key on public.plan_templates (tenant_id, lower(name));
create index plan_templates_tenant_active_idx on public.plan_templates (tenant_id, is_active);

-- Attachments
create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  owner_type public.attachment_owner_type not null,
  owner_id uuid,
  kind public.attachment_kind not null,
  upload_session_id uuid,
  bucket text not null check (bucket in ('tenant-branding', 'customer-documents', 'business-documents')),
  object_path text not null check (btrim(object_path) <> ''),
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  size_bytes integer not null check (size_bytes > 0 and size_bytes <= 10485760),
  original_filename text,
  status public.attachment_status not null default 'pending',
  superseded_reason text,
  superseded_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  check ((status = 'pending' and owner_id is null and upload_session_id is not null)
      or (status in ('active', 'superseded') and owner_id is not null))
);
create index attachments_tenant_owner_idx on public.attachments (tenant_id, owner_type, owner_id) where owner_id is not null;
create index attachments_tenant_session_idx on public.attachments (tenant_id, upload_session_id) where status = 'pending';
create index attachments_pending_cleanup_idx on public.attachments (created_at) where status = 'pending';

-- Enable RLS
alter table public.categories enable row level security;
alter table public.brands enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.suppliers enable row level security;
alter table public.cash_accounts enable row level security;
alter table public.expense_categories enable row level security;
alter table public.partners enable row level security;
alter table public.plan_templates enable row level security;
alter table public.attachments enable row level security;

-- RLS Policies: Read for members
create policy categories_select_member on public.categories for select to authenticated using (app.is_member(tenant_id));
create policy brands_select_member on public.brands for select to authenticated using (app.is_member(tenant_id));
create policy products_select_member on public.products for select to authenticated using (app.is_member(tenant_id));
create policy customers_select_member on public.customers for select to authenticated using (app.is_member(tenant_id));
create policy suppliers_select_member on public.suppliers for select to authenticated using (app.is_member(tenant_id));
create policy cash_accounts_select_member on public.cash_accounts for select to authenticated using (app.is_member(tenant_id));
create policy expense_categories_select_member on public.expense_categories for select to authenticated using (app.is_member(tenant_id));
create policy partners_select_owner on public.partners for select to authenticated using (app.has_role(tenant_id, array['owner']::public.membership_role[]));
create policy plan_templates_select_member on public.plan_templates for select to authenticated using (app.is_member(tenant_id));

-- Attachments RLS: based on role and owner_type
create or replace function app.can_view_attachment(p_tenant_id uuid, p_owner_type public.attachment_owner_type)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case p_owner_type
    when 'customer' then app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[])
    when 'guarantor' then app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[])
    when 'installment_contract' then app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[])
    when 'purchase_invoice' then app.has_role(p_tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
    when 'purchase_return' then app.has_role(p_tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
    when 'supplier_payment' then app.has_role(p_tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
    when 'expense' then app.has_role(p_tenant_id, array['owner', 'manager', 'accountant']::public.membership_role[])
    when 'trade_in' then app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[])
    else false
  end
$$;

create or replace function app.can_upload_attachment(p_tenant_id uuid, p_owner_type public.attachment_owner_type)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case p_owner_type
    when 'customer' then app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[])
    when 'guarantor' then app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[])
    when 'installment_contract' then app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[])
    when 'purchase_invoice' then app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[])
    when 'purchase_return' then app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[])
    when 'supplier_payment' then app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[])
    when 'expense' then app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[])
    when 'trade_in' then app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[])
    else false
  end
$$;

create policy attachments_select on public.attachments for select to authenticated
  using (app.can_view_attachment(tenant_id, owner_type));

-- Grants
grant select on public.categories, public.brands, public.products, public.customers,
               public.suppliers, public.cash_accounts, public.expense_categories,
               public.partners, public.plan_templates, public.attachments to authenticated;

revoke all on function app.can_view_attachment(uuid, public.attachment_owner_type) from public, anon, authenticated;
revoke all on function app.can_upload_attachment(uuid, public.attachment_owner_type) from public, anon, authenticated;
grant execute on function app.can_view_attachment(uuid, public.attachment_owner_type) to authenticated;
grant execute on function app.can_upload_attachment(uuid, public.attachment_owner_type) to authenticated;

-- Master Data Management RPCs

create or replace function public.manage_category(
  p_tenant_id uuid,
  p_id uuid,
  p_name_ar text,
  p_name_en text,
  p_sort_order integer default 0,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_category_id uuid;
  v_before jsonb;
begin
  if not app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner or manager role required';
  end if;
  v_actor := auth.uid();

  if p_id is not null then
    select to_jsonb(c), c.id into v_before, v_category_id
    from public.categories c where c.id = p_id and c.tenant_id = p_tenant_id for update;
    if v_category_id is null then
      raise exception using errcode = '42501', message = 'category not found';
    end if;
    update public.categories set
      name_ar = btrim(p_name_ar),
      name_en = btrim(p_name_en),
      sort_order = p_sort_order,
      is_active = p_is_active
    where id = p_id;
  else
    insert into public.categories (tenant_id, name_ar, name_en, sort_order, is_active, created_by)
    values (p_tenant_id, btrim(p_name_ar), btrim(p_name_en), p_sort_order, p_is_active, v_actor)
    returning id into v_category_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'category.update' else 'category.create' end,
          'category', v_category_id, v_before,
          jsonb_build_object('name_ar', btrim(p_name_ar), 'name_en', btrim(p_name_en), 'is_active', p_is_active));
  return v_category_id;
end;
$$;

create or replace function public.manage_brand(
  p_tenant_id uuid,
  p_id uuid,
  p_name text,
  p_logo_path text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_brand_id uuid;
  v_before jsonb;
begin
  if not app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner or manager role required';
  end if;
  v_actor := auth.uid();

  if p_id is not null then
    select to_jsonb(b), b.id into v_before, v_brand_id
    from public.brands b where b.id = p_id and b.tenant_id = p_tenant_id for update;
    if v_brand_id is null then
      raise exception using errcode = '42501', message = 'brand not found';
    end if;
    update public.brands set
      name = btrim(p_name),
      logo_path = p_logo_path,
      is_active = p_is_active
    where id = p_id;
  else
    insert into public.brands (tenant_id, name, logo_path, is_active, created_by)
    values (p_tenant_id, btrim(p_name), p_logo_path, p_is_active, v_actor)
    returning id into v_brand_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'brand.update' else 'brand.create' end,
          'brand', v_brand_id, v_before,
          jsonb_build_object('name', btrim(p_name), 'is_active', p_is_active));
  return v_brand_id;
end;
$$;

create or replace function public.manage_product(
  p_tenant_id uuid,
  p_id uuid,
  p_name_ar text,
  p_name_en text default null,
  p_category_id uuid default null,
  p_brand_id uuid default null,
  p_model text default null,
  p_barcode text default null,
  p_tracking public.tracking_type default 'serial',
  p_default_price bigint default 0,
  p_min_stock integer default 0,
  p_warranty_months integer default 0,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_product_id uuid;
  v_before jsonb;
begin
  if not app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner or manager role required';
  end if;
  v_actor := auth.uid();

  if p_id is not null then
    select to_jsonb(p), p.id into v_before, v_product_id
    from public.products p where p.id = p_id and p.tenant_id = p_tenant_id for update;
    if v_product_id is null then
      raise exception using errcode = '42501', message = 'product not found';
    end if;
    update public.products set
      name_ar = btrim(p_name_ar),
      name_en = nullif(btrim(p_name_en), ''),
      category_id = p_category_id,
      brand_id = p_brand_id,
      model = nullif(btrim(p_model), ''),
      barcode = nullif(btrim(p_barcode), ''),
      tracking = p_tracking,
      default_price = p_default_price,
      min_stock = p_min_stock,
      warranty_months = p_warranty_months,
      is_active = p_is_active
    where id = p_id;
  else
    insert into public.products (tenant_id, name_ar, name_en, category_id, brand_id, model, barcode, tracking, default_price, min_stock, warranty_months, is_active, created_by)
    values (p_tenant_id, btrim(p_name_ar), nullif(btrim(p_name_en), ''), p_category_id, p_brand_id, nullif(btrim(p_model), ''), nullif(btrim(p_barcode), ''), p_tracking, p_default_price, p_min_stock, p_warranty_months, p_is_active, v_actor)
    returning id into v_product_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'product.update' else 'product.create' end,
          'product', v_product_id, v_before,
          jsonb_build_object('name_ar', btrim(p_name_ar), 'barcode', nullif(btrim(p_barcode), ''), 'is_active', p_is_active));
  return v_product_id;
end;
$$;

create or replace function public.manage_customer(
  p_tenant_id uuid,
  p_id uuid,
  p_name text,
  p_phone1 text,
  p_phone2 text default null,
  p_national_id text default null,
  p_address text default null,
  p_area text default null,
  p_workplace text default null,
  p_guarantor_name text default null,
  p_guarantor_phone text default null,
  p_guarantor_national_id text default null,
  p_notes text default null,
  p_assigned_collector_id uuid default null,
  p_risk_flag boolean default false,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_customer_id uuid;
  v_before jsonb;
begin
  if not app.has_role(p_tenant_id, array['owner', 'manager', 'cashier']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner, manager, or cashier role required';
  end if;
  v_actor := auth.uid();

  -- Validate phone format
  if p_phone1 !~ '^01[0125][0-9]{8}$' then
    raise exception using errcode = '23514', message = 'invalid phone1 format';
  end if;

  if p_id is not null then
    select to_jsonb(c), c.id into v_before, v_customer_id
    from public.customers c where c.id = p_id and c.tenant_id = p_tenant_id for update;
    if v_customer_id is null then
      raise exception using errcode = '42501', message = 'customer not found';
    end if;
    update public.customers set
      name = btrim(p_name),
      phone1 = p_phone1,
      phone2 = nullif(btrim(p_phone2), ''),
      national_id = nullif(btrim(p_national_id), ''),
      address = nullif(btrim(p_address), ''),
      area = nullif(btrim(p_area), ''),
      workplace = nullif(btrim(p_workplace), ''),
      guarantor_name = nullif(btrim(p_guarantor_name), ''),
      guarantor_phone = nullif(btrim(p_guarantor_phone), ''),
      guarantor_national_id = nullif(btrim(p_guarantor_national_id), ''),
      notes = nullif(btrim(p_notes), ''),
      assigned_collector_id = p_assigned_collector_id,
      risk_flag = p_risk_flag,
      is_active = p_is_active
    where id = p_id;
  else
    insert into public.customers (tenant_id, name, phone1, phone2, national_id, address, area, workplace, guarantor_name, guarantor_phone, guarantor_national_id, notes, assigned_collector_id, risk_flag, is_active, created_by)
    values (p_tenant_id, btrim(p_name), p_phone1, nullif(btrim(p_phone2), ''), nullif(btrim(p_national_id), ''), nullif(btrim(p_address), ''), nullif(btrim(p_area), ''), nullif(btrim(p_workplace), ''), nullif(btrim(p_guarantor_name), ''), nullif(btrim(p_guarantor_phone), ''), nullif(btrim(p_guarantor_national_id), ''), nullif(btrim(p_notes), ''), p_assigned_collector_id, p_risk_flag, p_is_active, v_actor)
    returning id into v_customer_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'customer.update' else 'customer.create' end,
          'customer', v_customer_id, v_before,
          jsonb_build_object('name', btrim(p_name), 'phone1', p_phone1, 'is_active', p_is_active));
  return v_customer_id;
end;
$$;

create or replace function public.manage_supplier(
  p_tenant_id uuid,
  p_id uuid,
  p_name text,
  p_phone text default null,
  p_address text default null,
  p_notes text default null,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_supplier_id uuid;
  v_before jsonb;
begin
  if not app.has_role(p_tenant_id, array['owner', 'manager']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner or manager role required';
  end if;
  v_actor := auth.uid();

  if p_id is not null then
    select to_jsonb(s), s.id into v_before, v_supplier_id
    from public.suppliers s where s.id = p_id and s.tenant_id = p_tenant_id for update;
    if v_supplier_id is null then
      raise exception using errcode = '42501', message = 'supplier not found';
    end if;
    update public.suppliers set
      name = btrim(p_name),
      phone = nullif(btrim(p_phone), ''),
      address = nullif(btrim(p_address), ''),
      notes = nullif(btrim(p_notes), ''),
      is_active = p_is_active
    where id = p_id;
  else
    insert into public.suppliers (tenant_id, name, phone, address, notes, is_active, created_by)
    values (p_tenant_id, btrim(p_name), nullif(btrim(p_phone), ''), nullif(btrim(p_address), ''), nullif(btrim(p_notes), ''), p_is_active, v_actor)
    returning id into v_supplier_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'supplier.update' else 'supplier.create' end,
          'supplier', v_supplier_id, v_before,
          jsonb_build_object('name', btrim(p_name), 'is_active', p_is_active));
  return v_supplier_id;
end;
$$;

create or replace function public.manage_cash_account(
  p_tenant_id uuid,
  p_id uuid,
  p_name text,
  p_type public.cash_account_type,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_cash_account_id uuid;
  v_gl_account_id uuid;
  v_before jsonb;
  v_next_code text;
  v_parent_id uuid;
begin
  v_actor := app.require_owner_writable(p_tenant_id);

  if p_id is not null then
    select to_jsonb(ca), ca.id into v_before, v_cash_account_id
    from public.cash_accounts ca where ca.id = p_id and ca.tenant_id = p_tenant_id for update;
    if v_cash_account_id is null then
      raise exception using errcode = '42501', message = 'cash account not found';
    end if;
    update public.cash_accounts set
      name = btrim(p_name),
      type = p_type,
      is_active = p_is_active
    where id = p_id;
    -- Also update the GL account name
    update public.accounts set name_ar = btrim(p_name), name_en = btrim(p_name)
    where id = (select gl_account_id from public.cash_accounts where id = p_id);
  else
    -- Get parent account (1100 Cash header)
    select id into v_parent_id from public.accounts
    where tenant_id = p_tenant_id and system_key = 'cash_main';
    if v_parent_id is null then
      -- Use the header
      select id into v_parent_id from public.accounts
      where tenant_id = p_tenant_id and code = '1100';
    end if;

    -- Generate next code under 11xx
    select '11' || lpad((coalesce(max(substring(code from 3)::integer), 9) + 1)::text, 2, '0')
    into v_next_code
    from public.accounts
    where tenant_id = p_tenant_id and code like '11%' and length(code) = 4;

    -- Create GL account
    insert into public.accounts (tenant_id, code, name_ar, name_en, type, normal_side, parent_id, is_header, created_by)
    values (p_tenant_id, v_next_code, btrim(p_name), btrim(p_name), 'asset', 'debit', v_parent_id, false, v_actor)
    returning id into v_gl_account_id;

    -- Create cash account
    insert into public.cash_accounts (tenant_id, name, type, gl_account_id, is_active, created_by)
    values (p_tenant_id, btrim(p_name), p_type, v_gl_account_id, p_is_active, v_actor)
    returning id into v_cash_account_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'cash_account.update' else 'cash_account.create' end,
          'cash_account', v_cash_account_id, v_before,
          jsonb_build_object('name', btrim(p_name), 'type', p_type::text, 'is_active', p_is_active));
  return v_cash_account_id;
end;
$$;

create or replace function public.manage_expense_category(
  p_tenant_id uuid,
  p_id uuid,
  p_name_ar text,
  p_name_en text,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_expense_cat_id uuid;
  v_gl_account_id uuid;
  v_before jsonb;
  v_next_code text;
begin
  v_actor := app.require_owner_writable(p_tenant_id);

  if p_id is not null then
    select to_jsonb(ec), ec.id into v_before, v_expense_cat_id
    from public.expense_categories ec where ec.id = p_id and ec.tenant_id = p_tenant_id for update;
    if v_expense_cat_id is null then
      raise exception using errcode = '42501', message = 'expense category not found';
    end if;
    update public.expense_categories set
      name_ar = btrim(p_name_ar),
      name_en = btrim(p_name_en),
      is_active = p_is_active
    where id = p_id;
    -- Also update the GL account names
    update public.accounts set name_ar = btrim(p_name_ar), name_en = btrim(p_name_en)
    where id = (select gl_account_id from public.expense_categories where id = p_id);
  else
    -- Generate next code under 6xxx
    select '6' || lpad((coalesce(max(substring(code from 2)::integer), 99) + 1)::text, 3, '0')
    into v_next_code
    from public.accounts
    where tenant_id = p_tenant_id and code like '6%' and length(code) = 4;

    -- Create GL account
    insert into public.accounts (tenant_id, code, name_ar, name_en, type, normal_side, is_header, created_by)
    values (p_tenant_id, v_next_code, btrim(p_name_ar), btrim(p_name_en), 'expense', 'debit', false, v_actor)
    returning id into v_gl_account_id;

    -- Create expense category
    insert into public.expense_categories (tenant_id, name_ar, name_en, gl_account_id, is_active, created_by)
    values (p_tenant_id, btrim(p_name_ar), btrim(p_name_en), v_gl_account_id, p_is_active, v_actor)
    returning id into v_expense_cat_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'expense_category.update' else 'expense_category.create' end,
          'expense_category', v_expense_cat_id, v_before,
          jsonb_build_object('name_ar', btrim(p_name_ar), 'name_en', btrim(p_name_en), 'is_active', p_is_active));
  return v_expense_cat_id;
end;
$$;

create or replace function public.manage_partner(
  p_tenant_id uuid,
  p_id uuid,
  p_name text,
  p_share_bp integer,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_partner_id uuid;
  v_capital_id uuid;
  v_current_id uuid;
  v_drawings_id uuid;
  v_before jsonb;
  v_total_share integer;
  v_next_suffix text;
begin
  v_actor := app.require_owner_writable(p_tenant_id);

  if p_id is not null then
    select to_jsonb(p), p.id into v_before, v_partner_id
    from public.partners p where p.id = p_id and p.tenant_id = p_tenant_id for update;
    if v_partner_id is null then
      raise exception using errcode = '42501', message = 'partner not found';
    end if;

    -- Validate total shares excluding this partner
    select coalesce(sum(share_bp), 0) into v_total_share
    from public.partners
    where tenant_id = p_tenant_id and is_active and id <> p_id;
    if v_total_share + p_share_bp > 10000 then
      raise exception using errcode = '23514', message = 'total partner shares cannot exceed 100%';
    end if;

    update public.partners set
      name = btrim(p_name),
      share_bp = p_share_bp,
      is_active = p_is_active
    where id = p_id;
    -- Update account names
    update public.accounts set name_ar = 'رأس مال - ' || btrim(p_name), name_en = 'Capital - ' || btrim(p_name)
    where id = (select capital_account_id from public.partners where id = p_id);
    update public.accounts set name_ar = 'جاري - ' || btrim(p_name), name_en = 'Current - ' || btrim(p_name)
    where id = (select current_account_id from public.partners where id = p_id);
    update public.accounts set name_ar = 'مسحوبات - ' || btrim(p_name), name_en = 'Drawings - ' || btrim(p_name)
    where id = (select drawings_account_id from public.partners where id = p_id);
  else
    -- Validate total shares
    select coalesce(sum(share_bp), 0) into v_total_share
    from public.partners
    where tenant_id = p_tenant_id and is_active;
    if v_total_share + p_share_bp > 10000 then
      raise exception using errcode = '23514', message = 'total partner shares cannot exceed 100%';
    end if;

    -- Generate suffix for codes
    select lpad((count(*) + 1)::text, 2, '0') into v_next_suffix
    from public.partners where tenant_id = p_tenant_id;

    -- Create 3 GL accounts
    insert into public.accounts (tenant_id, code, name_ar, name_en, type, normal_side, is_header, created_by)
    values (p_tenant_id, '31' || v_next_suffix, 'رأس مال - ' || btrim(p_name), 'Capital - ' || btrim(p_name), 'equity', 'credit', false, v_actor)
    returning id into v_capital_id;

    insert into public.accounts (tenant_id, code, name_ar, name_en, type, normal_side, is_header, created_by)
    values (p_tenant_id, '32' || v_next_suffix, 'جاري - ' || btrim(p_name), 'Current - ' || btrim(p_name), 'equity', 'credit', false, v_actor)
    returning id into v_current_id;

    insert into public.accounts (tenant_id, code, name_ar, name_en, type, normal_side, is_header, created_by)
    values (p_tenant_id, '33' || v_next_suffix, 'مسحوبات - ' || btrim(p_name), 'Drawings - ' || btrim(p_name), 'equity', 'debit', false, v_actor)
    returning id into v_drawings_id;

    -- Create partner
    insert into public.partners (tenant_id, name, share_bp, capital_account_id, current_account_id, drawings_account_id, is_active, created_by)
    values (p_tenant_id, btrim(p_name), p_share_bp, v_capital_id, v_current_id, v_drawings_id, p_is_active, v_actor)
    returning id into v_partner_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'partner.update' else 'partner.create' end,
          'partner', v_partner_id, v_before,
          jsonb_build_object('name', btrim(p_name), 'share_bp', p_share_bp, 'is_active', p_is_active));
  return v_partner_id;
end;
$$;

create or replace function public.manage_plan_template(
  p_tenant_id uuid,
  p_id uuid,
  p_name text,
  p_months integer,
  p_factor_bp integer,
  p_min_down_payment_bp integer,
  p_is_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_template_id uuid;
  v_before jsonb;
begin
  v_actor := app.require_owner_writable(p_tenant_id);

  if p_id is not null then
    select to_jsonb(pt), pt.id into v_before, v_template_id
    from public.plan_templates pt where pt.id = p_id and pt.tenant_id = p_tenant_id for update;
    if v_template_id is null then
      raise exception using errcode = '42501', message = 'plan template not found';
    end if;
    update public.plan_templates set
      name = btrim(p_name),
      months = p_months,
      factor_bp = p_factor_bp,
      min_down_payment_bp = p_min_down_payment_bp,
      is_active = p_is_active
    where id = p_id;
  else
    insert into public.plan_templates (tenant_id, name, months, factor_bp, min_down_payment_bp, is_active, created_by)
    values (p_tenant_id, btrim(p_name), p_months, p_factor_bp, p_min_down_payment_bp, p_is_active, v_actor)
    returning id into v_template_id;
  end if;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor,
          case when p_id is not null then 'plan_template.update' else 'plan_template.create' end,
          'plan_template', v_template_id, v_before,
          jsonb_build_object('name', btrim(p_name), 'months', p_months, 'factor_bp', p_factor_bp, 'is_active', p_is_active));
  return v_template_id;
end;
$$;

-- Attachment RPCs

create or replace function public.register_attachment(
  p_tenant_id uuid,
  p_owner_type public.attachment_owner_type,
  p_kind public.attachment_kind,
  p_upload_session_id uuid,
  p_bucket text,
  p_object_path text,
  p_mime_type text,
  p_size_bytes integer,
  p_original_filename text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_attachment_id uuid;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;
  if not app.can_upload_attachment(p_tenant_id, p_owner_type) then
    raise exception using errcode = '42501', message = 'upload permission denied for this attachment type';
  end if;
  if p_upload_session_id is null then
    raise exception using errcode = '23514', message = 'upload_session_id is required for pending attachments';
  end if;

  insert into public.attachments (
    tenant_id, owner_type, kind, upload_session_id, bucket, object_path, mime_type, size_bytes, original_filename, status, created_by
  ) values (
    p_tenant_id, p_owner_type, p_kind, p_upload_session_id, p_bucket, p_object_path, p_mime_type, p_size_bytes, p_original_filename, 'pending', v_actor
  ) returning id into v_attachment_id;

  return v_attachment_id;
end;
$$;

create or replace function public.attach_to_document(
  p_tenant_id uuid,
  p_attachment_id uuid,
  p_owner_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_owner_type public.attachment_owner_type;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;

  select owner_type into v_owner_type
  from public.attachments
  where id = p_attachment_id and tenant_id = p_tenant_id and status = 'pending'
  for update;

  if not found then
    raise exception using errcode = '42501', message = 'attachment not found or not pending';
  end if;

  if not app.can_upload_attachment(p_tenant_id, v_owner_type) then
    raise exception using errcode = '42501', message = 'permission denied';
  end if;

  update public.attachments
  set owner_id = p_owner_id, status = 'active'
  where id = p_attachment_id;

  return p_attachment_id;
end;
$$;

create or replace function public.supersede_attachment(
  p_tenant_id uuid,
  p_attachment_id uuid,
  p_reason text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_owner_type public.attachment_owner_type;
begin
  v_actor := app.require_owner_writable(p_tenant_id);

  select owner_type into v_owner_type
  from public.attachments
  where id = p_attachment_id and tenant_id = p_tenant_id and status = 'active'
  for update;

  if not found then
    raise exception using errcode = '42501', message = 'attachment not found or not active';
  end if;

  update public.attachments
  set status = 'superseded', superseded_reason = btrim(p_reason), superseded_by = v_actor
  where id = p_attachment_id;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, after_data)
  values (p_tenant_id, v_actor, 'attachment.supersede', 'attachment', p_attachment_id,
          jsonb_build_object('reason', btrim(p_reason)));

  return p_attachment_id;
end;
$$;

create or replace function public.get_attachment_url(
  p_tenant_id uuid,
  p_attachment_id uuid
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_attachment record;
  v_signed_url text;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;

  select * into v_attachment
  from public.attachments
  where id = p_attachment_id and tenant_id = p_tenant_id and status in ('active', 'superseded');

  if not found then
    raise exception using errcode = '42501', message = 'attachment not found';
  end if;

  if not app.can_view_attachment(p_tenant_id, v_attachment.owner_type) then
    raise exception using errcode = '42501', message = 'view permission denied';
  end if;

  -- In production, this would call storage.create_signed_url()
  -- For now, return a placeholder that the Edge Function would generate
  v_signed_url := 'signed://' || v_attachment.bucket || '/' || v_attachment.object_path || '?expires=300';

  -- Audit the view
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, after_data)
  values (p_tenant_id, v_actor, 'attachment.viewed', 'attachment', p_attachment_id,
          jsonb_build_object('bucket', v_attachment.bucket, 'path', v_attachment.object_path));

  return v_signed_url;
end;
$$;

-- Grants for RPCs
revoke all on function public.manage_category(uuid, uuid, text, text, integer, boolean) from public, anon;
revoke all on function public.manage_brand(uuid, uuid, text, text, boolean) from public, anon;
revoke all on function public.manage_product(uuid, uuid, text, text, uuid, uuid, text, text, public.tracking_type, bigint, integer, integer, boolean) from public, anon;
revoke all on function public.manage_customer(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, uuid, boolean, boolean) from public, anon;
revoke all on function public.manage_supplier(uuid, uuid, text, text, text, text, boolean) from public, anon;
revoke all on function public.manage_cash_account(uuid, uuid, text, public.cash_account_type, boolean) from public, anon;
revoke all on function public.manage_expense_category(uuid, uuid, text, text, boolean) from public, anon;
revoke all on function public.manage_partner(uuid, uuid, text, integer, boolean) from public, anon;
revoke all on function public.manage_plan_template(uuid, uuid, text, integer, integer, integer, boolean) from public, anon;
revoke all on function public.register_attachment(uuid, public.attachment_owner_type, public.attachment_kind, uuid, text, text, text, integer, text) from public, anon;
revoke all on function public.attach_to_document(uuid, uuid, uuid) from public, anon;
revoke all on function public.supersede_attachment(uuid, uuid, text) from public, anon;
revoke all on function public.get_attachment_url(uuid, uuid) from public, anon;

grant execute on function public.manage_category(uuid, uuid, text, text, integer, boolean) to authenticated;
grant execute on function public.manage_brand(uuid, uuid, text, text, boolean) to authenticated;
grant execute on function public.manage_product(uuid, uuid, text, text, uuid, uuid, text, text, public.tracking_type, bigint, integer, integer, boolean) to authenticated;
grant execute on function public.manage_customer(uuid, uuid, text, text, text, text, text, text, text, text, text, text, text, uuid, boolean, boolean) to authenticated;
grant execute on function public.manage_supplier(uuid, uuid, text, text, text, text, boolean) to authenticated;
grant execute on function public.manage_cash_account(uuid, uuid, text, public.cash_account_type, boolean) to authenticated;
grant execute on function public.manage_expense_category(uuid, uuid, text, text, boolean) to authenticated;
grant execute on function public.manage_partner(uuid, uuid, text, integer, boolean) to authenticated;
grant execute on function public.manage_plan_template(uuid, uuid, text, integer, integer, integer, boolean) to authenticated;
grant execute on function public.register_attachment(uuid, public.attachment_owner_type, public.attachment_kind, uuid, text, text, text, integer, text) to authenticated;
grant execute on function public.attach_to_document(uuid, uuid, uuid) to authenticated;
grant execute on function public.supersede_attachment(uuid, uuid, text) to authenticated;
grant execute on function public.get_attachment_url(uuid, uuid) to authenticated;

-- Seed function for default categories
create or replace function app.seed_categories(p_tenant_id uuid, p_actor_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.categories (tenant_id, name_ar, name_en, sort_order, created_by)
  values
    (p_tenant_id, 'ثلاجات', 'Refrigerators', 1, p_actor_id),
    (p_tenant_id, 'غسالات', 'Washing Machines', 2, p_actor_id),
    (p_tenant_id, 'شاشات', 'TVs', 3, p_actor_id),
    (p_tenant_id, 'تكييفات', 'Air Conditioners', 4, p_actor_id),
    (p_tenant_id, 'سخانات', 'Water Heaters', 5, p_actor_id),
    (p_tenant_id, 'أجهزة صغيرة', 'Small Appliances', 6, p_actor_id)
  on conflict do nothing;
$$;

-- Seed function for default brands
create or replace function app.seed_brands(p_tenant_id uuid, p_actor_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.brands (tenant_id, name, created_by)
  values
    (p_tenant_id, 'Sharp', p_actor_id),
    (p_tenant_id, 'Toshiba', p_actor_id),
    (p_tenant_id, 'Samsung', p_actor_id),
    (p_tenant_id, 'LG', p_actor_id),
    (p_tenant_id, 'Fresh', p_actor_id),
    (p_tenant_id, 'Tornado', p_actor_id),
    (p_tenant_id, 'Kiriazi', p_actor_id),
    (p_tenant_id, 'Zanussi', p_actor_id),
    (p_tenant_id, 'Unionaire', p_actor_id),
    (p_tenant_id, 'White Point', p_actor_id),
    (p_tenant_id, 'Hisense', p_actor_id),
    (p_tenant_id, 'TCL', p_actor_id)
  on conflict do nothing;
$$;

revoke all on function app.seed_categories(uuid, uuid) from public, anon, authenticated;
revoke all on function app.seed_brands(uuid, uuid) from public, anon, authenticated;
