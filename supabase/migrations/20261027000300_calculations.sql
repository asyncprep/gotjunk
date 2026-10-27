-- Truck Team OS: calculations
-- The crew never does arithmetic: disposal pricing, totals, tip split and cash are computed here.

-- ---------------------------------------------------------------------------
-- Disposal pricing
-- ---------------------------------------------------------------------------

create function public.price_material_txn() returns trigger
language plpgsql as $$
declare
  v_site uuid;
  v_visit_at timestamptz;
  r public.site_rate_config%rowtype;
begin
  select site_id, visit_at into v_site, v_visit_at
  from public.disposal_visit where disposal_visit_id = new.disposal_visit_id;

  -- Re-price only when the inputs change; otherwise keep the historical snapshot.
  if tg_op = 'UPDATE'
     and new.material_type_id = old.material_type_id
     and new.weight_kg = old.weight_kg
     and new.disposal_visit_id = old.disposal_visit_id
     and not coalesce(current_setting('tto.reprice', true), '') = 'on' then
    new.rate_config_id := old.rate_config_id;
    new.rate_per_ton_applied := old.rate_per_ton_applied;
    new.direction := old.direction;
    new.min_billable_kg_applied := old.min_billable_kg_applied;
    new.billable_kg := old.billable_kg;
    new.signed_amount := old.signed_amount;
    return new;
  end if;

  select * into r from public.site_rate_config c
  where c.site_id = v_site
    and c.material_type_id = new.material_type_id
    and c.active
    and public.business_date(v_visit_at) between c.effective_from and coalesce(c.effective_to, 'infinity'::date);

  if not found then
    raise exception 'no_rate: no active rate for this site and material on %', public.business_date(v_visit_at);
  end if;

  new.rate_config_id := r.rate_config_id;
  new.rate_per_ton_applied := r.rate_per_ton;
  new.direction := r.direction;
  new.min_billable_kg_applied := case when r.min_applies_to = 'transaction' then r.min_billable_kg else 0 end;
  new.billable_kg := greatest(new.weight_kg, new.min_billable_kg_applied);
  -- Metric tonnes (open item R3). Costs are positive, credits negative.
  new.signed_amount := round(new.billable_kg / 1000.0 * r.rate_per_ton, 2)
    * case r.direction when 'cost' then 1 when 'credit' then -1 else 0 end;
  return new;
end $$;

create trigger disposal_material_txn_price
  before insert or update on public.disposal_material_txn
  for each row execute function public.price_material_txn();

-- Moving a visit to another site or date re-prices its lines.
create function public.reprice_visit_lines() returns trigger
language plpgsql as $$
begin
  if new.site_id is distinct from old.site_id
     or public.business_date(new.visit_at) is distinct from public.business_date(old.visit_at) then
    perform set_config('tto.reprice', 'on', true);
    update public.disposal_material_txn set weight_kg = weight_kg
    where disposal_visit_id = new.disposal_visit_id;
    perform set_config('tto.reprice', '', true);
  end if;
  return new;
end $$;

create trigger disposal_visit_reprice
  after update of site_id, visit_at on public.disposal_visit
  for each row execute function public.reprice_visit_lines();

-- ---------------------------------------------------------------------------
-- Live shift totals (the scoreboard)
-- ---------------------------------------------------------------------------

create view public.v_shift_totals with (security_invoker = true) as
select
  s.shift_id,
  coalesce(j.jobs_completed, 0) as jobs_completed,
  coalesce(j.jobs_cancelled, 0) as jobs_cancelled,
  coalesce(j.jobs_draft, 0) as jobs_draft,
  coalesce(j.revenue_pre_tax, 0)::numeric(12,2) as revenue_pre_tax,
  coalesce(j.revenue_total_incl_tax, 0)::numeric(12,2) as revenue_total_incl_tax,
  coalesce(j.discounts, 0)::numeric(12,2) as discounts,
  coalesce(j.tips, 0)::numeric(12,2) as tips,
  coalesce(j.expected_cash, 0)::numeric(12,2) as expected_cash,
  coalesce(d.net_disposal, 0)::numeric(12,2) as net_disposal,
  s.total_hours,
  case when s.total_hours > 0 then round(coalesce(j.revenue_pre_tax, 0) / s.total_hours, 2) end as revenue_per_hour
