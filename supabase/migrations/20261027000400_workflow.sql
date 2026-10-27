-- Truck Team OS: workflow
-- Status changes are plain column updates (so they sync offline) validated by triggers:
--   open -> in_progress -> submitted -> locked -> reconciled -> archived
--   submitted -> returned -> submitted;  locked/reconciled -> reopened -> submitted

create function public.is_crew_member(p_shift_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.shift_crew_member
    where shift_id = p_shift_id and employee_id = public.current_employee_id())
$$;

create function public.crew_can_edit(p_status public.shift_status) returns boolean
language sql immutable as $$
  select coalesce(p_status in ('open', 'in_progress', 'returned', 'reopened'), false)
$$;

create function public.transition_allowed(
  p_from public.shift_status, p_to public.shift_status, p_role public.app_role
) returns boolean
language sql immutable as $$
  select coalesce(case
    when (p_from::text, p_to::text) in (('open', 'in_progress'), ('in_progress', 'submitted'),
                                        ('returned', 'submitted'), ('reopened', 'submitted'))
      then p_role in ('ttm', 'dispatcher', 'admin', 'senior_ops')
    when (p_from::text, p_to::text) in (('submitted', 'returned'), ('submitted', 'locked'),
                                        ('locked', 'reopened'))
      then p_role in ('dispatcher', 'admin', 'senior_ops')
    when (p_from::text, p_to::text) in (('locked', 'reconciled'), ('reconciled', 'reopened'),
                                        ('reconciled', 'archived'))
      then p_role in ('admin', 'senior_ops')
    else false
  end, false)
$$;

-- ---------------------------------------------------------------------------
-- Shift: insert and update rules
-- ---------------------------------------------------------------------------

create function public.shift_before_insert() returns trigger
language plpgsql as $$
begin
  if not public.is_system() then
    if not public.is_staff() then
      raise exception 'not_allowed: only dispatch creates shifts';
    end if;
    if new.status <> 'open' then
      raise exception 'invalid_transition: new shifts start as open';
    end if;
  end if;
  return new;
end $$;

create trigger shift_a_before_insert
  before insert on public.shift
  for each row execute function public.shift_before_insert();

create function public.shift_before_update() returns trigger
language plpgsql as $$
declare
  v_role public.app_role := public.current_app_role();
  v_system boolean := public.is_system();
begin
  if not v_system then
    if v_role is null then
      raise exception 'not_allowed';
    end if;

    -- No edits while frozen; only a permitted status change can leave these states.
    if new.status = old.status then
      if old.status in ('locked', 'reconciled', 'archived') then
        raise exception 'shift_locked: reopen the shift before editing';
      end if;
      if v_role = 'ttm' and not public.crew_can_edit(old.status) then
        raise exception 'shift_not_editable: shift is waiting for dispatcher review';
      end if;
    end if;

    if v_role = 'ttm' and (
         new.truck_id is distinct from old.truck_id
      or new.phone_id is distinct from old.phone_id
      or new.shift_date is distinct from old.shift_date
      or new.dispatcher_id is distinct from old.dispatcher_id
      or new.hours_type_confirmed_at is distinct from old.hours_type_confirmed_at
      or new.return_reason is distinct from old.return_reason
      or new.reopen_reason is distinct from old.reopen_reason) then
      raise exception 'not_allowed: crew cannot change assignment or dispatcher fields';
    end if;

    if new.status is distinct from old.status
       and not public.transition_allowed(old.status, new.status, v_role) then
      raise exception 'invalid_transition: % -> % is not allowed for %', old.status, new.status, v_role;
    end if;
  end if;

  -- Hours type: crew selects, dispatcher confirms. A crew change clears the confirmation.
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
        new.truck_phone_confirmed_at := coalesce(new.truck_phone_confirmed_at, now());
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
      else
        null;
    end case;
  end if;

  return new;
end $$;

create trigger shift_a_before_update
  before update on public.shift
  for each row execute function public.shift_before_update();

