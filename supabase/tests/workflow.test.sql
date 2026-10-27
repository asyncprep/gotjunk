-- test: crew starts a shift only after choosing hours type
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  update shift set status = 'in_progress' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'hours_type_missing%');
update shift set hours_type = 'regular_junk', status = 'in_progress'
where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select status::text from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 'in_progress', 'started');
select tests.ok((select start_time is not null and truck_phone_confirmed_at is not null
                 from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 'start stamped');

-- test: submit is blocked until the shift is complete
select tests.prepare_ready_shift();
select tests.login('a0000000-0000-0000-0000-000000000001');
insert into job (shift_id, opportunity_id) values ('c0000000-0000-0000-0000-000000000001', 'OPP-DRAFT');
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-CASH', 'completed', 'cash', 100, 114.98);
select tests.throws($q$
  update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'shift_not_ready: cash_photo_missing, job_incomplete');

update job set outcome = 'cancelled_pending' where opportunity_id = 'OPP-DRAFT';
insert into cash_submission (cash_submission_id, shift_id)
values ('ca000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001');
insert into photo (shift_id, photo_kind, entity_type, entity_id, storage_path)
values ('c0000000-0000-0000-0000-000000000001', 'cash_submission', 'cash_submission',
        'ca000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001/cash.jpg');
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select submitted_by from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                'a0000000-0000-0000-0000-000000000001'::uuid, 'submitted by crew');

-- test: missing ticket photo and number block submission
select tests.prepare_ready_shift();
update disposal_visit set ticket_number = null where disposal_visit_id = 'd0000000-0000-0000-0000-000000000001';
delete from photo where entity_id = 'd0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'shift_not_ready: ticket_number_missing, ticket_photo_missing');

-- test: submitted shift is frozen for crew
select tests.prepare_ready_shift();
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.throws($q$
  update job set tip_amount = 50 where job_id = 'e0000000-0000-0000-0000-000000000001'
$q$, 'shift_not_editable%');
select tests.throws($q$
  update shift set finish_time = now() where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'shift_not_editable%');
select tests.throws($q$
  update shift set status = 'locked' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'invalid_transition%');

-- test: dispatcher accepts a shift only after the checklist
select tests.prepare_ready_shift();
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';

select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  update shift set status = 'locked' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'shift_not_ready: checklist_incomplete%hours_type_unconfirmed%');

update shift set hours_type_confirmed_at = now() where shift_id = 'c0000000-0000-0000-0000-000000000001';
insert into shift_checklist_check (shift_id, item_id, checked)
select 'c0000000-0000-0000-0000-000000000001', item_id, true from checklist_item;
update shift set status = 'locked' where shift_id = 'c0000000-0000-0000-0000-000000000001';

select tests.eq((select locked_by from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                'a0000000-0000-0000-0000-000000000010'::uuid, 'locked by dispatcher');
select tests.eq((select hours_type_confirmed_by from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                'a0000000-0000-0000-0000-000000000010'::uuid, 'hours confirmed by dispatcher');
select tests.eq((select r.code from shift_crew_member m join rank r on r.rank_id = m.rank_id_snapshot
                 where m.employee_id = 'b0000000-0000-0000-0000-000000000001'), 'recruit', 'rank frozen at lock');

-- test: locked shift needs a reasoned reopen before any edit
select tests.prepare_ready_shift();
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';
update shift set hours_type_confirmed_at = now() where shift_id = 'c0000000-0000-0000-0000-000000000001';
insert into shift_checklist_check (shift_id, item_id, checked)
select 'c0000000-0000-0000-0000-000000000001', item_id, true from checklist_item;
update shift set status = 'locked' where shift_id = 'c0000000-0000-0000-0000-000000000001';

select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  update job set tip_amount = 50 where job_id = 'e0000000-0000-0000-0000-000000000001'
$q$, 'shift_locked%');
select tests.throws($q$
  update shift set status = 'reopened' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'reason_required%');
update shift set status = 'reopened', reopen_reason = 'Tip entered on wrong job'
where shift_id = 'c0000000-0000-0000-0000-000000000001';

select tests.login('a0000000-0000-0000-0000-000000000001');
update job set tip_amount = 25 where job_id = 'e0000000-0000-0000-0000-000000000001';
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';

reset role;
select tests.ok(exists (select 1 from audit_log where entity_id = 'c0000000-0000-0000-0000-000000000001'
                          and action = 'status:reopened' and reason = 'Tip entered on wrong job'
                          and actor_id = 'a0000000-0000-0000-0000-000000000010'), 'reopen audited with reason');
select tests.ok(exists (select 1 from audit_log where entity_id = 'e0000000-0000-0000-0000-000000000001'
                          and action = 'update' and field_changes -> 'tip_amount' ->> 'new' = '25.00'
                          and actor_id = 'a0000000-0000-0000-0000-000000000001'), 'tip edit audited');

-- test: dispatcher returns a shift with a reason
select tests.prepare_ready_shift();
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  update shift set status = 'returned' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'reason_required%');
update shift set status = 'returned', return_reason = 'Missing second ticket'
where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000001');
update job set tip_amount = 30 where job_id = 'e0000000-0000-0000-0000-000000000001';
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select return_reason from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                null::text, 'reason cleared on resubmit');

