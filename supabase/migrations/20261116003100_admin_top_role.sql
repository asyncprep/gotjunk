-- Admin becomes the highest role, senior ops the one below it (client, Nov 16, 2026).
-- The two enum values swap names, so every login keeps exactly the access it had: today's
-- senior ops logins become admin (full rights), today's admins become senior ops (configuration
-- only when granted). Policies store the enum value itself and follow the rename; the functions
-- below compare against the names as text, so they are rewritten with the new names.

alter type public.app_role rename value 'admin' to 'admin_swap';
alter type public.app_role rename value 'senior_ops' to 'admin';
alter type public.app_role rename value 'admin_swap' to 'senior_ops';

create or replace function public.can_edit_config() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select role = 'admin' or (role = 'senior_ops' and can_edit_config)
       from public.app_user where user_id = auth.uid() and active),
    false)
$$;

create or replace function public.app_user_guard() returns trigger
language plpgsql as $$
declare v_role public.app_role := public.current_app_role();
begin
  -- Configuration rights only mean something for senior ops; cleared when the role changes away.
  if tg_op = 'UPDATE' and new.role is distinct from old.role and new.role <> 'senior_ops' then
    new.can_edit_config := false;
  end if;
  if public.is_system() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op <> 'INSERT' and old.user_id = auth.uid() then
    raise exception 'not_allowed: you cannot change your own access';
  end if;
  if v_role is distinct from 'admin' then
    if (tg_op <> 'DELETE' and new.role = 'admin') or (tg_op <> 'INSERT' and old.role = 'admin') then
      raise exception 'not_allowed: only an admin can grant or change admin access';
    end if;
    if tg_op <> 'DELETE' and new.can_edit_config
       and (tg_op = 'INSERT' or not old.can_edit_config) then
      raise exception 'not_allowed: only an admin can grant configuration rights';
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
