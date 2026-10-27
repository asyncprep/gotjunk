-- Truck Team OS: photo storage and offline sync plumbing
-- Both blocks are skipped where the Supabase storage schema or logical replication isn't present
-- (e.g. the local PGlite test harness).

-- Private bucket; objects live at {shift_id}/{photo_id}.jpg
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public) values ('photos', 'photos', false)
    on conflict (id) do nothing;

    execute $p$
      create policy photos_read on storage.objects for select to authenticated using (
        bucket_id = 'photos'
        and (public.is_staff() or public.is_crew_member(((storage.foldername(name))[1])::uuid)))
    $p$;
    execute $p$
      create policy photos_insert on storage.objects for insert to authenticated with check (
        bucket_id = 'photos'
        and (public.is_staff() or public.is_crew_member(((storage.foldername(name))[1])::uuid)))
    $p$;
  end if;
end $$;

-- PowerSync replicates from this publication. Sync rules are defined in the PowerSync dashboard.
do $$
begin
  create publication powersync for table
    public.shift, public.shift_crew_member, public.job, public.disposal_visit,
    public.disposal_material_txn, public.cash_submission, public.photo, public.shift_checklist_check,
    public.employee, public.app_user, public.truck, public.phone, public.site, public.material_type,
    public.payment_method, public.cancellation_reason, public.site_rate_config, public.checklist_item,
    public.app_setting, public.rank;
exception
  when duplicate_object then null;
  when feature_not_supported or insufficient_privilege then
    raise notice 'publication powersync not created: %', sqlerrm;
end $$;
