-- B1: tenant isolation and append-only ledger foundation.

create schema if not exists app;
revoke all on schema app from public, anon, authenticated;

create type public.membership_role as enum ('owner', 'manager', 'cashier', 'collector', 'accountant');
create type public.tenant_status as enum ('trial', 'active', 'suspended');
create type public.account_type as enum ('asset', 'liability', 'equity', 'revenue', 'expense');
create type public.normal_side as enum ('debit', 'credit');
create type public.secret_kind as enum ('whatsapp', 'n8n', 'llm');
create type public.posting_request_status as enum ('processing', 'completed');

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug = lower(slug) and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  name text not null check (btrim(name) <> ''),
  legal_name text,
  phones text[] not null default '{}',
  address text,
  logo_path text,
  tax_number text,
  settings jsonb not null default '{}'::jsonb check (jsonb_typeof(settings) = 'object'),
  plan text not null default 'trial' check (btrim(plan) <> ''),
  status public.tenant_status not null default 'trial',
  lock_date date,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id)
);

create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  user_id uuid not null references auth.users(id),
  role public.membership_role not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, user_id),
  unique (tenant_id, id)
);
create index memberships_tenant_role_idx on public.memberships (tenant_id, role, is_active);
create index memberships_tenant_user_idx on public.memberships (tenant_id, user_id, is_active);

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  code text not null check (btrim(code) <> ''),
  name_ar text not null check (btrim(name_ar) <> ''),
  name_en text not null check (btrim(name_en) <> ''),
  type public.account_type not null,
  normal_side public.normal_side not null,
  parent_id uuid,
  system_key text,
  partner_id uuid,
  cash_account_id uuid,
  is_header boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, id),
  unique (tenant_id, code),
  foreign key (tenant_id, parent_id) references public.accounts(tenant_id, id)
);
create unique index accounts_tenant_system_key_key on public.accounts (tenant_id, system_key) where system_key is not null;
create index accounts_tenant_parent_idx on public.accounts (tenant_id, parent_id);

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  entry_no bigint not null check (entry_no > 0),
  entry_date date not null,
  source_type text not null check (btrim(source_type) <> ''),
  source_id uuid not null,
  description text not null check (btrim(description) <> ''),
  reverses_entry_id uuid,
  reversed_by_entry_id uuid,
  request_id uuid not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (tenant_id, id),
  unique (tenant_id, request_id),
  foreign key (tenant_id, reverses_entry_id) references public.journal_entries(tenant_id, id),
  foreign key (tenant_id, reversed_by_entry_id) references public.journal_entries(tenant_id, id),
  check (reverses_entry_id is null or reversed_by_entry_id is null),
  check (reverses_entry_id is null or reverses_entry_id <> id),
  check (reversed_by_entry_id is null or reversed_by_entry_id <> id)
);
create unique index journal_entries_tenant_year_number_key
  on public.journal_entries (tenant_id, extract(year from entry_date), entry_no);
create unique index journal_entries_reverses_key
  on public.journal_entries (tenant_id, reverses_entry_id) where reverses_entry_id is not null;
create unique index journal_entries_reversed_by_key
  on public.journal_entries (tenant_id, reversed_by_entry_id) where reversed_by_entry_id is not null;
create index journal_entries_tenant_date_idx on public.journal_entries (tenant_id, entry_date, entry_no);

create table public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  entry_id uuid not null,
  account_id uuid not null,
  debit bigint not null default 0 check (debit >= 0),
  credit bigint not null default 0 check (credit >= 0),
  customer_id uuid,
  supplier_id uuid,
  partner_id uuid,
  contract_id uuid,
  product_id uuid,
  category_id uuid,
  cash_account_id uuid,
  user_id uuid,
  memo text,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  foreign key (tenant_id, entry_id) references public.journal_entries(tenant_id, id),
  foreign key (tenant_id, account_id) references public.accounts(tenant_id, id),
  check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);
