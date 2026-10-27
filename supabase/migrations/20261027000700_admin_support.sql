-- Truck Team OS: support for the dispatch/admin web app

-- Show who each login is without reading auth.users from the browser.
alter table public.app_user add column email text;
create unique index app_user_email_uq on public.app_user (lower(email)) where email is not null;

-- Create a shift and its crew in one transaction. SECURITY INVOKER: RLS and triggers apply.
create function public.create_shift(
  p_shift_date date, p_truck_id uuid, p_phone_id uuid, p_crew uuid[]
) returns uuid
language plpgsql as $$
declare v_shift_id uuid;
begin
  if coalesce(array_length(p_crew, 1), 0) = 0 then
    raise exception 'crew_size: pick at least one crew member';
  end if;

  insert into public.shift (shift_date, truck_id, phone_id, dispatcher_id)
  values (p_shift_date, p_truck_id, p_phone_id, auth.uid())
  returning shift_id into v_shift_id;

  insert into public.shift_crew_member (shift_id, employee_id)
  select v_shift_id, e from unnest(p_crew) as e;

  return v_shift_id;
end $$;

-- Change an employee's rank from a date: closes the current rank the day before. SECURITY INVOKER.
create function public.set_employee_rank(
  p_employee_id uuid, p_rank_id uuid, p_effective_from date, p_reason text default null
) returns void
language plpgsql as $$
begin
  if not (public.is_system() or public.is_admin()) then
    raise exception 'not_allowed: only administration changes ranks';
  end if;

  update public.employee_rank_history
     set effective_to = p_effective_from - 1
   where employee_id = p_employee_id
     and effective_from < p_effective_from
     and (effective_to is null or effective_to >= p_effective_from);

  insert into public.employee_rank_history (employee_id, rank_id, effective_from, change_reason)
  values (p_employee_id, p_rank_id, p_effective_from, p_reason);
end $$;

-- Current rank per employee, for the team screen.
create view public.v_employee_current_rank with (security_invoker = true) as
select e.employee_id, h.rank_id, h.effective_from
from public.employee e
left join public.employee_rank_history h
  on h.employee_id = e.employee_id
 and public.business_date(now()) between h.effective_from and coalesce(h.effective_to, 'infinity'::date);

grant select on public.v_employee_current_rank to authenticated;
