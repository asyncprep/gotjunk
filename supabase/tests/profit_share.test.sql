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

-- test: every plan value is in the setting, including the short-day team size
select tests.eq((select (value ->> 'small_team_min_crew')::numeric from app_setting where key = 'profit_share_plan'), 2::numeric, 'team size');
select tests.ok((select value ?& array['wage_per_hour', 'franchise_pct', 'fuel_pct', 'swing_truck_fee', 'min_revenue',
  'min_revenue_per_hour', 'small_team_hours', 'small_team_min_revenue', 'training_min_revenue',
  'training_min_revenue_per_hour', 'training_hours_max', 'training_hours_off_revenue_per_hour', 'low_cogs_max_pct',
  'mid_cogs_max_pct', 'max_cogs_pct', 'hours_types'] from app_setting where key = 'profit_share_plan'), 'all keys present');

-- test: only configuration rights change the plan and the % per rank
select tests.login('a0000000-0000-0000-0000-000000000010');
update app_setting set value = value || '{"wage_per_hour": 99}'::jsonb where key = 'profit_share_plan';
update rank set share_pct_low_cogs = 99 where code = 'wingman';
select tests.login('a0000000-0000-0000-0000-000000000020');
select tests.eq((select (value ->> 'wage_per_hour')::numeric from app_setting where key = 'profit_share_plan'), 26::numeric, 'dispatcher cannot');
select tests.eq((select share_pct_low_cogs from rank where code = 'wingman'), 3.00::numeric, 'dispatcher cannot');
update app_setting set value = value || '{"wage_per_hour": 27}'::jsonb where key = 'profit_share_plan';
update rank set share_pct_low_cogs = 3.5 where code = 'wingman';
select tests.eq((select (value ->> 'wage_per_hour')::numeric from app_setting where key = 'profit_share_plan'), 27::numeric, 'admin with config rights');
select tests.eq((select share_pct_low_cogs from rank where code = 'wingman'), 3.50::numeric, 'admin with config rights');

-- test: a route can use several swing trucks; the old yes/no follows (client, Nov 6)
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set swing_truck_count = 3 where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select swing_truck_count from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 3, 'the crew lead enters the number');
select tests.ok((select swing_truck from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 'yes/no follows the number');
update shift set swing_truck = false where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select swing_truck_count from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 0, 'an older build turning it off clears the number');
update shift set swing_truck = true where shift_id = 'c0000000-0000-0000-0000-000000000001';
select tests.eq((select swing_truck_count from shift where shift_id = 'c0000000-0000-0000-0000-000000000001'), 1, 'an older build turning it on means one truck');