-- Freeze values that must not change after acceptance.
create function public.snapshot_shift_on_lock(p_shift_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_date date;
begin
  select shift_date into v_date from public.shift where shift_id = p_shift_id;

  update public.shift_crew_member m
     set rank_id_snapshot = public.rank_on(m.employee_id, v_date)
   where m.shift_id = p_shift_id;

  update public.cash_submission c
     set expected_cash_snapshot = t.expected_cash
    from public.v_shift_totals t
   where c.shift_id = p_shift_id and t.shift_id = p_shift_id;
end $$;

-- Validation runs after the row is written, so it sees the values sent with the status change.
-- SECURITY DEFINER so it can call the (non-public) lock snapshot.
create function public.shift_after_status_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_errors text;
begin
  if new.status in ('submitted', 'locked') then
    select string_agg(distinct p.code, ', ' order by p.code) into v_errors
    from public.shift_problems(new.shift_id, case when new.status = 'locked' then 'lock' else 'submit' end) p
    where p.severity = 'error';
    if v_errors is not null then
      raise exception 'shift_not_ready: %', v_errors;
    end if;
  end if;

  if new.status = 'locked' then
    perform public.snapshot_shift_on_lock(new.shift_id);
  end if;
  return null;
end $$;

create trigger shift_b_after_status_change
  after update of status on public.shift
  for each row when (old.status is distinct from new.status)
  execute function public.shift_after_status_change();

-- ---------------------------------------------------------------------------
-- Child records: editable only while the shift is, and only by the right role
-- ---------------------------------------------------------------------------

create function public.assert_shift_editable(p_shift_id uuid) returns void
language plpgsql as $$
declare
  v_status public.shift_status;
  v_role public.app_role := public.current_app_role();
begin
  if v_role is null then
    raise exception 'not_allowed';
  end if;
  select status into v_status from public.shift where shift_id = p_shift_id;
  if v_status in ('locked', 'reconciled', 'archived') then
    raise exception 'shift_locked: reopen the shift before editing';
  end if;
  if v_role = 'ttm' and not public.crew_can_edit(v_status) then
    raise exception 'shift_not_editable: shift is waiting for dispatcher review';
  end if;
end $$;

create function public.guard_shift_child() returns trigger
language plpgsql as $$
declare
  v_old_shift uuid;
  v_new_shift uuid;
begin
  if public.is_system() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_table_name = 'disposal_material_txn' then
    if tg_op <> 'INSERT' then
      select shift_id into v_old_shift from public.disposal_visit where disposal_visit_id = old.disposal_visit_id;
    end if;
    if tg_op <> 'DELETE' then
      select shift_id into v_new_shift from public.disposal_visit where disposal_visit_id = new.disposal_visit_id;
    end if;
  else
    if tg_op <> 'INSERT' then v_old_shift := old.shift_id; end if;
    if tg_op <> 'DELETE' then v_new_shift := new.shift_id; end if;
  end if;

  if tg_op = 'UPDATE' and v_old_shift is distinct from v_new_shift then
    raise exception 'not_allowed: records cannot move to another shift';
  end if;

  perform public.assert_shift_editable(coalesce(v_new_shift, v_old_shift));

  if tg_table_name in ('shift_crew_member', 'shift_checklist_check')
     and public.current_app_role() = 'ttm' then
    raise exception 'not_allowed: only dispatch can change %', tg_table_name;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'shift_crew_member', 'job', 'disposal_visit', 'disposal_material_txn',
    'cash_submission', 'photo', 'shift_checklist_check'
  ] loop
    execute format(
      'create trigger %I before insert or update or delete on public.%I
         for each row execute function public.guard_shift_child()',
      t || '_a_guard', t);
  end loop;
end $$;

-- Job: crew records outcomes; only dispatch finalizes a cancellation.
create function public.job_rules() returns trigger
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
       or new.cancellation_finalized_at is not null then
      raise exception 'not_allowed: only dispatch sets the cancellation reason';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

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

create trigger job_b_rules
  before insert or update or delete on public.job
  for each row execute function public.job_rules();

-- Cash: crew creates the record and photo; dispatch counts and verifies.
create function public.cash_rules() returns trigger
language plpgsql as $$
begin
  if not public.is_system() and public.current_app_role() = 'ttm' and tg_op <> 'DELETE' and (
       new.counted_cash is distinct from case when tg_op = 'UPDATE' then old.counted_cash end
    or new.envelope_id is distinct from case when tg_op = 'UPDATE' then old.envelope_id end
    or new.received_by is distinct from case when tg_op = 'UPDATE' then old.received_by end
    or new.storage_location is distinct from case when tg_op = 'UPDATE' then old.storage_location end
    or new.mismatch_resolution is distinct from case when tg_op = 'UPDATE' then old.mismatch_resolution end
    or new.verified_at is distinct from case when tg_op = 'UPDATE' then old.verified_at end
    or new.expected_cash_snapshot is distinct from case when tg_op = 'UPDATE' then old.expected_cash_snapshot end) then
    raise exception 'not_allowed: only dispatch records the cash count';
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

create trigger cash_submission_b_rules
  before insert or update or delete on public.cash_submission
  for each row execute function public.cash_rules();

create function public.checklist_rules() returns trigger
language plpgsql as $$
begin
  if new.checked and (tg_op = 'INSERT' or not old.checked) then
    new.checked_at := now();
    new.checked_by := auth.uid();
  elsif not new.checked then
    new.checked_at := null;
    new.checked_by := null;
  end if;
  return new;
end $$;

create trigger shift_checklist_check_b_rules
  before insert or update on public.shift_checklist_check
  for each row execute function public.checklist_rules();
