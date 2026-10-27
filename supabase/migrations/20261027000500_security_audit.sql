-- Truck Team OS: audit trail, row-level security and grants

-- ---------------------------------------------------------------------------
-- Audit log (append-only; written only by trigger)
-- ---------------------------------------------------------------------------

create table public.audit_log (
  audit_id bigint generated always as identity primary key,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  field_changes jsonb,
  actor_id uuid,
  actor_role text,
  occurred_at timestamptz not null default now(),
  client_recorded_at timestamptz,
  reason text
);

create index on public.audit_log (entity_type, entity_id, occurred_at);

create function public.write_audit_log() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_pk text := tg_argv[0];
  v_old jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  v_new jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  v_changes jsonb;
  v_action text := lower(tg_op);
  v_reason text;
begin
  if tg_op = 'UPDATE' then
    select jsonb_object_agg(k, jsonb_build_object('old', v_old -> k, 'new', v_new -> k))
      into v_changes
    from jsonb_object_keys(v_new) k
    where k not in ('updated_at', 'updated_by')
      and (v_old -> k) is distinct from (v_new -> k);
    if v_changes is null then
      return null;  -- nothing material changed
    end if;
    if tg_table_name = 'shift' and v_changes ? 'status' then
      v_action := 'status:' || (v_new ->> 'status');
      v_reason := case v_new ->> 'status'
                    when 'returned' then v_new ->> 'return_reason'
                    when 'reopened' then v_new ->> 'reopen_reason' end;
    end if;
  elsif tg_op = 'INSERT' then
    v_changes := v_new;
  else
    v_changes := v_old;
  end if;

  insert into public.audit_log (entity_type, entity_id, action, field_changes, actor_id, actor_role, reason)
  values (tg_table_name,
          coalesce(v_new, v_old) ->> v_pk,
          v_action,
          v_changes,
          auth.uid(),
          coalesce(public.current_app_role()::text, 'system'),
          v_reason);
  return null;
end $$;

do $$
declare
  t record;
begin
  for t in
    select * from (values
      ('shift', 'shift_id'), ('shift_crew_member', 'shift_crew_id'), ('job', 'job_id'),
      ('disposal_visit', 'disposal_visit_id'), ('disposal_material_txn', 'material_txn_id'),
      ('cash_submission', 'cash_submission_id'), ('photo', 'photo_id'),
      ('shift_checklist_check', 'shift_id'),
      ('employee', 'employee_id'), ('employee_rank_history', 'rank_history_id'),
      ('app_user', 'user_id'), ('site_rate_config', 'rate_config_id'),
      ('app_setting', 'key'), ('truck', 'truck_id'), ('phone', 'phone_id'), ('site', 'site_id'),
      ('material_type', 'material_type_id'), ('payment_method', 'code'),
      ('cancellation_reason', 'reason_id'), ('checklist_item', 'item_id'), ('rank', 'rank_id')
    ) as v(tbl, pk)
  loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
         for each row execute function public.write_audit_log(%L)',
      t.tbl || '_z_audit', t.tbl, t.pk);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'app_setting', 'employee', 'rank', 'employee_rank_history', 'app_user', 'truck', 'phone', 'site',
    'material_type', 'payment_method', 'cancellation_reason', 'site_rate_config', 'checklist_item',
    'shift', 'shift_crew_member', 'job', 'disposal_visit', 'disposal_material_txn',
    'cash_submission', 'photo', 'shift_checklist_check', 'audit_log'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Reference data: everyone signed in reads; config editors write.
do $$
declare t text;
begin
  foreach t in array array[
    'app_setting', 'rank', 'truck', 'phone', 'site', 'material_type', 'payment_method',
    'cancellation_reason', 'site_rate_config', 'checklist_item'
  ] loop
    execute format('create policy read_all on public.%I for select to authenticated using (true)', t);
    execute format(
      'create policy config_write on public.%I for all to authenticated
         using (public.can_edit_config()) with check (public.can_edit_config())', t);
  end loop;
end $$;

-- Roster: staff see everyone; crew see themselves and the people on their shifts.
create policy employee_read on public.employee for select to authenticated using (
  public.is_staff()
  or employee_id = public.current_employee_id()
  or exists (select 1 from public.shift_crew_member m
             where m.employee_id = employee.employee_id and public.is_crew_member(m.shift_id)));
create policy employee_write on public.employee for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy rank_history_read on public.employee_rank_history for select to authenticated
  using (public.is_staff() or employee_id = public.current_employee_id());
create policy rank_history_write on public.employee_rank_history for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy app_user_read on public.app_user for select to authenticated
  using (user_id = auth.uid() or public.is_staff());
create policy app_user_write on public.app_user for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Shifts: staff see all; crew see the shifts they are on. Only staff create them.
create policy shift_read on public.shift for select to authenticated
  using (public.is_staff() or public.is_crew_member(shift_id));
create policy shift_insert on public.shift for insert to authenticated
  with check (public.is_staff());
create policy shift_update on public.shift for update to authenticated
  using (public.is_staff() or public.is_crew_member(shift_id))
  with check (public.is_staff() or public.is_crew_member(shift_id));

create policy crew_read on public.shift_crew_member for select to authenticated
  using (public.is_staff() or public.is_crew_member(shift_id));
create policy crew_write on public.shift_crew_member for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- Shift children: staff or crew of the shift. Triggers decide what each role may change.
do $$
declare t text;
begin
  foreach t in array array['job', 'disposal_visit', 'cash_submission', 'photo'] loop
    execute format(
      'create policy shift_member_all on public.%I for all to authenticated
         using (public.is_staff() or public.is_crew_member(shift_id))
         with check (public.is_staff() or public.is_crew_member(shift_id))', t);
  end loop;
end $$;

create policy shift_member_all on public.disposal_material_txn for all to authenticated
  using (exists (select 1 from public.disposal_visit v
                 where v.disposal_visit_id = disposal_material_txn.disposal_visit_id
                   and (public.is_staff() or public.is_crew_member(v.shift_id))))
  with check (exists (select 1 from public.disposal_visit v
                      where v.disposal_visit_id = disposal_material_txn.disposal_visit_id
                        and (public.is_staff() or public.is_crew_member(v.shift_id))));

create policy checklist_read on public.shift_checklist_check for select to authenticated
  using (public.is_staff() or public.is_crew_member(shift_id));
create policy checklist_write on public.shift_checklist_check for all to authenticated
  using (public.is_staff()) with check (public.is_staff());

create policy audit_read on public.audit_log for select to authenticated
  using (public.is_staff());

-- ---------------------------------------------------------------------------
-- Grants (RLS still applies). anon gets nothing.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke insert, update, delete on public.audit_log from authenticated;
grant select on public.v_shift_totals, public.v_tip_split, public.v_shift_tips_by_employee to authenticated;

revoke execute on function public.snapshot_shift_on_lock(uuid) from public, anon, authenticated;
revoke execute on function public.write_audit_log() from public, anon, authenticated;
