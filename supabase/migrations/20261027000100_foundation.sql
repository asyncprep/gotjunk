-- Truck Team OS: foundation
-- Types, settings, users, roster and admin-controlled lookup tables.
-- Every table carries created_at/by and updated_at/by; set_row_audit_columns() maintains them.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

create type public.app_role as enum ('ttm', 'dispatcher', 'admin', 'senior_ops');

create type public.shift_status as enum (
  'open', 'in_progress', 'submitted', 'returned', 'locked', 'reopened', 'reconciled', 'archived'
);

create type public.hours_type as enum ('regular_junk', 'warehouse', 'non_junk');

-- null outcome on a job = draft (auto-saved, not yet completed or cancelled)
create type public.job_outcome as enum ('completed', 'cancelled_pending', 'cancelled_confirmed');

create type public.disposal_direction as enum ('cost', 'credit', 'no_charge');

-- 'never' = actual weight is always billed (default for credits). Open item R3.
create type public.min_applies_to as enum ('transaction', 'never');

create type public.photo_kind as enum ('disposal_ticket', 'cash_submission');

create type public.ui_language as enum ('fr', 'en');

-- ---------------------------------------------------------------------------
-- Row audit columns
-- ---------------------------------------------------------------------------

create function public.set_row_audit_columns() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := coalesce(new.created_at, now());
    new.created_by := coalesce(new.created_by, auth.uid());
  else
    new.created_at := old.created_at;
    new.created_by := old.created_by;
  end if;
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Settings (business rules that are values, not code)
-- ---------------------------------------------------------------------------