from public.shift s
left join lateral (
  select
    count(*) filter (where outcome = 'completed') as jobs_completed,
    count(*) filter (where outcome in ('cancelled_pending', 'cancelled_confirmed')) as jobs_cancelled,
    count(*) filter (where outcome is null) as jobs_draft,
    sum(revenue_pre_tax) filter (where outcome = 'completed') as revenue_pre_tax,
    sum(revenue_total_incl_tax) filter (where outcome = 'completed') as revenue_total_incl_tax,
    sum(discount_amount) filter (where outcome = 'completed') as discounts,
    sum(tip_amount) filter (where outcome = 'completed') as tips,
    sum(revenue_total_incl_tax
        + case when coalesce(public.setting_bool('cash_includes_tips'), true) then tip_amount else 0 end)
      filter (where outcome = 'completed' and pm.is_cash) as expected_cash
  from public.job
  left join public.payment_method pm on pm.code = job.payment_method_code
  where job.shift_id = s.shift_id
) j on true
left join lateral (
  select sum(t.signed_amount) as net_disposal
  from public.disposal_visit v
  join public.disposal_material_txn t on t.disposal_visit_id = v.disposal_visit_id
  where v.shift_id = s.shift_id
) d on true;

-- ---------------------------------------------------------------------------
-- Tip split: equal shares among crew present when the job was completed.
-- Leftover cents go to the first members in a stable order. Overrides are open item B.
-- ---------------------------------------------------------------------------

create view public.v_tip_split with (security_invoker = true) as
with present as (
  select
    j.job_id, j.shift_id, j.tip_amount, m.employee_id,
    count(*) over (partition by j.job_id) as n,
    row_number() over (partition by j.job_id order by m.joined_at, m.employee_id) as rn
  from public.job j
  join public.shift_crew_member m
    on m.shift_id = j.shift_id
   and m.joined_at <= coalesce(j.completed_at, j.created_at)
   and (m.left_at is null or m.left_at > coalesce(j.completed_at, j.created_at))
  where j.outcome = 'completed' and j.tip_amount > 0
)
select
  job_id, shift_id, employee_id,
  ((floor(tip_amount * 100 / n)
    + case when rn <= (tip_amount * 100 - floor(tip_amount * 100 / n) * n) then 1 else 0 end) / 100.0
  )::numeric(12,2) as tip_share
from present;

create view public.v_shift_tips_by_employee with (security_invoker = true) as
select shift_id, employee_id, sum(tip_share)::numeric(12,2) as tips
from public.v_tip_split
group by shift_id, employee_id;

-- ---------------------------------------------------------------------------
-- Readiness checks. Returns problem codes the apps translate (fr/en).
-- stage 'submit' = crew submission; 'lock' = dispatcher acceptance (includes submit checks).
-- ---------------------------------------------------------------------------

create function public.shift_problems(p_shift_id uuid, p_stage text default 'submit')
returns table (severity text, code text, entity_type text, entity_id uuid, detail text)
language plpgsql stable security definer set search_path = public as $$
declare
  s public.shift%rowtype;
  v_totals public.v_shift_totals%rowtype;
  v_crew int;
  v_cash public.cash_submission%rowtype;
