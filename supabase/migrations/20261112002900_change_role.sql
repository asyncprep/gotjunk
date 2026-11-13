-- Admins change the role of other logins from Team → Users (Nov 12, 2026).
-- The guard already allows it (not your own login; only senior ops gives or takes senior ops).
-- New: configuration rights only mean something for an admin, so they are cleared when the
-- role changes to anything else. Otherwise they would come back if the person were made admin again.

create or replace function public.app_user_guard() returns trigger
language plpgsql as $$
declare v_role public.app_role := public.current_app_role();
begin
  if tg_op = 'UPDATE' and new.role is distinct from old.role and new.role <> 'admin' then
    new.can_edit_config := false;
  end if;
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
