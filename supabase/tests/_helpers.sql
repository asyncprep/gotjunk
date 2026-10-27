-- Assertion helpers for the SQL test cases.
create schema tests;
grant usage on schema tests to authenticated;

-- Act as a signed-in app user for the rest of the transaction. Use `reset role;` to go back to system.
create function tests.login(p_user uuid) returns void
language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
end $$;

create function tests.eq(p_actual anyelement, p_expected anyelement, p_label text) returns void
language plpgsql as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'ASSERT %: expected %, got %', p_label, p_expected, p_actual;
  end if;
end $$;

create function tests.ok(p_cond boolean, p_label text) returns void
language plpgsql as $$
begin
  if p_cond is not true then
    raise exception 'ASSERT %: condition was not true', p_label;
  end if;
end $$;

-- The statement must fail with a message matching the ILIKE pattern.
create function tests.throws(p_sql text, p_pattern text) returns void
language plpgsql as $$
declare
  v_failed boolean := false;
  v_msg text;
begin
  begin
    execute p_sql;
  exception when others then
    v_failed := true;
    v_msg := sqlerrm;
  end;
  if not v_failed then
    raise exception 'ASSERT expected error like "%" but statement succeeded: %', p_pattern, p_sql;
  end if;
  if v_msg not ilike p_pattern then
    raise exception 'ASSERT expected error like "%" but got "%"', p_pattern, v_msg;
  end if;
end $$;

grant execute on all functions in schema tests to authenticated;

-- Fills shift S1 so it passes the submit checks: hours, start/finish, one card job,
-- one Eco-Junk visit with ticket, photo and a garbage line. Runs as system.
create function tests.prepare_ready_shift() returns void
language plpgsql as $$
begin
  update public.shift
     set hours_type = 'regular_junk', status = 'in_progress',
         start_time = now() - interval '8 hours', finish_time = now()
   where shift_id = 'c0000000-0000-0000-0000-000000000001';

  insert into public.job (job_id, shift_id, opportunity_id, outcome, payment_method_code,
                          revenue_pre_tax, revenue_total_incl_tax, tip_amount)
  values ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
          'OPP-1001', 'completed', 'card', 200.00, 229.95, 20.00);

  insert into public.disposal_visit (disposal_visit_id, shift_id, site_id, ticket_number)
  select 'd0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', site_id, 'EJ-500'
  from public.site where code = 'eco_junk';

  insert into public.disposal_material_txn (disposal_visit_id, material_type_id, weight_kg)
  select 'd0000000-0000-0000-0000-000000000001', material_type_id, 300
  from public.material_type where code = 'garbage';

  insert into public.photo (shift_id, photo_kind, entity_type, entity_id, storage_path)
  values ('c0000000-0000-0000-0000-000000000001', 'disposal_ticket', 'disposal_visit',
          'd0000000-0000-0000-0000-000000000001',
          'c0000000-0000-0000-0000-000000000001/ticket-1.jpg');
end $$;