create index journal_lines_tenant_entry_idx on public.journal_lines (tenant_id, entry_id);
create index journal_lines_tenant_account_idx on public.journal_lines (tenant_id, account_id, entry_id);
create index journal_lines_tenant_customer_idx on public.journal_lines (tenant_id, customer_id) where customer_id is not null;
create index journal_lines_tenant_supplier_idx on public.journal_lines (tenant_id, supplier_id) where supplier_id is not null;
create index journal_lines_tenant_partner_idx on public.journal_lines (tenant_id, partner_id) where partner_id is not null;
create index journal_lines_tenant_contract_idx on public.journal_lines (tenant_id, contract_id) where contract_id is not null;
create index journal_lines_tenant_product_idx on public.journal_lines (tenant_id, product_id) where product_id is not null;
create index journal_lines_tenant_category_idx on public.journal_lines (tenant_id, category_id) where category_id is not null;
create index journal_lines_tenant_cash_account_idx on public.journal_lines (tenant_id, cash_account_id) where cash_account_id is not null;
create index journal_lines_tenant_user_idx on public.journal_lines (tenant_id, user_id) where user_id is not null;

create table public.document_counters (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  doc_type text not null check (btrim(doc_type) <> ''),
  year integer not null check (year between 1 and 9999),
  last_no bigint not null default 0 check (last_no >= 0),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, doc_type, year)
);
create index document_counters_tenant_idx on public.document_counters (tenant_id, doc_type, year);

create table public.posting_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  request_id uuid not null,
  rpc_name text not null check (btrim(rpc_name) <> ''),
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  status public.posting_request_status not null default 'processing',
  result jsonb,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  completed_at timestamptz,
  unique (tenant_id, request_id),
  check (jsonb_typeof(result) is null or jsonb_typeof(result) = 'object'),
  check ((status = 'processing' and result is null and completed_at is null) or (status = 'completed' and result is not null and completed_at is not null))
);
create index posting_requests_tenant_rpc_idx on public.posting_requests (tenant_id, rpc_name, created_at);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  actor_id uuid not null references auth.users(id),
  action text not null check (btrim(action) <> ''),
  target_type text not null check (btrim(target_type) <> ''),
  target_id uuid not null,
  before_data jsonb,
  after_data jsonb,
  request_id uuid,
  created_at timestamptz not null default now(),
  check (jsonb_typeof(before_data) is null or jsonb_typeof(before_data) = 'object'),
  check (jsonb_typeof(after_data) is null or jsonb_typeof(after_data) = 'object')
);
create index audit_log_tenant_created_idx on public.audit_log (tenant_id, created_at desc);
create index audit_log_tenant_target_idx on public.audit_log (tenant_id, target_type, target_id);

create table public.tenant_secret_refs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  kind public.secret_kind not null,
  vault_secret_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id),
  unique (tenant_id, kind)
);
create index tenant_secret_refs_tenant_idx on public.tenant_secret_refs (tenant_id, kind);

create or replace function app.current_user_id()
returns uuid
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select auth.uid()
$$;

create or replace function app.is_member(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.is_active
  )
$$;

create or replace function app.has_role(p_tenant_id uuid, p_roles public.membership_role[])
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and m.user_id = auth.uid()
      and m.is_active
      and m.role = any(p_roles)
  )
$$;

create or replace function app.reject_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  raise exception using errcode = '55000', message = format('%s is append-only', tg_table_name);
end;
$$;

create or replace function app.guard_journal_entry_mutation()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '55000', message = 'journal_entries is append-only';
  end if;

  if current_setting('app.allow_reversal_link', true) = 'on'
     and new.id = old.id
     and new.tenant_id = old.tenant_id
     and new.entry_no = old.entry_no
     and new.entry_date = old.entry_date
     and new.source_type = old.source_type
     and new.source_id = old.source_id
     and new.description = old.description
     and new.reverses_entry_id is not distinct from old.reverses_entry_id
     and old.reversed_by_entry_id is null
     and new.reversed_by_entry_id is not null
     and new.request_id = old.request_id
     and new.created_by = old.created_by
     and new.created_at = old.created_at then
    return new;
  end if;

  raise exception using errcode = '55000', message = 'journal_entries is append-only';
