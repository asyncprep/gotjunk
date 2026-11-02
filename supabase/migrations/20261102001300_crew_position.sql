-- Truck Team OS: each crew member on a route is the driver or a navigator (client, Nov 2).
-- Dispatch picks the position for every member when creating the route; a route has exactly
-- one driver. Dispatch can change positions later (e.g. the driver and navigator swap).

create type public.crew_position as enum ('driver', 'navigator');

-- The unused free-text role is replaced by the position.
alter table public.shift_crew_member drop column shift_role;
alter table public.shift_crew_member add column position public.crew_position;

-- Existing routes: the earliest crew member drives, the others navigate.
update public.shift_crew_member m
   set position = case when m.shift_crew_id = (
       select f.shift_crew_id from public.shift_crew_member f
       where f.shift_id = m.shift_id
       order by f.joined_at, f.created_at, f.shift_crew_id
       limit 1) then 'driver'::public.crew_position else 'navigator'::public.crew_position end;

alter table public.shift_crew_member alter column position set not null;

-- create_shift now takes a position for each crew member, in the same order as p_crew.
drop function public.create_shift(date, uuid, uuid, uuid[], uuid);

create function public.create_shift(
  p_shift_date date, p_truck_id uuid, p_phone_id uuid, p_crew uuid[],
  p_positions public.crew_position[], p_lead uuid default null
) returns uuid
language plpgsql as $$
declare v_shift_id uuid;
begin
  if coalesce(array_length(p_crew, 1), 0) = 0 then
    raise exception 'crew_size: pick at least one crew member';
  end if;
  if coalesce(array_length(p_positions, 1), 0) <> array_length(p_crew, 1)
     or array_position(p_positions, null) is not null then
    raise exception 'position_missing: pick driver or navigator for each crew member';
  end if;
  if (select count(*) from unnest(p_positions) p where p = 'driver') <> 1 then
    raise exception 'one_driver: a route needs exactly one driver';
  end if;
  if p_lead is not null and not p_lead = any (p_crew) then
    raise exception 'lead_not_crew: the lead must be on this shift''s crew';
  end if;

  insert into public.shift (shift_date, truck_id, phone_id, dispatcher_id)
  values (p_shift_date, p_truck_id, p_phone_id, auth.uid())
  returning shift_id into v_shift_id;

  insert into public.shift_crew_member (shift_id, employee_id, position)
  select v_shift_id, c.e, c.p from unnest(p_crew, p_positions) as c(e, p);

  update public.shift set lead_employee_id = coalesce(p_lead, p_crew[1]) where shift_id = v_shift_id;

  return v_shift_id;
end $$;

revoke execute on function public.create_shift(date, uuid, uuid, uuid[], public.crew_position[], uuid) from public, anon;
grant execute on function public.create_shift(date, uuid, uuid, uuid[], public.crew_position[], uuid) to authenticated, service_role;

-- Projet page: record the decision.
insert into public.spec_item (kind, ref, area, priority, title, blocks, build_default, status, answer, sort_order)
values ('question', 'S11', 'Crew', 'pilot',
  $s$Does each crew member on a route have a position?$s$,
  $s$Route creation, crew list$s$,
  $s$Each member is the driver or a navigator; exactly one driver per route$s$,
  'answered',
  $s$Yes. When creating a route, dispatch picks the members and, for each one, the position: driver or navigator.$s$,
  106)
on conflict (ref) do nothing;
