-- test: a truck can run two shifts the same day
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.ok((select create_shift(public.business_date(now()),
  (select truck_id from truck where unit_number = 'T-01'),
  (select phone_id from phone where label = 'P-01'),
  array['b0000000-0000-0000-0000-000000000004'::uuid]) is not null), 'second T-01 shift');
select tests.eq((select count(*) from shift s join truck t using (truck_id) where t.unit_number = 'T-01'),
                2::bigint, 'two shifts on T-01');

-- test: an employee can do an afternoon shift once the morning one is submitted
select tests.prepare_ready_shift();
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.ok((select create_shift(public.business_date(now()),
  (select truck_id from truck where unit_number = 'T-03'),
  (select phone_id from phone where label = 'P-03'),
  array['b0000000-0000-0000-0000-000000000001'::uuid]) is not null), 'afternoon shift');

-- test: dispatch cancels an open shift with a reason; crew cannot
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  update shift set status = 'archived', cancel_reason = 'x' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'not_allowed%');
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  update shift set status = 'archived' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'reason_required%');
update shift set status = 'archived', cancel_reason = 'Camion en panne' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select status::text from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 'archived', 'cancelled');

-- test: crew can only change their own shift fields
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set hours_type = 'regular_junk', start_time = now() - interval '2 hours'
where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.throws($q$
  update shift set locked_by = 'a0000000-0000-0000-0000-000000000001' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'not_allowed: crew cannot change locked_by');
select tests.throws($q$
  update shift set cancel_reason = 'x' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'not_allowed%');

-- test: crew cannot mark a job as reconciled
select tests.prepare_ready_shift();
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  update job set reconciliation_status = 'matched' where job_id = 'e0000000-0000-0000-0000-000000000001'
$q$, 'not_allowed%');

-- test: the phone's start and completion times are kept
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set hours_type = 'regular_junk', status = 'in_progress', start_time = timestamptz '2026-10-30 07:00-04'
where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select start_time from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                timestamptz '2026-10-30 07:00-04', 'start time from phone');
insert into job (job_id, shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax, completed_at)
values ('e0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000001', 'OPP-T', 'completed', 'card', 100, 114.98,
        timestamptz '2026-10-30 11:00-04');
select tests.eq((select completed_at from job where job_id = 'e0000000-0000-0000-0000-000000000005'),
                timestamptz '2026-10-30 11:00-04', 'completion time from phone');

-- test: a tip with nobody present is flagged and blocks acceptance
reset role;
update shift_crew_member set left_at = now() - interval '1 hour'
where shift_id = 'c0000000-0000-0000-0000-000000000001';
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax, tip_amount, completed_at)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-TIP', 'completed', 'card', 100, 114.98, 20, now());
select tests.eq((select severity from shift_problems('c0000000-0000-0000-0000-000000000001', 'lock') where code = 'tip_unassigned'),
                'error', 'tip_unassigned at lock');
select tests.eq((select severity from shift_problems('c0000000-0000-0000-0000-000000000001', 'submit') where code = 'tip_unassigned'),
                'warning', 'warning at submit');

-- test: crew cannot delete cash that dispatch counted
select tests.prepare_ready_shift();
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-C', 'completed', 'cash', 100, 114.98);
insert into cash_submission (cash_submission_id, shift_id, counted_cash)
values ('ca000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 114.98);
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  delete from cash_submission where cash_submission_id = 'ca000000-0000-0000-0000-000000000001'
$q$, 'not_allowed: dispatch already counted%');

-- test: photos must be stored in their shift's folder
select tests.prepare_ready_shift();
select tests.throws($q$
  insert into photo (shift_id, photo_kind, entity_type, entity_id, storage_path)
  values ('c0000000-0000-0000-0000-000000000001', 'disposal_ticket', 'disposal_visit',
          'd0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000002/x.jpg')
$q$, 'photo_shift_mismatch%');

-- test: only senior ops grants senior ops or config rights, and nobody edits their own access
reset role;
insert into auth.users (id) values ('a0000000-0000-0000-0000-000000000030'), ('a0000000-0000-0000-0000-000000000031');
insert into app_user (user_id, role, can_edit_config) values
  ('a0000000-0000-0000-0000-000000000030', 'senior_ops', true),
  ('a0000000-0000-0000-0000-000000000031', 'admin', false);
select tests.login('a0000000-0000-0000-0000-000000000031');
select tests.throws($q$
  update app_user set role = 'senior_ops' where user_id = 'a0000000-0000-0000-0000-000000000031'
$q$, 'not_allowed: you cannot change your own access');
select tests.throws($q$
  update app_user set can_edit_config = true where user_id = 'a0000000-0000-0000-0000-000000000010'
$q$, 'not_allowed: only senior ops can grant configuration rights');
select tests.throws($q$
  update app_user set role = 'senior_ops' where user_id = 'a0000000-0000-0000-0000-000000000010'
$q$, 'not_allowed: only senior ops%');
update app_user set active = false where user_id = 'a0000000-0000-0000-0000-000000000010';
select tests.login('a0000000-0000-0000-0000-000000000030');
update app_user set can_edit_config = true where user_id = 'a0000000-0000-0000-0000-000000000031';
reset role;
select tests.eq((select active from app_user where user_id = 'a0000000-0000-0000-0000-000000000010'), false, 'admin deactivates dispatcher');
select tests.eq((select can_edit_config from app_user where user_id = 'a0000000-0000-0000-0000-000000000031'), true, 'senior grants rights');

-- test: anonymous callers cannot run the readiness checks
set local role anon;
select tests.throws($q$ select * from public.shift_problems('c0000000-0000-0000-0000-000000000001') $q$, '%permission denied%');

-- test: setting a rank twice the same day replaces it
select tests.login('a0000000-0000-0000-0000-000000000020');
select set_employee_rank('b0000000-0000-0000-0000-000000000001', (select rank_id from rank where code = 'wingman'), date '2026-11-01');
select set_employee_rank('b0000000-0000-0000-0000-000000000001', (select rank_id from rank where code = 'sales_pro'), date '2026-11-01');
select tests.eq((select r.code from rank r where r.rank_id = rank_on('b0000000-0000-0000-0000-000000000001', date '2026-11-02')),
                'sales_pro', 'corrected rank');

-- test: a new rate closes the current one the day before, and credits never use a minimum
select tests.login('a0000000-0000-0000-0000-000000000020');
select add_site_rate((select site_id from site where code = 'eco_junk'), (select material_type_id from material_type where code = 'garbage'),
                     175, 'cost', 0, 'transaction', date '2026-12-01');
select tests.eq((select effective_to from site_rate_config c join material_type m using (material_type_id)
                 where m.code = 'garbage' and c.rate_per_ton = 150), date '2026-11-30', 'old rate closed');
select add_site_rate((select site_id from site where code = 'eco_junk'), (select material_type_id from material_type where code = 'donation'),
                     80, 'credit', 500, 'transaction', date '2026-12-01');
select tests.eq((select min_applies_to::text from site_rate_config c join material_type m using (material_type_id)
                 where m.code = 'donation' and c.rate_per_ton = 80), 'never', 'credit has no minimum');