begin
  if p_stage not in ('submit', 'lock') then
    raise exception 'invalid_stage: %', p_stage;
  end if;

  select * into s from public.shift where shift_id = p_shift_id;
  if not found then
    raise exception 'shift_not_found';
  end if;

  -- Signed-in callers may only inspect shifts they can see. (No JWT = backend/system call.
  -- is_system() can't be used here: inside SECURITY DEFINER current_user is the owner.)
  if auth.uid() is not null and not (public.is_staff() or public.is_crew_member(p_shift_id)) then
    raise exception 'not_allowed';
  end if;

  select * into v_totals from public.v_shift_totals where shift_id = p_shift_id;
  select * into v_cash from public.cash_submission where shift_id = p_shift_id;

  select count(*) into v_crew from public.shift_crew_member
  where shift_id = p_shift_id and left_at is null;

  -- Shift header
  if v_crew < public.setting_num('crew_min') or v_crew > public.setting_num('crew_max') then
    return query select 'error', 'crew_size', 'shift', p_shift_id, v_crew::text;
  end if;
  if s.hours_type is null then
    return query select 'error', 'hours_type_missing', 'shift', p_shift_id, null::text;
  end if;
  if s.start_time is null then
    return query select 'error', 'start_time_missing', 'shift', p_shift_id, null::text;
  end if;
  if s.finish_time is null then
    return query select 'error', 'finish_time_missing', 'shift', p_shift_id, null::text;
  end if;

  -- Jobs
  return query
    select 'error', 'job_incomplete', 'job', j.job_id, j.opportunity_id
    from public.job j where j.shift_id = p_shift_id and j.outcome is null;

  return query
    select 'warning', 'tax_check', 'job', j.job_id, j.opportunity_id
    from public.job j
    where j.shift_id = p_shift_id and j.outcome = 'completed'
      and abs(j.revenue_total_incl_tax - round(j.revenue_pre_tax * (1 + public.setting_num('sales_tax_rate')), 2))
          > public.setting_num('tax_tolerance');

  return query
    select distinct 'warning', 'opportunity_repeated', 'job', j.job_id, j.opportunity_id
    from public.job j
    join public.job o on o.opportunity_id = j.opportunity_id and o.shift_id <> j.shift_id
    join public.shift os on os.shift_id = o.shift_id and os.status <> 'archived'
    where j.shift_id = p_shift_id;

  -- Disposal
  return query
    select 'error', 'ticket_number_missing', 'disposal_visit', v.disposal_visit_id, st.name
    from public.disposal_visit v join public.site st on st.site_id = v.site_id
    where v.shift_id = p_shift_id and st.issues_tickets
      and coalesce(trim(v.ticket_number), '') = '';

  return query
    select 'error', 'ticket_photo_missing', 'disposal_visit', v.disposal_visit_id, st.name
    from public.disposal_visit v join public.site st on st.site_id = v.site_id
    where v.shift_id = p_shift_id and st.requires_ticket_photo
      and not exists (select 1 from public.photo p
                      where p.entity_type = 'disposal_visit' and p.entity_id = v.disposal_visit_id);

  return query
    select 'error', 'visit_no_materials', 'disposal_visit', v.disposal_visit_id, null::text
    from public.disposal_visit v
    where v.shift_id = p_shift_id
      and not exists (select 1 from public.disposal_material_txn t where t.disposal_visit_id = v.disposal_visit_id);

  -- Cash
  if v_totals.expected_cash > 0 and not exists (
      select 1 from public.photo p where p.shift_id = p_shift_id and p.photo_kind = 'cash_submission') then
    return query select 'error', 'cash_photo_missing', 'shift', p_shift_id, v_totals.expected_cash::text;
  end if;

  if p_stage = 'lock' then
    if s.hours_type_confirmed_at is null then
      return query select 'error', 'hours_type_unconfirmed', 'shift', p_shift_id, null::text;
    end if;

    return query
      select 'error', 'checklist_incomplete', 'checklist_item', ci.item_id, ci.code
      from public.checklist_item ci
      where ci.active and ci.required
        and not exists (select 1 from public.shift_checklist_check c
                        where c.shift_id = p_shift_id and c.item_id = ci.item_id and c.checked);

    if v_totals.expected_cash > 0 and (v_cash.cash_submission_id is null or v_cash.counted_cash is null) then
      return query select 'error', 'cash_not_counted', 'shift', p_shift_id, v_totals.expected_cash::text;
    end if;

    if v_cash.counted_cash is not null
       and v_cash.counted_cash <> v_totals.expected_cash
       and coalesce(trim(v_cash.mismatch_resolution), '') = '' then
      return query select 'error', 'cash_variance_unresolved', 'cash_submission', v_cash.cash_submission_id,
        (v_cash.counted_cash - v_totals.expected_cash)::text;
    end if;

    return query
      select 'warning', 'cancellation_pending', 'job', j.job_id, j.opportunity_id
      from public.job j where j.shift_id = p_shift_id and j.outcome = 'cancelled_pending';
  end if;
end $$;
