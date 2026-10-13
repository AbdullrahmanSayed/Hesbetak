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
create policy document_counters_select_member on public.document_counters for select to authenticated using (app.is_member(tenant_id));
create policy audit_log_select_privileged on public.audit_log for select to authenticated using (app.has_role(tenant_id, array['owner', 'accountant']::public.membership_role[]));
create policy tenant_secret_refs_select_owner on public.tenant_secret_refs for select to authenticated using (app.has_role(tenant_id, array['owner']::public.membership_role[]));

revoke all on all tables in schema public from anon, authenticated;
grant select on public.tenants, public.memberships, public.accounts, public.journal_entries, public.journal_lines, public.document_counters, public.audit_log, public.tenant_secret_refs to authenticated;

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

create or replace function app.next_document_number(
  p_tenant_id uuid,
  p_doc_type text,
  p_year integer,
  p_actor_id uuid
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_next bigint;
begin
  insert into public.document_counters (tenant_id, doc_type, year, last_no, created_by)
  values (p_tenant_id, p_doc_type, p_year, 0, p_actor_id)
  on conflict (tenant_id, doc_type, year) do nothing;

  select last_no + 1 into v_next
  from public.document_counters
  where tenant_id = p_tenant_id and doc_type = p_doc_type and year = p_year
  for update;

  update public.document_counters
  set last_no = v_next
  where tenant_id = p_tenant_id and doc_type = p_doc_type and year = p_year;
  return v_next;
end;
$$;

create or replace function app.create_journal_entry(
  p_tenant_id uuid,
  p_request_id uuid,
  p_entry_date date,
  p_source_type text,
  p_source_id uuid,
  p_description text,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_status public.tenant_status;
  v_lock_date date;
  v_entry_id uuid;
  v_entry_no bigint;
  v_line jsonb;
  v_account_id uuid;
  v_debit bigint;
  v_credit bigint;
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  v_line_count integer;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;
  if p_entry_date is null or p_source_id is null or p_request_id is null
     or btrim(coalesce(p_source_type, '')) = '' or btrim(coalesce(p_description, '')) = '' then
    raise exception using errcode = '23514', message = 'journal header is incomplete';
  end if;

  -- Compute canonical payload hash for idempotency
  v_payload_hash := encode(sha256(convert_to(
    p_entry_date::text || '|' || p_source_type || '|' || p_source_id::text || '|' || p_description || '|' || p_lines::text,
    'UTF8'
  )), 'hex');

  -- Check for existing completed request
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

  select status, lock_date into v_status, v_lock_date
  from public.tenants where id = p_tenant_id for update;
  if not found then
    raise exception using errcode = '23514', message = 'tenant does not exist';
  end if;
  if v_status = 'suspended' then
    raise exception using errcode = '55000', message = 'tenant is suspended';
  end if;
  if v_lock_date is not null and p_entry_date <= v_lock_date then
    raise exception using errcode = '55000', message = 'journal date is locked';
  end if;

  if jsonb_typeof(p_lines) <> 'array' then
    raise exception using errcode = '23514', message = 'journal lines must be an array';
  end if;
  v_line_count := jsonb_array_length(p_lines);
  if v_line_count < 2 then
    raise exception using errcode = '23514', message = 'journal entry must contain at least two lines';
  end if;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    if jsonb_typeof(v_line) <> 'object'
       or jsonb_typeof(v_line->'account_id') <> 'string'
       or jsonb_typeof(v_line->'debit') <> 'string'
       or jsonb_typeof(v_line->'credit') <> 'string' then
      raise exception using errcode = '23514', message = 'journal line identifiers and money must be strings';
    end if;
    v_account_id := (v_line->>'account_id')::uuid;
    v_debit := (v_line->>'debit')::bigint;
    v_credit := (v_line->>'credit')::bigint;
    if v_debit < 0 or v_credit < 0
       or not ((v_debit > 0 and v_credit = 0) or (v_credit > 0 and v_debit = 0)) then
      raise exception using errcode = '23514', message = 'each journal line must have exactly one positive side';
    end if;
    if not exists (
      select 1 from public.accounts a
      where a.id = v_account_id and a.tenant_id = p_tenant_id and a.is_active and not a.is_header
    ) then
      raise exception using errcode = '23514', message = 'journal account is invalid for this tenant';
    end if;
    v_total_debit := v_total_debit + v_debit;
    v_total_credit := v_total_credit + v_credit;
  end loop;

  if v_total_debit <> v_total_credit then
    raise exception using errcode = '23514', message = 'journal entry must balance';
  end if;

  v_entry_no := app.next_document_number(p_tenant_id, 'journal_entry', extract(year from p_entry_date)::integer, v_actor);
  insert into public.journal_entries (
    tenant_id, entry_no, entry_date, source_type, source_id, description, request_id, created_by
  ) values (
    p_tenant_id, v_entry_no, p_entry_date, p_source_type, p_source_id, p_description, p_request_id, v_actor
  ) returning id into v_entry_id;

  set constraints check_journal_entry_balanced deferred;
  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    insert into public.journal_lines (
      tenant_id, entry_id, account_id, debit, credit,
      customer_id, supplier_id, partner_id, contract_id, product_id, category_id, cash_account_id, user_id,
      memo, created_by
    ) values (
      p_tenant_id,
      v_entry_id,
      (v_line->>'account_id')::uuid,
      (v_line->>'debit')::bigint,
      (v_line->>'credit')::bigint,
      nullif(v_line->>'customer_id', '')::uuid,
      nullif(v_line->>'supplier_id', '')::uuid,
      nullif(v_line->>'partner_id', '')::uuid,
      nullif(v_line->>'contract_id', '')::uuid,
      nullif(v_line->>'product_id', '')::uuid,
      nullif(v_line->>'category_id', '')::uuid,
      nullif(v_line->>'cash_account_id', '')::uuid,
      nullif(v_line->>'user_id', '')::uuid,
      nullif(v_line->>'memo', ''),
      v_actor
    );
  end loop;
  set constraints check_journal_entry_balanced immediate;

  -- Build result and store for idempotency
  v_existing_result := jsonb_build_object(
    'entry_id', v_entry_id::text,
    'entry_no', v_entry_no::text,
    'entry_date', p_entry_date::text,
    'total_debit', v_total_debit::text,
    'total_credit', v_total_credit::text
  );

  insert into public.posting_requests (
    tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at
  ) values (
    p_tenant_id, p_request_id, 'create_journal_entry', v_payload_hash, 'completed', v_existing_result, v_actor, now()
  );

  return v_existing_result;
end;
$$;

create or replace function app.reverse_journal_entry(
  p_tenant_id uuid,
  p_request_id uuid,
  p_original_entry_id uuid,
  p_reversal_date date,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_status public.tenant_status;
  v_lock_date date;
  v_original_entry record;
  v_reversal_id uuid;
  v_reversal_no bigint;
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  v_payload_hash text;
  v_existing_result jsonb;
  v_existing_hash text;
  v_line record;
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'authentication required';
  end if;
  if p_request_id is null or p_original_entry_id is null or p_reversal_date is null
     or btrim(coalesce(p_reason, '')) = '' then
    raise exception using errcode = '23514', message = 'reversal request is incomplete';
  end if;

  -- Compute payload hash for idempotency
  v_payload_hash := encode(sha256(convert_to(
    p_original_entry_id::text || '|' || p_reversal_date::text || '|' || p_reason,
    'UTF8'
  )), 'hex');

  -- Check for existing completed request
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

  -- Lock tenant and check constraints
  select status, lock_date into v_status, v_lock_date
  from public.tenants where id = p_tenant_id for update;
  if not found then
    raise exception using errcode = '23514', message = 'tenant does not exist';
  end if;
  if v_status = 'suspended' then
    raise exception using errcode = '55000', message = 'tenant is suspended';
  end if;
  if v_lock_date is not null and p_reversal_date <= v_lock_date then
    raise exception using errcode = '55000', message = 'reversal date is locked';
  end if;

  -- Lock and validate original entry
  select id, tenant_id, entry_no, entry_date, source_type, source_id, description, reverses_entry_id, reversed_by_entry_id
  into v_original_entry
  from public.journal_entries
  where id = p_original_entry_id and tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception using errcode = '23514', message = 'original entry not found in tenant';
  end if;
  if v_original_entry.reversed_by_entry_id is not null then
    raise exception using errcode = '23514', message = 'entry is already reversed';
  end if;
  if v_original_entry.reverses_entry_id is not null then
    raise exception using errcode = '23514', message = 'cannot reverse a reversal';
  end if;

  -- Create reversal entry
  v_reversal_no := app.next_document_number(p_tenant_id, 'journal_entry', extract(year from p_reversal_date)::integer, v_actor);
  insert into public.journal_entries (
    tenant_id, entry_no, entry_date, source_type, source_id, description, reverses_entry_id, request_id, created_by
  ) values (
    p_tenant_id, v_reversal_no, p_reversal_date,
    'reversal', v_original_entry.source_id,
    'Reversal: ' || p_reason,
    p_original_entry_id, p_request_id, v_actor
  ) returning id into v_reversal_id;

  -- Link original to reversal
  perform set_config('app.allow_reversal_link', 'on', true);
  update public.journal_entries
  set reversed_by_entry_id = v_reversal_id
  where id = p_original_entry_id;
  perform set_config('app.allow_reversal_link', 'off', true);

  -- Mirror lines with swapped debit/credit
  set constraints check_journal_entry_balanced deferred;
  for v_line in
    select account_id, debit, credit, customer_id, supplier_id, partner_id, contract_id, product_id, category_id, cash_account_id, user_id, memo
    from public.journal_lines
    where entry_id = p_original_entry_id
  loop
    insert into public.journal_lines (
      tenant_id, entry_id, account_id, debit, credit,
      customer_id, supplier_id, partner_id, contract_id, product_id, category_id, cash_account_id, user_id,
      memo, created_by
    ) values (
      p_tenant_id, v_reversal_id, v_line.account_id,
      v_line.credit,  -- swap: original credit becomes reversal debit
      v_line.debit,   -- swap: original debit becomes reversal credit
      v_line.customer_id, v_line.supplier_id, v_line.partner_id, v_line.contract_id,
      v_line.product_id, v_line.category_id, v_line.cash_account_id, v_line.user_id,
      v_line.memo, v_actor
    );
    v_total_debit := v_total_debit + v_line.credit;
    v_total_credit := v_total_credit + v_line.debit;
  end loop;
  set constraints check_journal_entry_balanced immediate;

  -- Audit the reversal
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, request_id, before_data, after_data)
  values (p_tenant_id, v_actor, 'journal.reversal', 'journal_entry', v_reversal_id, p_request_id,
          jsonb_build_object('original_entry_id', p_original_entry_id::text),
          jsonb_build_object('reason', p_reason));

  -- Build and store result
  v_existing_result := jsonb_build_object(
    'entry_id', v_reversal_id::text,
    'entry_no', v_reversal_no::text,
    'entry_date', p_reversal_date::text,
    'original_entry_id', p_original_entry_id::text,
    'total_debit', v_total_debit::text,
    'total_credit', v_total_credit::text
  );

  insert into public.posting_requests (
    tenant_id, request_id, rpc_name, payload_hash, status, result, created_by, completed_at
  ) values (
    p_tenant_id, p_request_id, 'reverse_journal_entry', v_payload_hash, 'completed', v_existing_result, v_actor, now()
  );

  return v_existing_result;
end;
$$;

create or replace function public.manage_tenant_secret_ref(
  p_tenant_id uuid,
  p_kind public.secret_kind,
  p_vault_secret_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor uuid;
  v_ref_id uuid;
  v_before jsonb;
begin
  v_actor := app.require_owner_writable(p_tenant_id);

  -- Get existing reference if any
  select to_jsonb(r), r.id into v_before, v_ref_id
  from public.tenant_secret_refs r
  where r.tenant_id = p_tenant_id and r.kind = p_kind
  for update;

  if v_ref_id is not null then
    -- Update existing
    update public.tenant_secret_refs
    set vault_secret_id = p_vault_secret_id
    where id = v_ref_id;
  else
    -- Insert new
    insert into public.tenant_secret_refs (tenant_id, kind, vault_secret_id, created_by)
    values (p_tenant_id, p_kind, p_vault_secret_id, v_actor)
    returning id into v_ref_id;
  end if;

  -- Audit without exposing actual secret ID
  insert into public.audit_log (tenant_id, actor_id, action, target_type, target_id, before_data, after_data)
  values (p_tenant_id, v_actor, 'secret_ref.upsert', 'tenant_secret_ref', v_ref_id,
          case when v_before is not null then jsonb_build_object('kind', p_kind::text) else null end,
          jsonb_build_object('kind', p_kind::text));

  return v_ref_id;
end;
$$;

revoke all on function app.next_document_number(uuid, text, integer, uuid) from public, anon, authenticated;
revoke all on function app.create_journal_entry(uuid, uuid, date, text, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function app.reverse_journal_entry(uuid, uuid, uuid, date, text) from public, anon, authenticated;
revoke all on function public.manage_tenant_secret_ref(uuid, public.secret_kind, uuid) from public, anon;
grant execute on function public.manage_tenant_secret_ref(uuid, public.secret_kind, uuid) to authenticated;
