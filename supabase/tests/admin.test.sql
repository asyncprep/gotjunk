-- test: dispatcher creates a shift with its crew in one call
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.ok((select create_shift(
  public.business_date(now()),
  (select truck_id from truck where unit_number = 'T-03'),
  (select phone_id from phone where label = 'P-03'),
  array['b0000000-0000-0000-0000-000000000004'::uuid]) is not null), 'shift created');
select tests.eq((select count(*) from shift_crew_member m join shift s using (shift_id)
                 join truck t using (truck_id) where t.unit_number = 'T-03'), 1::bigint, 'crew attached');
select tests.eq((select dispatcher_id from shift s join truck t using (truck_id) where t.unit_number = 'T-03'),
                'a0000000-0000-0000-0000-000000000010'::uuid, 'dispatcher recorded');

-- test: shift creation is all-or-nothing
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  select create_shift(public.business_date(now()),
    (select truck_id from truck where unit_number = 'T-03'),
    (select phone_id from phone where label = 'P-03'),
    array['b0000000-0000-0000-0000-000000000001'::uuid])
$q$, 'crew_double_booked%');
select tests.eq((select count(*) from shift s join truck t using (truck_id) where t.unit_number = 'T-03'),
                0::bigint, 'no half-created shift');

-- test: crew cannot create shifts through the function either
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  select create_shift(public.business_date(now()),
    (select truck_id from truck where unit_number = 'T-03'),
    (select phone_id from phone where label = 'P-03'),
    array['b0000000-0000-0000-0000-000000000004'::uuid])
$q$, 'not_allowed%');

-- test: promotion closes the previous rank and keeps history
select tests.login('a0000000-0000-0000-0000-000000000020');
select set_employee_rank('b0000000-0000-0000-0000-000000000001',
  (select rank_id from rank where code = 'wingman'), date '2026-11-01', 'Promotion');
select tests.eq((select effective_to from employee_rank_history h join rank r using (rank_id)
                 where h.employee_id = 'b0000000-0000-0000-0000-000000000001' and r.code = 'recruit'),
                date '2026-10-31', 'recruit closed the day before');
select tests.eq((select r.code from rank r where r.rank_id = rank_on('b0000000-0000-0000-0000-000000000001', date '2026-11-15')),
                'wingman', 'wingman from Nov 1');
select tests.eq((select r.code from rank r where r.rank_id = rank_on('b0000000-0000-0000-0000-000000000001', date '2026-10-15')),
                'recruit', 'history unchanged');

-- test: dispatcher cannot change ranks
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  select set_employee_rank('b0000000-0000-0000-0000-000000000001',
    (select rank_id from rank where code = 'wingman'), date '2026-11-01')
$q$, 'not_allowed%');
