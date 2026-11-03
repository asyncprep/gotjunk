-- Truck Team OS: live profit share (the bottom of the paper route sheet, Aug 2024 version).
-- The crew app calculates it during the day from the plan below; see docs/profit-share.md.
-- Values are the sheet's defaults until the client confirms them (A10, A11, A13).

-- The plan: every amount and threshold on the sheet, editable on the Configuration page.
insert into public.app_setting (key, value, description) values
  ('profit_share_plan', $j${
    "wage_per_hour": 26,
    "franchise_pct": 16,
    "fuel_pct": {"one_truck": 4, "split_day": 5.5, "two_trucks": 7},
    "swing_truck_fee": 60,
    "min_revenue": 2000,
    "min_revenue_per_hour": 135,
    "small_team_hours": 18,
    "small_team_min_revenue": 1500,
    "training_min_revenue": 1500,
    "training_min_revenue_per_hour": 125,
    "training_hours_max": 3,
    "training_hours_off_revenue_per_hour": false,
    "low_cogs_max_pct": 43,
    "mid_cogs_max_pct": 47,
    "max_cogs_pct": 50,
    "hours_types": ["regular_junk"]
  }$j$, 'Profit-share plan (sheet of Aug 2024): wages, fees, fuel, minimums and COGS bands')
on conflict (key) do nothing;

-- % of the route's revenue per rank and COGS band. No % (Recruit, A12) = no profit share.
alter table public.rank
  add column share_pct_low_cogs numeric(5,2) check (share_pct_low_cogs between 0 and 100),
  add column share_pct_mid_cogs numeric(5,2) check (share_pct_mid_cogs between 0 and 100),
  add column share_pct_high_cogs numeric(5,2) check (share_pct_high_cogs between 0 and 100);
comment on column public.rank.share_pct_low_cogs is 'Profit share % when COGS is at or under the low band (sheet: under 43%)';
comment on column public.rank.share_pct_mid_cogs is 'Profit share % in the middle band (sheet: 43.01–47%)';
comment on column public.rank.share_pct_high_cogs is 'Profit share % in the high band (sheet: 47.01–50%)';

update public.rank set share_pct_high_cogs = 1, share_pct_mid_cogs = 2, share_pct_low_cogs = 3 where code = 'wingman';
update public.rank set share_pct_high_cogs = 2, share_pct_mid_cogs = 3, share_pct_low_cogs = 4 where code in ('sales_pro', 'professional');
update public.rank set share_pct_high_cogs = 3, share_pct_mid_cogs = 4, share_pct_low_cogs = 5 where code in ('expert', 'jr_coach');

-- What the sheet asks about the route that the app didn't record yet.
alter table public.shift
  add column fuel_mode text not null default 'one_truck' check (fuel_mode in ('one_truck', 'split_day', 'two_trucks')),
  add column swing_truck boolean not null default false,
  add column training_day boolean not null default false,
  add column training_hours_removed numeric(4,2) not null default 0 check (training_hours_removed between 0 and 8),
  add column damages boolean not null default false;
comment on column public.shift.fuel_mode is 'Fuel % on the sheet: one truck, split day, or 2 trucks';
comment on column public.shift.swing_truck is 'A swing truck was used (flat fee in COGS)';
comment on column public.shift.training_day is 'A trainer was on the route: lower minimums, hours can be removed';
comment on column public.shift.damages is 'Damages on the route: no profit share (set by dispatch)';

-- The crew lead may set fuel, swing truck and training; damages stay with dispatch.
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
                       except select unnest(array['hours_type', 'start_time', 'finish_time', 'fuel_mode', 'swing_truck',
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

-- The phone needs each crew member's rank before the route is accepted: keep the snapshot
-- current until lock (acceptance freezes it, as before).
create function public.crew_rank_on_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.rank_id_snapshot is null then
    new.rank_id_snapshot := public.rank_on(new.employee_id,
      (select shift_date from public.shift where shift_id = new.shift_id));
  end if;
  return new;
end $$;

create trigger shift_crew_member_rank
  before insert on public.shift_crew_member
  for each row execute function public.crew_rank_on_insert();

create function public.refresh_crew_rank() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_employee uuid := coalesce(new.employee_id, old.employee_id);
begin
  update public.shift_crew_member m
     set rank_id_snapshot = public.rank_on(m.employee_id, s.shift_date)
    from public.shift s
   where s.shift_id = m.shift_id and m.employee_id = v_employee
     and s.status in ('open', 'in_progress', 'submitted', 'returned', 'reopened')
     and m.rank_id_snapshot is distinct from public.rank_on(m.employee_id, s.shift_date);
  return null;
end $$;

create trigger employee_rank_history_refresh_crew
  after insert or update or delete on public.employee_rank_history
  for each row execute function public.refresh_crew_rank();

update public.shift_crew_member m
   set rank_id_snapshot = public.rank_on(m.employee_id, s.shift_date)
  from public.shift s
 where s.shift_id = m.shift_id and s.status in ('open', 'in_progress', 'submitted', 'returned', 'reopened');
