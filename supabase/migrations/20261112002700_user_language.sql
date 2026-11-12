-- Each person's language (fr / en), so the crew app and the admin open in it on any phone or
-- computer they sign in on. Null = not chosen yet (the app keeps the device's choice).

alter table public.app_user add column language text check (language in ('fr', 'en'));

-- Anyone signed in sets their own language; nothing else on their access changes.
-- (The app_user guard refuses changes to your own row from the apps; this runs as system.)
create function public.set_my_language(p_language text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_language not in ('fr', 'en') then
    raise exception 'not_allowed: language must be fr or en';
  end if;
  update public.app_user set language = p_language, updated_at = now(), updated_by = auth.uid()
   where user_id = auth.uid();
end $$;

revoke execute on function public.set_my_language(text) from public, anon;
grant execute on function public.set_my_language(text) to authenticated;
