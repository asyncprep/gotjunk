-- Truck Team OS: fixes from the Oct 30, 2026 review, and client answers (Projet page).

-- ---------------------------------------------------------------------------
-- 1. A truck (and its phone) can run two shifts the same day (client answer H2).
--    An employee can't be on two shifts that are both still active the same day,
--    but can do an afternoon shift once the morning one is submitted.
-- ---------------------------------------------------------------------------

drop index public.shift_truck_date_uq;
drop index public.shift_phone_date_uq;
create index if not exists shift_truck_date_idx on public.shift (truck_id, shift_date);

create or replace function public.check_crew_double_booking() returns trigger
language plpgsql as $$
begin
  if exists (
    select 1
    from public.shift_crew_member m
    join public.shift s on s.shift_id = m.shift_id
    join public.shift this on this.shift_id = new.shift_id
    where m.employee_id = new.employee_id
      and m.shift_crew_id <> new.shift_crew_id
      and m.left_at is null
      and s.shift_date = this.shift_date
      and s.status in ('open', 'in_progress', 'returned', 'reopened')
      and this.status in ('open', 'in_progress', 'returned', 'reopened')
  ) then
    raise exception 'crew_double_booked: employee is already on another active shift that day';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Dispatch can cancel a shift that won't run (truck breakdown…), with a reason.
-- ---------------------------------------------------------------------------

alter table public.shift add column cancel_reason text;

create or replace function public.transition_allowed(
  p_from public.shift_status, p_to public.shift_status, p_role public.app_role
) returns boolean
language sql immutable as $$
  select coalesce(case
    when (p_from::text, p_to::text) in (('open', 'in_progress'), ('in_progress', 'submitted'),
                                        ('returned', 'submitted'), ('reopened', 'submitted'))
      then p_role in ('ttm', 'dispatcher', 'admin', 'senior_ops')
    when (p_from::text, p_to::text) in (('submitted', 'returned'), ('submitted', 'locked'),
                                        ('locked', 'reopened'), ('open', 'archived'))
      then p_role in ('dispatcher', 'admin', 'senior_ops')
    when (p_from::text, p_to::text) in (('locked', 'reconciled'), ('reconciled', 'reopened'),
                                        ('reconciled', 'archived'))
      then p_role in ('admin', 'senior_ops')
    else false
  end, false)
$$;

-- Columns that changed between two versions of a row (ignoring ones triggers maintain).
create or replace function public.changed_columns(p_old jsonb, p_new jsonb) returns text[]
language sql immutable as $$
  select coalesce(array_agg(k), '{}')
  from jsonb_object_keys(p_new) k
  where (p_old -> k) is distinct from (p_new -> k)
    and k not in ('updated_at', 'updated_by', 'created_at', 'created_by', 'total_hours', 'expected_payment_total')
$$;

-- ---------------------------------------------------------------------------
-- 3. Shift rules: crew may change only an explicit list of columns.
-- ---------------------------------------------------------------------------

create or replace function public.shift_before_update() returns trigger
language plpgsql as $$
declare
  v_role public.app_role := public.current_app_role();
  v_system boolean := public.is_system();
  v_extra text[];
