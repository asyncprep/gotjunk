-- A route can use several swing trucks in a day (client, Nov 6): the crew lead enters how many, and
-- COGS charges the fee for each one. shift.swing_truck stays for crew app builds that only know
-- yes/no; the trigger below keeps the two columns in step.

alter table public.shift
  add column swing_truck_count integer not null default 0 check (swing_truck_count between 0 and 20);
comment on column public.shift.swing_truck_count is 'Swing trucks used on this route (fee per truck in COGS)';

alter table public.shift disable trigger user;
update public.shift set swing_truck_count = 1 where swing_truck;
alter table public.shift enable trigger user;

create function public.shift_swing_truck_sync() returns trigger
language plpgsql as $$
begin
  if new.swing_truck_count is distinct from old.swing_truck_count then
    new.swing_truck := new.swing_truck_count > 0;
  elsif new.swing_truck is distinct from old.swing_truck then
    new.swing_truck_count := case when new.swing_truck then 1 else 0 end;
  end if;
  return new;
end $$;

create trigger shift_swing_truck_sync
  before update of swing_truck, swing_truck_count on public.shift
  for each row execute function public.shift_swing_truck_sync();

-- The crew lead may set the number of swing trucks, like the yes/no before it.
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
                       except select unnest(array['hours_type', 'start_time', 'finish_time', 'fuel_mode', 'swing_truck', 'swing_truck_count',
                                                  'training_day', 'training_hours_removed',
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
