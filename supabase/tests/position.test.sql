-- Each crew member on a route is the driver or a navigator; exactly one driver (client, Nov 2).

-- test: create_shift stores each member's position
select tests.login('a0000000-0000-0000-0000-000000000010');
select create_shift(public.business_date(now()) + 1,
  (select truck_id from truck where unit_number = 'T-03'), (select phone_id from phone where label = 'P-03'),
  array['b0000000-0000-0000-0000-000000000004'::uuid, 'b0000000-0000-0000-0000-000000000003'::uuid],
  array['navigator', 'driver']::crew_position[]);
select tests.eq((select string_agg(m.position::text, ',' order by m.employee_id desc)
                 from shift_crew_member m join shift s using (shift_id) join truck t using (truck_id)
                 where t.unit_number = 'T-03'), 'navigator,driver', 'positions saved per member');

-- test: every member needs a position, and a route needs exactly one driver
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  select create_shift(public.business_date(now()) + 2,
    (select truck_id from truck where unit_number = 'T-03'), (select phone_id from phone where label = 'P-03'),
    array['b0000000-0000-0000-0000-000000000004'::uuid, 'b0000000-0000-0000-0000-000000000003'::uuid],
    array['driver']::crew_position[])
$q$, 'position_missing%');
select tests.throws($q$
  select create_shift(public.business_date(now()) + 1,
    (select truck_id from truck where unit_number = 'T-03'), (select phone_id from phone where label = 'P-03'),
    array['b0000000-0000-0000-0000-000000000004'::uuid, 'b0000000-0000-0000-0000-000000000003'::uuid],
    array['driver', null]::crew_position[])
$q$, 'position_missing%');
select tests.throws($q$
  select create_shift(public.business_date(now()) + 1,
    (select truck_id from truck where unit_number = 'T-03'), (select phone_id from phone where label = 'P-03'),
    array['b0000000-0000-0000-0000-000000000004'::uuid, 'b0000000-0000-0000-0000-000000000003'::uuid],
    array['navigator', 'navigator']::crew_position[])
$q$, 'one_driver%');
select tests.throws($q$
  select create_shift(public.business_date(now()) + 1,
    (select truck_id from truck where unit_number = 'T-03'), (select phone_id from phone where label = 'P-03'),
    array['b0000000-0000-0000-0000-000000000004'::uuid, 'b0000000-0000-0000-0000-000000000003'::uuid],
    array['driver', 'driver']::crew_position[])
$q$, 'one_driver%');

-- test: dispatch can swap positions; a crew login changes nothing (access rules hide the row)
select tests.login('a0000000-0000-0000-0000-000000000010');
update shift_crew_member set position = 'navigator'
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000001';
update shift_crew_member set position = 'driver'
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000002';
select tests.eq((select position::text from shift_crew_member
                 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000002'),
                'driver', 'dispatch swapped driver');
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift_crew_member set position = 'driver'
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.eq((select position::text from shift_crew_member
                 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000001'),
                'navigator', 'crew change matched no row');

-- test: dispatch names the route (tracker paste); the crew can't
select tests.login('a0000000-0000-0000-0000-000000000010');
update shift set route_code = 'C1' where shift_id = (select shift_id from shift order by shift_date desc limit 1);
select tests.eq((select count(*) from shift where route_code = 'C1'), 1::bigint, 'dispatcher sets the route name');

-- test: onboarding is a third position (client, Nov 3); still one driver
select tests.login('a0000000-0000-0000-0000-000000000010');
update shift_crew_member set position = 'onboarding'
 where shift_crew_id = (select shift_crew_id from shift_crew_member where position = 'navigator' limit 1);
select tests.eq((select count(*) from shift_crew_member where position = 'onboarding'), 1::bigint, 'dispatcher sets onboarding');

-- test: the tracker's route list is loaded, readable by dispatch, editable only with config rights
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.eq((select count(*) from route_name where active), 42::bigint, 'the 42 tracker routes');
update route_name set active = false where name = 'TR2';
select tests.eq((select count(*) from route_name where active), 42::bigint, 'dispatch cannot change the route list');