end;
$$;

create or replace function app.validate_journal_line_account()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.accounts a
    where a.id = new.account_id
      and a.tenant_id = new.tenant_id
      and a.is_active
      and not a.is_header
  ) then
    raise exception using errcode = '23514', message = 'journal line account must be active, posting-enabled, and in the same tenant';
  end if;
  return new;
end;
$$;

create or replace function app.assert_journal_entry_balanced()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_entry_id uuid := coalesce(new.entry_id, old.entry_id);
  v_line_count bigint;
  v_debit numeric;
  v_credit numeric;
begin
  select count(*), coalesce(sum(debit), 0), coalesce(sum(credit), 0)
  into v_line_count, v_debit, v_credit
  from public.journal_lines
  where entry_id = v_entry_id;

  if v_line_count < 2 then
    raise exception using errcode = '23514', message = 'journal entry must contain at least two lines';
  end if;
  if v_debit <> v_credit then
    raise exception using errcode = '23514', message = 'journal entry must balance';
  end if;
  return null;
end;
$$;

create trigger guard_journal_entry_mutation
before update or delete on public.journal_entries
for each row execute function app.guard_journal_entry_mutation();

create trigger guard_journal_line_mutation
before update or delete on public.journal_lines
for each row execute function app.reject_mutation();

create trigger validate_journal_line_account
before insert on public.journal_lines
for each row execute function app.validate_journal_line_account();

create constraint trigger check_journal_entry_balanced
after insert on public.journal_lines
deferrable initially deferred
for each row execute function app.assert_journal_entry_balanced();

create trigger guard_audit_log_mutation
before update or delete on public.audit_log
for each row execute function app.reject_mutation();

alter table public.tenants enable row level security;
alter table public.memberships enable row level security;
alter table public.accounts enable row level security;
alter table public.journal_entries enable row level security;
alter table public.journal_lines enable row level security;
alter table public.document_counters enable row level security;
alter table public.posting_requests enable row level security;
alter table public.audit_log enable row level security;
alter table public.tenant_secret_refs enable row level security;

create policy tenants_select_member on public.tenants for select to authenticated using (app.is_member(id));
create policy memberships_select_member on public.memberships for select to authenticated using (app.is_member(tenant_id));
create policy accounts_select_member on public.accounts for select to authenticated using (app.is_member(tenant_id));
create policy journal_entries_select_member on public.journal_entries for select to authenticated using (app.is_member(tenant_id));
create policy journal_lines_select_member on public.journal_lines for select to authenticated using (app.is_member(tenant_id));
create policy audit_log_select_privileged on public.audit_log for select to authenticated using (app.has_role(tenant_id, array['owner', 'accountant']::public.membership_role[]));
create policy tenant_secret_refs_select_owner on public.tenant_secret_refs for select to authenticated using (app.has_role(tenant_id, array['owner']::public.membership_role[]));

revoke all on all tables in schema public from anon, authenticated;
grant select on public.tenants, public.memberships, public.accounts, public.journal_entries, public.journal_lines, public.audit_log, public.tenant_secret_refs to authenticated;

revoke all on all functions in schema app from public, anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
grant usage on schema app to authenticated;
grant execute on function app.is_member(uuid) to authenticated;
grant execute on function app.has_role(uuid, public.membership_role[]) to authenticated;

