-- Truck Team OS: operational records (the Daily Route Journal replacement)
-- Primary keys of records the crew can create offline are generated on the device (UUIDv7);
-- the server default is only a fallback for records created elsewhere.

-- ---------------------------------------------------------------------------
-- Shift
-- ---------------------------------------------------------------------------

create table public.shift (
  shift_id uuid primary key default gen_random_uuid(),
  shift_date date not null default public.business_date(now()),
  status public.shift_status not null default 'open',
  truck_id uuid not null references public.truck,
  phone_id uuid not null references public.phone,
  dispatcher_id uuid references public.app_user (user_id),
  truck_phone_confirmed_at timestamptz,
  hours_type public.hours_type,
  hours_type_confirmed_by uuid references public.app_user (user_id),
  hours_type_confirmed_at timestamptz,
  start_time timestamptz,
  finish_time timestamptz,
  total_hours numeric(5,2) generated always as (
    case when start_time is not null and finish_time is not null
      then round((extract(epoch from (finish_time - start_time)) / 3600.0)::numeric, 2)
    end) stored,
  submitted_at timestamptz,
  submitted_by uuid,
  returned_at timestamptz,
  returned_by uuid,
  return_reason text,
  locked_at timestamptz,
  locked_by uuid,
  reopened_at timestamptz,
  reopened_by uuid,
  reopen_reason text,
  reconciled_at timestamptz,
  reconciled_by uuid,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (finish_time is null or start_time is null or finish_time > start_time)
);

create unique index shift_truck_date_uq on public.shift (truck_id, shift_date) where status <> 'archived';
create unique index shift_phone_date_uq on public.shift (phone_id, shift_date) where status <> 'archived';
create index on public.shift (shift_date);
create index on public.shift (status);

create table public.shift_crew_member (
  shift_crew_id uuid primary key default gen_random_uuid(),
  shift_id uuid not null references public.shift,
  employee_id uuid not null references public.employee,
  shift_role text,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  rank_id_snapshot uuid references public.rank,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (shift_id, employee_id),
  check (left_at is null or left_at > joined_at)
);

create index on public.shift_crew_member (employee_id);

-- An employee can't be on two active shifts on the same date.
create function public.check_crew_double_booking() returns trigger
language plpgsql as $$
begin
  if exists (
    select 1
    from public.shift_crew_member m
    join public.shift s on s.shift_id = m.shift_id
    join public.shift this on this.shift_id = new.shift_id
    where m.employee_id = new.employee_id
      and m.shift_crew_id <> new.shift_crew_id
      and s.shift_date = this.shift_date
      and s.status <> 'archived'
  ) then
    raise exception 'crew_double_booked: employee is already on another shift that date';
  end if;
  return new;
end $$;

create trigger shift_crew_member_double_booking
  before insert or update of employee_id, shift_id on public.shift_crew_member
  for each row execute function public.check_crew_double_booking();

-- ---------------------------------------------------------------------------
-- Job
-- ---------------------------------------------------------------------------

create table public.job (
  job_id uuid primary key default gen_random_uuid(),
  shift_id uuid not null references public.shift,
  opportunity_id text not null check (length(trim(opportunity_id)) between 1 and 40),
  outcome public.job_outcome,
  completed_at timestamptz,
  payment_method_code text references public.payment_method (code),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  revenue_pre_tax numeric(12,2) check (revenue_pre_tax >= 0),
  revenue_total_incl_tax numeric(12,2) check (revenue_total_incl_tax >= 0),
  tip_amount numeric(12,2) not null default 0 check (tip_amount >= 0),
  expected_payment_total numeric(12,2) generated always as (coalesce(revenue_total_incl_tax, 0) + tip_amount) stored,
  cancellation_reason_id uuid references public.cancellation_reason,
  cancellation_finalized_by uuid,
  cancellation_finalized_at timestamptz,
  reconciliation_status text not null default 'unchecked'
    check (reconciliation_status in ('unchecked', 'matched', 'exception', 'resolved')),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (shift_id, opportunity_id),
  check (revenue_total_incl_tax is null or revenue_pre_tax is null or revenue_total_incl_tax >= revenue_pre_tax),
  constraint job_completed_requires_financials check (
    outcome is distinct from 'completed'
    or (payment_method_code is not null and revenue_pre_tax is not null and revenue_total_incl_tax is not null)),
  constraint job_confirmed_requires_reason check (
    outcome is distinct from 'cancelled_confirmed' or cancellation_reason_id is not null)
);