begin
  if not v_system then
    if v_role is null then
      raise exception 'not_allowed';
    end if;

    if new.status = old.status then
      if old.status in ('locked', 'reconciled', 'archived') then
        raise exception 'shift_locked: reopen the shift before editing';
      end if;
      if v_role = 'ttm' and not public.crew_can_edit(old.status) then
        raise exception 'shift_not_editable: shift is waiting for dispatcher review';
      end if;
    end if;

    if v_role = 'ttm' then
      v_extra := array(select unnest(public.changed_columns(to_jsonb(old), to_jsonb(new)))
                       except select unnest(array['hours_type', 'start_time', 'finish_time',
                                                  'truck_phone_confirmed_at', 'status']));
      if cardinality(v_extra) > 0 then
        raise exception 'not_allowed: crew cannot change %', array_to_string(v_extra, ', ');
      end if;
    end if;

    if new.status is distinct from old.status
       and not public.transition_allowed(old.status, new.status, v_role) then
      raise exception 'invalid_transition: % -> % is not allowed for %', old.status, new.status, v_role;
    end if;
  end if;

  if new.hours_type is distinct from old.hours_type then
    if v_role = 'ttm' then
      new.hours_type_confirmed_at := null;
      new.hours_type_confirmed_by := null;
    elsif v_role is not null then
      new.hours_type_confirmed_at := now();
    end if;
  end if;
  if new.hours_type_confirmed_at is not null
     and new.hours_type_confirmed_at is distinct from old.hours_type_confirmed_at then
    if new.hours_type is null then
      raise exception 'hours_type_missing: nothing to confirm';
    end if;
    new.hours_type_confirmed_by := auth.uid();
  end if;

  if new.status is distinct from old.status then
    case new.status
      when 'in_progress' then
        if new.hours_type is null then
          raise exception 'hours_type_missing: select the hours type before starting';
        end if;
        -- The phone sends the moment the crew actually started; now() only if it didn't.
        new.truck_phone_confirmed_at := coalesce(new.truck_phone_confirmed_at, new.start_time, now());
        new.start_time := coalesce(new.start_time, now());
      when 'submitted' then
        new.submitted_at := now();
        new.submitted_by := auth.uid();
        new.return_reason := null;
        new.reopen_reason := null;
      when 'returned' then
        if coalesce(trim(new.return_reason), '') = '' then
          raise exception 'reason_required: a reason is required to return a shift';
        end if;
        new.returned_at := now();
        new.returned_by := auth.uid();
      when 'locked' then
        new.locked_at := now();
        new.locked_by := auth.uid();
      when 'reopened' then
        if coalesce(trim(new.reopen_reason), '') = '' then
          raise exception 'reason_required: a reason is required to reopen a shift';
        end if;
        new.reopened_at := now();
        new.reopened_by := auth.uid();
      when 'reconciled' then
        new.reconciled_at := now();
        new.reconciled_by := auth.uid();
      when 'archived' then
        if old.status = 'open' and coalesce(trim(new.cancel_reason), '') = '' then
          raise exception 'reason_required: a reason is required to cancel a shift';
        end if;
      else
        null;
    end case;
  end if;

  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Jobs: crew can't touch reconciliation or dispatch fields.
-- ---------------------------------------------------------------------------

create or replace function public.job_rules() returns trigger
language plpgsql as $$
declare v_role public.app_role := public.current_app_role();
begin
  if not public.is_system() and v_role = 'ttm' then
    if tg_op <> 'INSERT' and old.outcome = 'cancelled_confirmed' then
      raise exception 'not_allowed: cancellation already finalized by dispatch';
    end if;
    if tg_op = 'DELETE' then
      return old;
    end if;
    if new.outcome = 'cancelled_confirmed'
       or new.cancellation_reason_id is not null
       or new.cancellation_finalized_at is not null
       or new.cancellation_finalized_by is not null then
      raise exception 'not_allowed: only dispatch sets the cancellation reason';
    end if;
    if new.reconciliation_status is distinct from
       (case when tg_op = 'UPDATE' then old.reconciliation_status else 'unchecked' end) then
      raise exception 'not_allowed: crew cannot change reconciliation_status';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  -- The phone sends when the job was completed; now() only if it didn't.
  if new.outcome = 'completed' then
    new.completed_at := coalesce(new.completed_at, now());
  end if;
  if new.outcome = 'cancelled_confirmed'
     and (tg_op = 'INSERT' or old.outcome is distinct from 'cancelled_confirmed') then
    new.cancellation_finalized_at := now();
    new.cancellation_finalized_by := auth.uid();
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Cash: crew can't delete a cash record dispatch has already counted.
-- ---------------------------------------------------------------------------

