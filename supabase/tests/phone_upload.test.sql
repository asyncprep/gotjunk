-- The crew app uploads through PostgREST: new rows as upserts (INSERT … ON CONFLICT DO UPDATE)
-- carrying only the fields the phone wrote, edits as plain updates. These cases send exactly
-- those payloads as a signed-in crew member.

-- test: phone upserts of a job, visit, weigh-in, cash record and photo are accepted
reset role;
update shift set hours_type = 'regular_junk', status = 'in_progress', start_time = now() - interval '6 hours'
where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000001');

insert into job (job_id, shift_id, opportunity_id, outcome, payment_method_code, discount_amount,
                 revenue_pre_tax, revenue_total_incl_tax, tip_amount, created_at)
values ('01900000-0000-7000-8000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'OPP-P1', 'completed',
        'cash', 0, 100, 114.98, 10, now())
on conflict (job_id) do update set opportunity_id = excluded.opportunity_id, outcome = excluded.outcome,
  payment_method_code = excluded.payment_method_code, revenue_pre_tax = excluded.revenue_pre_tax,
  revenue_total_incl_tax = excluded.revenue_total_incl_tax, tip_amount = excluded.tip_amount;

-- Same upsert again (a retried upload) must not fail or duplicate.
insert into job (job_id, shift_id, opportunity_id, outcome, payment_method_code, discount_amount,
                 revenue_pre_tax, revenue_total_incl_tax, tip_amount, created_at)
values ('01900000-0000-7000-8000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'OPP-P1', 'completed',
        'cash', 0, 100, 114.98, 10, now())
on conflict (job_id) do update set opportunity_id = excluded.opportunity_id;
select tests.eq((select count(*) from job where opportunity_id = 'OPP-P1'), 1::bigint, 'retry is idempotent');

insert into disposal_visit (disposal_visit_id, shift_id, site_id, visit_at, ticket_number, created_at)
select '01900000-0000-7000-8000-000000000002', 'c0000000-0000-0000-0000-000000000001', site_id, now(), 'EJ-P1', now()
from site where code = 'eco_junk'
on conflict (disposal_visit_id) do update set ticket_number = excluded.ticket_number;

insert into disposal_material_txn (material_txn_id, disposal_visit_id, material_type_id, weight_kg, created_at)
select '01900000-0000-7000-8000-000000000003', '01900000-0000-7000-8000-000000000002', material_type_id, 300, now()
from material_type where code = 'garbage'
on conflict (material_txn_id) do update set weight_kg = excluded.weight_kg;
select tests.eq((select signed_amount from disposal_material_txn where material_txn_id = '01900000-0000-7000-8000-000000000003'),
                45.00::numeric, 'server prices a line sent without price fields');

insert into cash_submission (cash_submission_id, shift_id, created_at)
values ('01900000-0000-7000-8000-000000000004', 'c0000000-0000-0000-0000-000000000001', now())
on conflict (cash_submission_id) do update set shift_id = excluded.shift_id;

insert into photo (photo_id, shift_id, photo_kind, entity_type, entity_id, storage_path, captured_at)
values ('01900000-0000-7000-8000-000000000005', 'c0000000-0000-0000-0000-000000000001', 'disposal_ticket',
        'disposal_visit', '01900000-0000-7000-8000-000000000002',
        'c0000000-0000-0000-0000-000000000001/01900000-0000-7000-8000-000000000005.jpg', now()),
       ('01900000-0000-7000-8000-000000000006', 'c0000000-0000-0000-0000-000000000001', 'cash_submission',
        'cash_submission', '01900000-0000-7000-8000-000000000004',
        'c0000000-0000-0000-0000-000000000001/01900000-0000-7000-8000-000000000006.jpg', now())
on conflict (photo_id) do update set captured_at = excluded.captured_at;

-- Submit with a finish time in the same update, as the phone sends it.
update shift set finish_time = now(), status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select status::text from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                'submitted', 'phone-shaped submit accepted');

-- test: a crew upload to another crew's shift is refused
select tests.login('a0000000-0000-0000-0000-000000000003');
select tests.throws($q$
  insert into job (job_id, shift_id, opportunity_id, created_at)
  values ('01900000-0000-7000-8000-000000000009', 'c0000000-0000-0000-0000-000000000001', 'OPP-X', now())
  on conflict (job_id) do update set opportunity_id = excluded.opportunity_id
$q$, 'not_allowed: shift not found or not yours');

-- test: deleting a weigh-in and a visit from the phone works while the shift is open to the crew
reset role;
update shift set hours_type = 'regular_junk', status = 'in_progress' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000001');
insert into disposal_visit (disposal_visit_id, shift_id, site_id, ticket_number)
select '01900000-0000-7000-8000-000000000012', 'c0000000-0000-0000-0000-000000000001', site_id, 'EJ-D' from site where code = 'eco_junk';
insert into disposal_material_txn (material_txn_id, disposal_visit_id, material_type_id, weight_kg)
select '01900000-0000-7000-8000-000000000013', '01900000-0000-7000-8000-000000000012', material_type_id, 10
from material_type where code = 'garbage';
delete from disposal_material_txn where material_txn_id = '01900000-0000-7000-8000-000000000013';
delete from disposal_visit where disposal_visit_id = '01900000-0000-7000-8000-000000000012';
select tests.eq((select count(*) from disposal_visit where disposal_visit_id = '01900000-0000-7000-8000-000000000012'),
                0::bigint, 'visit deleted');