create index on public.job (opportunity_id);

-- ---------------------------------------------------------------------------
-- Disposal
-- ---------------------------------------------------------------------------

create table public.disposal_visit (
  disposal_visit_id uuid primary key default gen_random_uuid(),
  shift_id uuid not null references public.shift,
  site_id uuid not null references public.site,
  visit_at timestamptz not null default now(),
  ticket_number text,
  exception_status text not null default 'none'
    check (exception_status in ('none', 'missing_photo', 'missing_ticket', 'scale_mismatch', 'other')),
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create unique index disposal_visit_ticket_uq on public.disposal_visit (site_id, ticket_number)
  where ticket_number is not null;
create index on public.disposal_visit (shift_id);

-- Rate, minimum and direction are copied from config when the line is recorded,
-- so later rate changes never rewrite history.
create table public.disposal_material_txn (
  material_txn_id uuid primary key default gen_random_uuid(),
  disposal_visit_id uuid not null references public.disposal_visit on delete cascade,
  material_type_id uuid not null references public.material_type,
  weight_kg numeric(10,1) not null check (weight_kg > 0),
  rate_config_id uuid not null references public.site_rate_config,
  rate_per_ton_applied numeric(10,2) not null,
  direction public.disposal_direction not null,
  min_billable_kg_applied numeric(10,1) not null,
  billable_kg numeric(10,1) not null,
  signed_amount numeric(12,2) not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create index on public.disposal_material_txn (disposal_visit_id);

-- ---------------------------------------------------------------------------
-- Cash
-- ---------------------------------------------------------------------------

create table public.cash_submission (
  cash_submission_id uuid primary key default gen_random_uuid(),
  shift_id uuid not null unique references public.shift,
  counted_cash numeric(12,2) check (counted_cash >= 0),
  expected_cash_snapshot numeric(12,2),
  envelope_id text,
  received_by uuid references public.app_user (user_id),
  storage_location text,
  mismatch_resolution text,
  verified_by uuid,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

-- ---------------------------------------------------------------------------
-- Photos (files live in the private 'photos' storage bucket at {shift_id}/{photo_id}.jpg)
-- ---------------------------------------------------------------------------

create table public.photo (
  photo_id uuid primary key default gen_random_uuid(),
  shift_id uuid not null references public.shift,
  photo_kind public.photo_kind not null,
  entity_type text not null check (entity_type in ('disposal_visit', 'cash_submission')),
  entity_id uuid not null,
  storage_path text not null unique,
  sha256 text,
  captured_at timestamptz,
  uploaded_at timestamptz,
  uploaded_by uuid,
  retention_until date,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((photo_kind = 'disposal_ticket' and entity_type = 'disposal_visit')
      or (photo_kind = 'cash_submission' and entity_type = 'cash_submission'))
);

create index on public.photo (entity_type, entity_id);
create index on public.photo (shift_id);

-- A photo must belong to a record on the same shift.
create function public.check_photo_entity() returns trigger
language plpgsql as $$
declare v_shift uuid;
begin
  if new.entity_type = 'disposal_visit' then
    select shift_id into v_shift from public.disposal_visit where disposal_visit_id = new.entity_id;
  else
    select shift_id into v_shift from public.cash_submission where cash_submission_id = new.entity_id;
  end if;
  if v_shift is null then
    raise exception 'photo_entity_missing: % % does not exist', new.entity_type, new.entity_id;
  end if;
  if v_shift <> new.shift_id then
    raise exception 'photo_shift_mismatch: photo shift does not match its record';
  end if;
  return new;
end $$;

create trigger photo_entity_check
  before insert or update on public.photo
  for each row execute function public.check_photo_entity();

-- ---------------------------------------------------------------------------
-- Dispatcher checklist per shift
-- ---------------------------------------------------------------------------

create table public.shift_checklist_check (
  shift_id uuid not null references public.shift,
  item_id uuid not null references public.checklist_item,
  checked boolean not null default false,
  checked_by uuid,
  checked_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (shift_id, item_id)
);

do $$
declare t text;
begin
  foreach t in array array[
    'shift', 'shift_crew_member', 'job', 'disposal_visit', 'disposal_material_txn',
    'cash_submission', 'photo', 'shift_checklist_check'
  ] loop
    execute format(
      'create trigger %I before insert or update on public.%I
         for each row execute function public.set_row_audit_columns()',
      t || '_row_audit', t);
  end loop;
end $$;
