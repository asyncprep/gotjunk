-- Truck Team OS: clearer refusal when a user edits records of a shift they can't see.
-- Previously a crew member writing to another crew's shift got "shift_not_editable"
-- (the shift was invisible to them under RLS, so its status read as NULL).

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
end $$;