create table public.app_setting (
  key text primary key,
  value jsonb not null,
  description text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

insert into public.app_setting (key, value, description) values
  ('timezone',           '"America/Toronto"', 'Business time zone used to derive dates (Montréal)'),
  ('crew_min',           '2',                 'Minimum active crew members to submit a shift'),
  ('crew_max',           '3',                 'Maximum active crew members on a shift'),
  ('sales_tax_rate',     '0.14975',           'GST 5% + QST 9.975%; used only for a soft warning'),
  ('tax_tolerance',      '0.05',              'Allowed difference in $ for the tax soft check'),
  ('cash_includes_tips', 'true',              'Whether cash tips are part of expected cash (open item B/C)');

create function public.setting_text(p_key text) returns text
language sql stable security definer set search_path = public as $$
  select value #>> '{}' from public.app_setting where key = p_key
$$;

create function public.setting_num(p_key text) returns numeric
language sql stable security definer set search_path = public as $$
  select (value #>> '{}')::numeric from public.app_setting where key = p_key
$$;

create function public.setting_bool(p_key text) returns boolean
language sql stable security definer set search_path = public as $$
  select (value #>> '{}')::boolean from public.app_setting where key = p_key
$$;

create function public.app_tz() returns text
language sql stable as $$ select coalesce(public.setting_text('timezone'), 'America/Toronto') $$;

create function public.business_date(p_at timestamptz) returns date
language sql stable as $$ select (p_at at time zone public.app_tz())::date $$;

-- ---------------------------------------------------------------------------
-- Roster
-- ---------------------------------------------------------------------------

create table public.employee (
  employee_id uuid primary key default gen_random_uuid(),
  full_name text not null check (length(trim(full_name)) > 0),
  active boolean not null default true,
  ceridian_id text unique,
  scale_person_ref text unique,
  preferred_language public.ui_language not null default 'fr',
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

-- Ranks are a controlled list; the full hierarchy is open item A.
create table public.rank (
  rank_id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_fr text not null,
  name_en text not null,
  sort_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table public.employee_rank_history (
  rank_history_id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employee,
  rank_id uuid not null references public.rank,
  effective_from date not null,
  effective_to date,
  change_reason text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (effective_to is null or effective_to >= effective_from)
);

create index on public.employee_rank_history (employee_id, effective_from);

-- Application users. A TTM must be linked to a roster employee.
create table public.app_user (
  user_id uuid primary key references auth.users (id) on delete cascade,
  employee_id uuid unique references public.employee,
  role public.app_role not null,
  can_edit_config boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (role <> 'ttm' or employee_id is not null)
);

-- ---------------------------------------------------------------------------
-- Identity helpers (security definer so RLS policies can call them cheaply)
-- ---------------------------------------------------------------------------

create function public.current_app_role() returns public.app_role
language sql stable security definer set search_path = public as $$
  select role from public.app_user where user_id = auth.uid() and active
$$;

create function public.current_employee_id() returns uuid
language sql stable security definer set search_path = public as $$
  select employee_id from public.app_user where user_id = auth.uid() and active
$$;

create function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() in ('dispatcher', 'admin', 'senior_ops'), false)
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_app_role() in ('admin', 'senior_ops'), false)
$$;

create function public.can_edit_config() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select role = 'senior_ops' or (role = 'admin' and can_edit_config)
       from public.app_user where user_id = auth.uid() and active),
    false)
$$;

-- True for backend/system connections (migrations, Edge Functions with the service key).
-- Must stay SECURITY INVOKER: it reads the caller's role.
create function public.is_system() returns boolean
language sql stable as $$
  select current_user in ('postgres', 'service_role', 'supabase_admin')
$$;

-- ---------------------------------------------------------------------------
-- Lookups (admin-maintained, bilingual where crews read them)
-- ---------------------------------------------------------------------------

create table public.truck (
  truck_id uuid primary key default gen_random_uuid(),
  unit_number text not null unique,
  motive_vehicle_ref text,
  scale_truck_ref text unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table public.phone (
  phone_id uuid primary key default gen_random_uuid(),
  label text not null unique,
  device_ref text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table public.site (
  site_id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  site_type text not null check (site_type in ('eco_junk', 'eco_depot', 'outside_dump', 'other')),
  issues_tickets boolean not null default true,
  requires_ticket_photo boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table public.material_type (
  material_type_id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_fr text not null,
  name_en text not null,
  scale_material_code text unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table public.payment_method (
  code text primary key,
  name_fr text not null,
  name_en text not null,
  is_cash boolean not null default false,
  stripe_method_type text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table public.cancellation_reason (
  reason_id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_fr text not null,
  name_en text not null,
  sort_order int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

-- Effective-dated disposal pricing. Rates are always positive; direction carries the sign.
create table public.site_rate_config (
  rate_config_id uuid primary key default gen_random_uuid(),
  site_id uuid not null references public.site,
  material_type_id uuid not null references public.material_type,
  rate_per_ton numeric(10,2) not null check (rate_per_ton >= 0),
  direction public.disposal_direction not null,
  min_billable_kg numeric(10,1) not null default 0 check (min_billable_kg >= 0),
  min_applies_to public.min_applies_to not null default 'transaction',
  effective_from date not null,
  effective_to date,
  active boolean not null default true,
  special_rule_code text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (effective_to is null or effective_to >= effective_from),
  check (direction <> 'no_charge' or rate_per_ton = 0)
);

create index on public.site_rate_config (site_id, material_type_id, effective_from);

-- Dispatcher end-of-day checklist items (open item D: list is configurable).
create table public.checklist_item (
  item_id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label_fr text not null,
  label_en text not null,
  sort_order int not null default 0,
  required boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

-- ---------------------------------------------------------------------------
-- Effective-date overlap checks
-- ---------------------------------------------------------------------------

create function public.check_rate_overlap() returns trigger
language plpgsql as $$
begin
  if new.active and exists (
    select 1 from public.site_rate_config r
    where r.site_id = new.site_id
      and r.material_type_id = new.material_type_id
      and r.active
      and r.rate_config_id <> new.rate_config_id
      and daterange(r.effective_from, r.effective_to, '[]')
          && daterange(new.effective_from, new.effective_to, '[]')
  ) then
    raise exception 'rate_overlap: another active rate covers these dates for this site and material';
  end if;
  return new;
end $$;

create trigger site_rate_config_overlap
  before insert or update on public.site_rate_config
  for each row execute function public.check_rate_overlap();

create function public.check_rank_overlap() returns trigger
language plpgsql as $$
begin
  if exists (
    select 1 from public.employee_rank_history h
    where h.employee_id = new.employee_id
      and h.rank_history_id <> new.rank_history_id
      and daterange(h.effective_from, h.effective_to, '[]')
          && daterange(new.effective_from, new.effective_to, '[]')
  ) then
    raise exception 'rank_overlap: employee already has a rank for these dates';
  end if;
  return new;
end $$;

create trigger employee_rank_history_overlap
  before insert or update on public.employee_rank_history
  for each row execute function public.check_rank_overlap();

create function public.rank_on(p_employee uuid, p_date date) returns uuid
language sql stable security definer set search_path = public as $$
  select rank_id from public.employee_rank_history
  where employee_id = p_employee
    and p_date between effective_from and coalesce(effective_to, 'infinity'::date)
$$;

-- ---------------------------------------------------------------------------
-- Row audit column triggers for the tables above
-- ---------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'app_setting', 'employee', 'rank', 'employee_rank_history', 'app_user', 'truck', 'phone',
    'site', 'material_type', 'payment_method', 'cancellation_reason', 'site_rate_config',
    'checklist_item'
  ] loop
    execute format(
      'create trigger %I before insert or update on public.%I
         for each row execute function public.set_row_audit_columns()',
      t || '_row_audit', t);
  end loop;
end $$;