-- test: only dispatch finalizes a cancellation
select tests.login('a0000000-0000-0000-0000-000000000001');
insert into job (job_id, shift_id, opportunity_id, outcome)
values ('e0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000001', 'OPP-NO', 'cancelled_pending');
select tests.throws($q$
  update job set outcome = 'cancelled_confirmed',
    cancellation_reason_id = (select reason_id from cancellation_reason where code = 'other')
  where job_id = 'e0000000-0000-0000-0000-000000000009'
$q$, 'not_allowed%');

select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  update job set outcome = 'cancelled_confirmed' where job_id = 'e0000000-0000-0000-0000-000000000009'
$q$, '%job_confirmed_requires_reason%');
update job set outcome = 'cancelled_confirmed',
  cancellation_reason_id = (select reason_id from cancellation_reason where code = 'price_declined')
where job_id = 'e0000000-0000-0000-0000-000000000009';
select tests.eq((select cancellation_finalized_by from job where job_id = 'e0000000-0000-0000-0000-000000000009'),
                'a0000000-0000-0000-0000-000000000010'::uuid, 'finalized by dispatcher');

select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  update job set opportunity_id = 'OPP-X' where job_id = 'e0000000-0000-0000-0000-000000000009'
$q$, 'not_allowed%');

-- test: cash count is dispatch-only and a variance needs a note
select tests.prepare_ready_shift();
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-CASH', 'completed', 'cash', 100, 114.98);
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  insert into cash_submission (shift_id, counted_cash) values ('c0000000-0000-0000-0000-000000000001', 114.98)
$q$, 'not_allowed%');
insert into cash_submission (cash_submission_id, shift_id)
values ('ca000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001');
insert into photo (shift_id, photo_kind, entity_type, entity_id, storage_path)
values ('c0000000-0000-0000-0000-000000000001', 'cash_submission', 'cash_submission',
        'ca000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001/cash.jpg');
update shift set status = 'submitted' where shift_id = 'c0000000-0000-0000-0000-000000000001';

select tests.login('a0000000-0000-0000-0000-000000000010');
update shift set hours_type_confirmed_at = now() where shift_id = 'c0000000-0000-0000-0000-000000000001';
insert into shift_checklist_check (shift_id, item_id, checked)
select 'c0000000-0000-0000-0000-000000000001', item_id, true from checklist_item;
update cash_submission set counted_cash = 110.00 where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.throws($q$
  update shift set status = 'locked' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'shift_not_ready: cash_variance_unresolved');
update cash_submission set mismatch_resolution = 'Customer paid $110; balance on card'
where shift_id = 'c0000000-0000-0000-0000-000000000001';
update shift set status = 'locked' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select expected_cash_snapshot from cash_submission where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                114.98::numeric, 'expected cash frozen at lock');