create or replace function app.seed_chart(p_tenant_id uuid, p_actor_id uuid)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  with seed(code, name_ar, name_en, account_kind, side, parent_code, system_key, is_header) as (
    values
      ('1100','النقدية وما في حكمها','Cash & equivalents','asset','debit',null,null,true),
      ('1110','الخزنة الرئيسية','Main cash box','asset','debit','1100','cash_main',false),
      ('1210','أقساط مستحقة على العملاء','Installment receivable','asset','debit',null,'installment_receivable',false),
      ('1215','فرق آجل غير محقق','Unearned deferred margin','asset','credit',null,'unearned_margin',false),
      ('1300','المخزون','Inventory','asset','debit',null,null,true),
      ('1310','مخزون بضاعة جديدة','Inventory — new','asset','debit','1300','inventory_new',false),
      ('1320','مخزون بضاعة مستعملة','Inventory — used/trade-in','asset','debit','1300','inventory_used',false),
      ('1400','دفعات مقدمة للموردين','Supplier advances','asset','debit',null,'supplier_advances',false),
      ('1500','أصول ثابتة','Fixed assets','asset','debit',null,'fixed_assets',false),
      ('2100','الموردون','Accounts payable — suppliers','liability','credit',null,'accounts_payable',false),
      ('2200','مستحق لعملاء (استبدال)','Payable to customers','liability','credit',null,'payable_customers',false),
      ('2300','أرصدة دائنة للعملاء','Customer credit balances','liability','credit',null,'customer_credit',false),
      ('3100','رأس مال الشركاء','Partners capital','equity','credit',null,'partner_capital',false),
      ('3200','جاري الشركاء','Partners current','equity','credit',null,'partner_current',false),
      ('3300','مسحوبات الشركاء','Partners drawings','equity','debit',null,'partner_drawings',false),
      ('3900','أرباح مرحلة','Retained earnings','equity','credit',null,'retained_earnings',false),
      ('3999','أرصدة افتتاحية','Opening balance equity','equity','credit',null,'opening_equity',false),
      ('4100','المبيعات','Sales revenue','revenue','credit',null,'sales',false),
      ('4150','مردودات المبيعات','Sales returns','revenue','debit',null,'sales_returns',false),
      ('4160','خصم مسموح به','Sales discounts','revenue','debit',null,'sales_discounts',false),
      ('4200','أرباح الآجل المحققة','Earned deferred margin','revenue','credit',null,'earned_margin',false),
      ('4300','غرامات تأخير','Late fees','revenue','credit',null,'late_fees',false),
      ('4900','إيرادات أخرى','Other income','revenue','credit',null,'other_income',false),
      ('5100','تكلفة البضاعة المباعة','Cost of goods sold','expense','debit',null,'cogs',false),
      ('5200','فروقات مخزون','Inventory adjustments','expense','debit',null,'inventory_adjustments',false),
      ('6100','إيجار','Rent','expense','debit',null,null,false),
      ('6200','مرتبات','Salaries','expense','debit',null,null,false),
      ('6300','كهرباء ومياه','Utilities','expense','debit',null,null,false),
      ('6400','نقل وتوصيل','Transport & delivery','expense','debit',null,null,false),
      ('6500','دعاية وإعلان','Marketing','expense','debit',null,null,false),
      ('6600','ديون معدومة','Bad debt expense','expense','debit',null,'bad_debt',false),
      ('6900','مصروفات متنوعة','Miscellaneous','expense','debit',null,'misc_expense',false),
      ('6950','خسائر فسخ عقود','Contract cancellation losses','expense','debit',null,'cancellation_loss',false)
  ), inserted_roots as (
    insert into public.accounts (tenant_id, code, name_ar, name_en, type, normal_side, system_key, is_header, created_by)
    select p_tenant_id, code, name_ar, name_en, account_kind::public.account_type, side::public.normal_side, system_key, is_header, p_actor_id
    from seed where parent_code is null
    returning id, code
  )
  insert into public.accounts (tenant_id, code, name_ar, name_en, type, normal_side, parent_id, system_key, is_header, created_by)
  select p_tenant_id, s.code, s.name_ar, s.name_en, s.account_kind::public.account_type, s.side::public.normal_side,
         r.id, s.system_key, s.is_header, p_actor_id
  from seed s
  join inserted_roots r on r.code = s.parent_code;
$$;

