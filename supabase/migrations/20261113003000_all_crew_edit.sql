-- Every crew member on a route can enter it from the app, not only the crew lead (client, Nov 13, 2026).
-- The lead stays: dispatch still picks one, it is shown with a star and goes on the envelope label.
-- A crew member who has left the route can no longer change it.

create or replace function public.is_current_crew(p_shift_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.shift_crew_member
    where shift_id = p_shift_id and employee_id = public.current_employee_id()
      and (left_at is null or left_at > now()))
$$;

revoke execute on function public.is_current_crew(uuid) from public, anon;
grant execute on function public.is_current_crew(uuid) to authenticated, service_role;

create or replace function public.shift_lead_rules() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and not public.is_system() and public.current_app_role() = 'ttm' then
    if not public.is_current_crew(new.shift_id) then
      raise exception 'not_crew: only someone on this route''s crew can change it';
    end if;
    if old.lead_employee_id is null or exists (
         select 1 from public.shift_crew_member m
         where m.shift_id = new.shift_id and m.employee_id = old.lead_employee_id
           and m.left_at is not null and m.left_at <= now()) then
      -- No lead, or the lead has left: the crew member who changes the route becomes lead.
      new.lead_employee_id := public.current_employee_id();
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

-- Records of a shift (jobs, disposal, cash, photos): any current crew member writes them.
create or replace function public.assert_shift_editable(p_shift_id uuid) returns void
language plpgsql as $$
declare
  v_status public.shift_status;
  v_role public.app_role := public.current_app_role();
begin
  if v_role is null then
    raise exception 'not_allowed';
  end if;
  select status into v_status from public.shift where shift_id = p_shift_id;
  if not found then
    raise exception 'not_allowed: shift not found or not yours';
  end if;
  if v_status in ('locked', 'reconciled', 'archived') then
    raise exception 'shift_locked: reopen the shift before editing';
  end if;
  if v_role = 'ttm' and not public.crew_can_edit(v_status) then
    raise exception 'shift_not_editable: shift is waiting for dispatcher review';
  end if;
  if v_role = 'ttm' and not public.is_current_crew(p_shift_id) then
    raise exception 'not_crew: only someone on this route''s crew can change it';
  end if;
end $$;

-- Projet page: record the change to S10.
update public.spec_item
   set build_default = $s$Every crew member on the route can enter it from the app$s$,
       answer = $s$The crew lead signs in on the truck phone, and since Nov 13, 2026 every crew member on the route can also enter it from the app (jobs, disposal, cash). Dispatch still picks the lead, shown with a star and on the envelope label. If the lead leaves, the next crew member who changes the route becomes lead.$s$
 where ref = 'S10';
