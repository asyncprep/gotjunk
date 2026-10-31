-- Truck Team OS: one shared phone per truck, signed in by the crew lead (client decision, Oct 31).
-- Each shift has a lead. Only the lead's login writes from the phone; the rest of the crew
-- needs no login. Dispatch picks the lead and can change it. If the lead leaves the shift
-- (or none was picked), the crew member who next uses the phone takes over.

alter table public.shift add column lead_employee_id uuid references public.employee;

-- Existing shifts: the earliest crew member with a login, otherwise the earliest crew member.
update public.shift s
   set lead_employee_id = (
     select m.employee_id
     from public.shift_crew_member m
     left join public.app_user u on u.employee_id = m.employee_id and u.active
     where m.shift_id = s.shift_id and m.left_at is null
     order by (u.user_id is null), m.joined_at, m.created_at
     limit 1)
 where s.status <> 'archived';

create function public.is_shift_lead(p_shift_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.shift
    where shift_id = p_shift_id and lead_employee_id = public.current_employee_id())
$$;

-- Runs after shift_a_before_update, so the crew's column whitelist has already been checked.
create function public.shift_lead_rules() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and not public.is_system() and public.current_app_role() = 'ttm' then
    if old.lead_employee_id is null or exists (
         select 1 from public.shift_crew_member m
         where m.shift_id = new.shift_id and m.employee_id = old.lead_employee_id
           and m.left_at is not null and m.left_at <= now()) then
      -- No lead, or the lead has left: whoever is signed in on the phone takes over.
      new.lead_employee_id := public.current_employee_id();
    elsif old.lead_employee_id is distinct from public.current_employee_id() then
      raise exception 'not_lead: only the crew lead signed in on the truck phone can change this shift';
    end if;
  end if;

  if new.lead_employee_id is not null
     and (tg_op = 'INSERT' or new.lead_employee_id is distinct from old.lead_employee_id)
     and not exists (
       select 1 from public.shift_crew_member m
       where m.shift_id = new.shift_id and m.employee_id = new.lead_employee_id
         and (m.left_at is null or m.left_at > now())) then
    raise exception 'lead_not_crew: the lead must be on this shift''s crew';
  end if;
  return new;
end $$;

create trigger shift_b_lead
  before insert or update on public.shift
  for each row execute function public.shift_lead_rules();

-- Records of a shift (jobs, disposal, cash, photos): crew writes only through the lead's login.
create or replace function public.assert_shift_editable(p_shift_id uuid) returns void
language plpgsql as $$
declare
  v_status public.shift_status;
  v_lead uuid;
  v_role public.app_role := public.current_app_role();
begin
  if v_role is null then
    raise exception 'not_allowed';
  end if;
  select status, lead_employee_id into v_status, v_lead from public.shift where shift_id = p_shift_id;
  if not found then
    raise exception 'not_allowed: shift not found or not yours';
  end if;
  if v_status in ('locked', 'reconciled', 'archived') then
    raise exception 'shift_locked: reopen the shift before editing';
  end if;
  if v_role = 'ttm' and not public.crew_can_edit(v_status) then
    raise exception 'shift_not_editable: shift is waiting for dispatcher review';
  end if;
  if v_role = 'ttm' and v_lead is distinct from public.current_employee_id() then
    raise exception 'not_lead: only the crew lead signed in on the truck phone can change this shift';
  end if;
end $$;

-- Removing the lead from the crew leaves the shift without a lead (the next phone user takes over).
create function public.clear_lead_on_crew_delete() returns trigger
language plpgsql as $$
begin
  update public.shift set lead_employee_id = null
   where shift_id = old.shift_id and lead_employee_id = old.employee_id;
  return old;
end $$;

create trigger shift_crew_member_clear_lead
  before delete on public.shift_crew_member
  for each row execute function public.clear_lead_on_crew_delete();

-- create_shift now takes the lead (defaults to the first crew member picked).
drop function public.create_shift(date, uuid, uuid, uuid[]);

create function public.create_shift(
  p_shift_date date, p_truck_id uuid, p_phone_id uuid, p_crew uuid[], p_lead uuid default null
) returns uuid
language plpgsql as $$
declare v_shift_id uuid;
begin
  if coalesce(array_length(p_crew, 1), 0) = 0 then
    raise exception 'crew_size: pick at least one crew member';
  end if;
  if p_lead is not null and not p_lead = any (p_crew) then
    raise exception 'lead_not_crew: the lead must be on this shift''s crew';
  end if;

  insert into public.shift (shift_date, truck_id, phone_id, dispatcher_id)
  values (p_shift_date, p_truck_id, p_phone_id, auth.uid())
  returning shift_id into v_shift_id;

  insert into public.shift_crew_member (shift_id, employee_id)
  select v_shift_id, e from unnest(p_crew) as e;

  update public.shift set lead_employee_id = coalesce(p_lead, p_crew[1]) where shift_id = v_shift_id;

  return v_shift_id;
end $$;

revoke execute on function public.create_shift(date, uuid, uuid, uuid[], uuid) from public, anon;
grant execute on function public.create_shift(date, uuid, uuid, uuid[], uuid) to authenticated, service_role;
revoke execute on function public.is_shift_lead(uuid) from public, anon;
grant execute on function public.is_shift_lead(uuid) to authenticated, service_role;

-- Projet page: record the decision.
insert into public.spec_item (kind, ref, area, priority, title, blocks, build_default, status, answer, sort_order)
values ('question', 'S10', 'Devices', 'blocker',
  $s$Each truck has one shared phone. How does the crew sign in on it?$s$,
  $s$Crew app sign-in, tip display, access rules$s$,
  $s$The crew lead signs in; only the lead's login writes from the phone$s$,
  'answered',
  $s$The crew lead signs in on the truck phone; the rest of the crew has no login. Dispatch picks the lead when creating the shift and can change it. If the lead leaves the shift, the next crew member who signs in on the phone takes over.$s$,
  105)
on conflict (ref) do nothing;