create or replace function public.cash_rules() returns trigger
language plpgsql as $$
begin
  if not public.is_system() and public.current_app_role() = 'ttm' then
    if tg_op = 'DELETE' then
      if old.counted_cash is not null or old.verified_at is not null then
        raise exception 'not_allowed: dispatch already counted this cash';
      end if;
      return old;
    end if;
    if (new.counted_cash is distinct from case when tg_op = 'UPDATE' then old.counted_cash end
       or new.envelope_id is distinct from case when tg_op = 'UPDATE' then old.envelope_id end
       or new.received_by is distinct from case when tg_op = 'UPDATE' then old.received_by end
       or new.storage_location is distinct from case when tg_op = 'UPDATE' then old.storage_location end
       or new.mismatch_resolution is distinct from case when tg_op = 'UPDATE' then old.mismatch_resolution end
       or new.verified_at is distinct from case when tg_op = 'UPDATE' then old.verified_at end
       or new.verified_by is distinct from case when tg_op = 'UPDATE' then old.verified_by end
       or new.expected_cash_snapshot is distinct from case when tg_op = 'UPDATE' then old.expected_cash_snapshot end) then
      raise exception 'not_allowed: only dispatch records the cash count';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  if new.counted_cash is not null
     and (tg_op = 'INSERT' or new.counted_cash is distinct from old.counted_cash) then
    new.verified_at := now();
    new.verified_by := auth.uid();
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 6. Photos must point into their own shift's folder.
-- ---------------------------------------------------------------------------

create or replace function public.check_photo_entity() returns trigger
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
  if new.storage_path not like new.shift_id::text || '/%' then
    raise exception 'photo_shift_mismatch: photo file must be in its shift''s folder';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Readiness checks: tips nobody receives, and photos whose file never arrived.
-- ---------------------------------------------------------------------------

create or replace function public.shift_problems(p_shift_id uuid, p_stage text default 'submit')
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

  -- Signed-in callers may only inspect shifts they can see. Anonymous callers can't execute
  -- this function at all (see grants below); no JWT here means a backend/system call.
  if auth.uid() is not null and not (public.is_staff() or public.is_crew_member(p_shift_id)) then
    raise exception 'not_allowed';
  end if;

  select * into v_totals from public.v_shift_totals where shift_id = p_shift_id;
  select * into v_cash from public.cash_submission where shift_id = p_shift_id;

  select count(*) into v_crew from public.shift_crew_member
  where shift_id = p_shift_id and left_at is null;

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

  -- A tip must go to someone: no crew member present when the job was completed means the
  -- crew times are wrong. Dispatch fixes joined/left times; blocks acceptance.
  return query
    select case when p_stage = 'lock' then 'error' else 'warning' end, 'tip_unassigned', 'job', j.job_id, j.opportunity_id
    from public.job j
    where j.shift_id = p_shift_id and j.outcome = 'completed' and j.tip_amount > 0
      and not exists (
        select 1 from public.shift_crew_member m
        where m.shift_id = j.shift_id
          and m.joined_at <= coalesce(j.completed_at, j.created_at)
          and (m.left_at is null or m.left_at > coalesce(j.completed_at, j.created_at)));

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

    -- Photo rows whose file never reached storage (phone lost, still offline…).
    if to_regclass('storage.objects') is not null then
      return query execute
        'select ''error''::text, ''photo_not_uploaded''::text, ''photo''::text, p.photo_id, p.photo_kind::text
           from public.photo p
          where p.shift_id = $1
            and not exists (select 1 from storage.objects o where o.bucket_id = ''photos'' and o.name = p.storage_path)'
        using p_shift_id;
    end if;

    return query
      select 'warning', 'cancellation_pending', 'job', j.job_id, j.opportunity_id
      from public.job j where j.shift_id = p_shift_id and j.outcome = 'cancelled_pending';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. Only senior ops grants senior ops or configuration rights; nobody edits their own access.
-- ---------------------------------------------------------------------------

create function public.app_user_guard() returns trigger
language plpgsql as $$
declare v_role public.app_role := public.current_app_role();
begin
  if public.is_system() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op <> 'INSERT' and old.user_id = auth.uid() then
    raise exception 'not_allowed: you cannot change your own access';
  end if;
  if v_role is distinct from 'senior_ops' then
    if (tg_op <> 'DELETE' and new.role = 'senior_ops') or (tg_op <> 'INSERT' and old.role = 'senior_ops') then
      raise exception 'not_allowed: only senior ops can grant or change senior ops access';
    end if;
    if tg_op <> 'DELETE' and new.can_edit_config
       and (tg_op = 'INSERT' or not old.can_edit_config) then
      raise exception 'not_allowed: only senior ops can grant configuration rights';
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

