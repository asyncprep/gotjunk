-- test: crew see only their own shifts and records
reset role;
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-1', 'completed', 'card', 100, 114.98);

select tests.login('a0000000-0000-0000-0000-000000000003');
select tests.eq((select count(*) from shift), 1::bigint, 'ttm3 sees one shift');
select tests.eq((select count(*) from job), 0::bigint, 'ttm3 sees no jobs from other shifts');
select tests.eq((select count(*) from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                0::bigint, 'scoreboard respects RLS');
update job set tip_amount = 99 where opportunity_id = 'OPP-1';
reset role;
select tests.eq((select tip_amount from job where opportunity_id = 'OPP-1'), 0.00::numeric, 'other crew cannot edit');

select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.eq((select count(*) from shift), 1::bigint, 'ttm1 sees own shift');
select tests.eq((select count(*) from job), 1::bigint, 'ttm1 sees own jobs');
select tests.eq((select count(*) from employee), 2::bigint, 'ttm1 sees self and crewmate only');

-- test: dispatcher sees every shift
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.eq((select count(*) from shift), 2::bigint, 'all shifts');
select tests.eq((select count(*) from employee), 4::bigint, 'all employees');

-- test: crew cannot create shifts, change assignments or crew
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  insert into shift (truck_id, phone_id)
  select truck_id, phone_id from truck, phone where unit_number = 'T-03' and label = 'P-03'
$q$, 'not_allowed: only dispatch creates shifts');
select tests.throws($q$
  update shift set truck_id = (select truck_id from truck where unit_number = 'T-03')
  where shift_id = 'c0000000-0000-0000-0000-000000000001'
$q$, 'not_allowed%');
select tests.throws($q$
  insert into shift_crew_member (shift_id, employee_id)
  values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004')
$q$, 'not_allowed: only dispatch can change shift_crew_member');

-- test: crew cannot edit configuration or read the audit log
select tests.login('a0000000-0000-0000-0000-000000000001');
update site_rate_config set rate_per_ton = 1;  -- RLS: silently affects no rows
reset role;
select tests.eq((select count(*) from site_rate_config where rate_per_ton = 1), 0::bigint, 'rates unchanged');
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.eq((select count(*) from audit_log), 0::bigint, 'audit hidden from crew');

-- test: config editor can change rates, dispatcher cannot
select tests.login('a0000000-0000-0000-0000-000000000010');
update site_rate_config set rate_per_ton = 1;
reset role;
select tests.eq((select count(*) from site_rate_config where rate_per_ton = 1), 0::bigint, 'dispatcher blocked');
select tests.login('a0000000-0000-0000-0000-000000000020');
update site_rate_config set special_rule_code = 'reviewed'
where material_type_id = (select material_type_id from material_type where code = 'garbage');
select tests.eq((select special_rule_code from site_rate_config
                 where material_type_id = (select material_type_id from material_type where code = 'garbage')),
                'reviewed', 'admin with config rights can edit');

-- test: employee cannot be double-booked on one date
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.throws($q$
  insert into shift_crew_member (shift_id, employee_id)
  values ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001')
$q$, 'crew_double_booked%');

-- test: other crew cannot read readiness checks for a shift
select tests.login('a0000000-0000-0000-0000-000000000003');
select tests.throws($q$
  select * from shift_problems('c0000000-0000-0000-0000-000000000001')
$q$, 'not_allowed%');
