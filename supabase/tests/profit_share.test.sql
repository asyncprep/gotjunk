-- Live profit share: the plan, rank %, the route inputs and each crew member's rank (Nov 3).

-- test: the plan and rank % from the Aug 2024 sheet are in place
select tests.eq((select (value ->> 'wage_per_hour')::numeric from app_setting where key = 'profit_share_plan'), 26::numeric, 'wage per hour');
select tests.eq((select share_pct_low_cogs from rank where code = 'wingman'), 3.00::numeric, 'wingman under 43%');
select tests.eq((select share_pct_high_cogs from rank where code = 'jr_coach'), 3.00::numeric, 'jr coach 47-50%');
select tests.ok((select share_pct_low_cogs is null from rank where code = 'recruit'), 'recruit gets no share');

-- test: crew members get their rank as soon as they are on the route
select tests.eq((select r.code from shift_crew_member m join rank r on r.rank_id = m.rank_id_snapshot
                  where m.shift_id = 'c0000000-0000-0000-0000-000000000001'
                    and m.employee_id = 'b0000000-0000-0000-0000-000000000002'), 'wingman', 'rank on insert');

-- test: a rank change shows on routes that aren't accepted yet
select tests.login('a0000000-0000-0000-0000-000000000020');
select public.set_employee_rank('b0000000-0000-0000-0000-000000000002',
  (select rank_id from rank where code = 'sales_pro'), current_date - 1, 'promoted');
select tests.eq((select r.code from shift_crew_member m join rank r on r.rank_id = m.rank_id_snapshot
                  where m.shift_id = 'c0000000-0000-0000-0000-000000000001'
                    and m.employee_id = 'b0000000-0000-0000-0000-000000000002'), 'sales_pro', 'rank refreshed');

-- test: the crew lead sets fuel, swing truck and training; damages stay with dispatch
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set hours_type = 'regular_junk', status = 'in_progress' where shift_id = 'c0000000-0000-0000-0000-000000000001';
update shift set fuel_mode = 'two_trucks', swing_truck = true, training_day = true, training_hours_removed = 3
 where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select fuel_mode from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 'two_trucks', 'fuel set by crew');
select tests.throws($q$
  update shift set damages = true where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'not_allowed: crew cannot change damages');
select tests.throws($q$
  update shift set fuel_mode = 'three_trucks' where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, '%check%');
select tests.login('a0000000-0000-0000-0000-000000000010');
update shift set damages = true where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.ok((select damages from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 'dispatch records damages');