create or replace function app.bootstrap_tenant(p_slug text, p_name text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_tenant_id uuid;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;
  insert into public.tenants (slug, name, created_by)
  values (lower(btrim(p_slug)), btrim(p_name), v_actor)
  returning id into v_tenant_id;

  insert into public.memberships (tenant_id, user_id, role, is_active, created_by)
  values (v_tenant_id, v_actor, 'owner', true, v_actor);

  perform app.seed_chart(v_tenant_id, v_actor);

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, after_data)
  values (v_tenant_id, v_actor, 'tenant.bootstrap', 'tenant', v_tenant_id, jsonb_build_object('slug', lower(btrim(p_slug)), 'name', btrim(p_name)));
  return v_tenant_id;
end;
$$;

create or replace function public.bootstrap_tenant(p_slug text, p_name text)
returns uuid
language sql
security definer
set search_path = public, pg_temp
as $$ select app.bootstrap_tenant(p_slug, p_name) $$;

create or replace function app.require_owner_writable(p_tenant_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_status public.tenant_status;
begin
  if v_actor is null or not app.has_role(p_tenant_id, array['owner']::public.membership_role[]) then
    raise exception using errcode = '42501', message = 'owner role required';
  end if;
  select status into v_status from public.tenants where id = p_tenant_id for update;
  if not found then
    raise exception using errcode = '42501', message = 'tenant not accessible';
  end if;
  if v_status = 'suspended' then
    raise exception using errcode = '55000', message = 'tenant is suspended';
  end if;
  return v_actor;
end;
$$;

create or replace function public.manage_membership(
  p_tenant_id uuid,
  p_user_id uuid,
  p_role public.membership_role,
  p_is_active boolean
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_membership_id uuid;
  v_before jsonb;
begin
  v_actor := app.require_owner_writable(p_tenant_id);
  select to_jsonb(m), m.id into v_before, v_membership_id
  from public.memberships m where m.tenant_id = p_tenant_id and m.user_id = p_user_id for update;

  if v_membership_id is not null
     and coalesce(v_before->>'role', '') = 'owner'
     and (not p_is_active or p_role <> 'owner')
     and not exists (
       select 1 from public.memberships m
       where m.tenant_id = p_tenant_id and m.role = 'owner' and m.is_active and m.user_id <> p_user_id
     ) then
    raise exception using errcode = '23514', message = 'tenant must retain an active owner';
  end if;

  insert into public.memberships (tenant_id, user_id, role, is_active, created_by)
  values (p_tenant_id, p_user_id, p_role, p_is_active, v_actor)
  on conflict (tenant_id, user_id) do update set role = excluded.role, is_active = excluded.is_active
  returning id into v_membership_id;

  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  select p_tenant_id, v_actor, 'membership.upsert', 'membership', v_membership_id, v_before,
         jsonb_build_object('user_id', p_user_id, 'role', p_role, 'is_active', p_is_active);
  return v_membership_id;
end;
$$;

create or replace function public.set_lock_date(p_tenant_id uuid, p_lock_date date)
returns date
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_before date;
begin
  v_actor := app.require_owner_writable(p_tenant_id);
  select lock_date into v_before from public.tenants where id = p_tenant_id;
  update public.tenants set lock_date = p_lock_date where id = p_tenant_id;
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor, 'tenant.lock_date', 'tenant', p_tenant_id,
          jsonb_build_object('lock_date', v_before), jsonb_build_object('lock_date', p_lock_date));
  return p_lock_date;
end;
$$;

revoke all on function app.seed_chart(uuid, uuid) from public, anon, authenticated;
revoke all on function app.bootstrap_tenant(text, text) from public, anon, authenticated;
revoke all on function app.require_owner_writable(uuid) from public, anon, authenticated;
revoke all on function public.bootstrap_tenant(text, text) from public, anon;
revoke all on function public.manage_membership(uuid, uuid, public.membership_role, boolean) from public, anon;
revoke all on function public.set_lock_date(uuid, date) from public, anon;
grant execute on function public.bootstrap_tenant(text, text) to authenticated;
grant execute on function public.manage_membership(uuid, uuid, public.membership_role, boolean) to authenticated;
grant execute on function public.set_lock_date(uuid, date) to authenticated;