create trigger app_user_a_guard
  before insert or update or delete on public.app_user
  for each row execute function public.app_user_guard();

-- ---------------------------------------------------------------------------
-- 9. Rank changes: setting a rank again for the same (or an earlier) date replaces
--    the rows it supersedes instead of failing.
-- ---------------------------------------------------------------------------

create or replace function public.set_employee_rank(
  p_employee_id uuid, p_rank_id uuid, p_effective_from date, p_reason text default null
) returns void
language plpgsql as $$
begin
  if not (public.is_system() or public.is_admin()) then
    raise exception 'not_allowed: only administration changes ranks';
  end if;

  delete from public.employee_rank_history
   where employee_id = p_employee_id and effective_from >= p_effective_from;

  update public.employee_rank_history
     set effective_to = p_effective_from - 1
   where employee_id = p_employee_id
     and effective_from < p_effective_from
     and (effective_to is null or effective_to >= p_effective_from);

  insert into public.employee_rank_history (employee_id, rank_id, effective_from, change_reason)
  values (p_employee_id, p_rank_id, p_effective_from, p_reason);
end $$;

-- ---------------------------------------------------------------------------
-- 10. Rates: a new rate closes the current one the day before; credits never use a minimum.
-- ---------------------------------------------------------------------------

update public.site_rate_config set min_applies_to = 'never', min_billable_kg = 0
 where direction = 'credit' and min_applies_to <> 'never';

alter table public.site_rate_config
  add constraint site_rate_credit_no_minimum check (direction <> 'credit' or min_applies_to = 'never');

create function public.add_site_rate(
  p_site_id uuid, p_material_type_id uuid, p_rate_per_ton numeric, p_direction public.disposal_direction,
  p_min_billable_kg numeric, p_min_applies_to public.min_applies_to, p_effective_from date
) returns uuid
language plpgsql as $$
declare v_id uuid;
begin
  update public.site_rate_config
     set effective_to = p_effective_from - 1
   where site_id = p_site_id and material_type_id = p_material_type_id and active
     and effective_from < p_effective_from
     and (effective_to is null or effective_to >= p_effective_from);

  insert into public.site_rate_config
    (site_id, material_type_id, rate_per_ton, direction, min_billable_kg, min_applies_to, effective_from)
  values (p_site_id, p_material_type_id, p_rate_per_ton, p_direction,
          case when p_direction = 'credit' then 0 else p_min_billable_kg end,
          case when p_direction = 'credit' then 'never' else p_min_applies_to end,
          p_effective_from)
  returning rate_config_id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- 11. Functions are for signed-in users and the backend only (none for anonymous callers).
-- ---------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated, service_role;
alter default privileges in schema public revoke execute on functions from public, anon;
revoke execute on function public.snapshot_shift_on_lock(uuid) from authenticated;
revoke execute on function public.write_audit_log() from authenticated;

-- ---------------------------------------------------------------------------
-- 12. Projet page: reflect the client's answers in the "meanwhile" text.
-- ---------------------------------------------------------------------------

update public.spec_item set build_default = $s$iPhone only (company phones, MDM in place)$s$ where ref = 'S2';
update public.spec_item set build_default = $s$Two shifts per truck per day allowed (since Oct 30, 2026)$s$ where ref = 'H2';
update public.spec_item set build_default = $s$Crew enters amounts in V1; Stripe carries Opportunity ID, GST and pre-tax amount, so amounts can be imported later$s$ where ref = 'I-03';
update public.spec_item set build_default = $s$Stripe is an HQ sub-account and API keys can be created (answer F1); integration planned for V1b$s$ where ref = 'I-11';
update public.spec_item set detail = $s$§3 and §4 call for a mobile-first web app installable on iPhone. Offline needs (§11) led to a native Flutter app; crews use iPhone only. The spec should be updated.$s$ where ref = 'I-13';
