-- Shared truck phone: the crew lead signs in (Oct 31). Since Nov 13 every crew member can enter the route.

-- test: the lead and another crew member both enter jobs and change the shift
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set hours_type = 'regular_junk', status = 'in_progress' where shift_id = 'c0000000-0000-0000-0000-000000000001';
insert into job (shift_id, opportunity_id, outcome) values ('c0000000-0000-0000-0000-000000000001', 'OPP-L1', null);
select tests.login('a0000000-0000-0000-0000-000000000002');
insert into job (shift_id, opportunity_id, outcome) values ('c0000000-0000-0000-0000-000000000001', 'OPP-L2', null);
update shift set truck_phone_confirmed_at = now() where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select count(*) from job), 2::bigint, 'both jobs saved');
select tests.eq((select lead_employee_id from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                'b0000000-0000-0000-0000-000000000001'::uuid, 'the lead stays the lead');

-- test: crew cannot make themselves lead
select tests.login('a0000000-0000-0000-0000-000000000002');
select tests.throws($q$
  update shift set lead_employee_id = 'b0000000-0000-0000-0000-000000000002' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'not_allowed: crew cannot change lead_employee_id');

-- test: when the lead leaves, the next crew member on the phone takes over
select tests.login('a0000000-0000-0000-0000-000000000010');
update shift_crew_member set left_at = now() - interval '1 minute'
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000002');
update shift set truck_phone_confirmed_at = now() where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select lead_employee_id from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                'b0000000-0000-0000-0000-000000000002'::uuid, 'crew two took over');
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  update shift set hours_type = 'regular_junk' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'not_crew%');
select tests.throws($q$
  insert into job (shift_id, opportunity_id, outcome) values ('c0000000-0000-0000-0000-000000000001', 'OPP-L3', null)
$q$, 'not_crew%');

-- test: dispatch changes the lead, only to someone on the crew
select tests.login('a0000000-0000-0000-0000-000000000010');
update shift set lead_employee_id = 'b0000000-0000-0000-0000-000000000002' where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.throws($q$
  update shift set lead_employee_id = 'b0000000-0000-0000-0000-000000000003' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'lead_not_crew%');

-- test: create_shift sets the lead, defaulting to the first crew member
select tests.login('a0000000-0000-0000-0000-000000000010');
select create_shift(public.business_date(now()),
  (select truck_id from truck where unit_number = 'T-03'), (select phone_id from phone where label = 'P-03'),
  array['b0000000-0000-0000-0000-000000000004'::uuid], array['driver']::crew_position[]);
select tests.eq((select lead_employee_id from shift s join truck t using (truck_id) where t.unit_number = 'T-03'),
                'b0000000-0000-0000-0000-000000000004'::uuid, 'default lead');
select tests.throws($q$
  select create_shift(public.business_date(now()),
    (select truck_id from truck where unit_number = 'T-03'), (select phone_id from phone where label = 'P-03'),
    array['b0000000-0000-0000-0000-000000000004'::uuid], array['driver']::crew_position[], 'b0000000-0000-0000-0000-000000000001'::uuid)
$q$, 'lead_not_crew%');

-- test: removing the lead from the crew leaves the shift without a lead
select tests.login('a0000000-0000-0000-0000-000000000010');
delete from shift_crew_member
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000001';
select tests.eq((select lead_employee_id from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                null::uuid, 'no lead');
