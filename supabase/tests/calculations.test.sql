-- test: disposal lines are priced from config with signed costs and credits
select tests.login('a0000000-0000-0000-0000-000000000001');

insert into disposal_visit (disposal_visit_id, shift_id, site_id, ticket_number)
select 'd0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', site_id, 'EJ-100'
from site where code = 'eco_junk';
insert into disposal_visit (disposal_visit_id, shift_id, site_id, ticket_number)
select 'd0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', site_id, 'OD-7'
from site where code = 'outside_dump';

insert into disposal_material_txn (disposal_visit_id, material_type_id, weight_kg)
select 'd0000000-0000-0000-0000-000000000001', material_type_id, w
from material_type m join (values ('garbage', 300), ('donation', 400), ('mattress_clean', 120)) v(code, w)
  on v.code = m.code;
insert into disposal_material_txn (disposal_visit_id, material_type_id, weight_kg)
select 'd0000000-0000-0000-0000-000000000002', material_type_id, 300 from material_type where code = 'mixed';

select tests.eq((select signed_amount from disposal_material_txn t join material_type m using (material_type_id)
                 where m.code = 'garbage'), 45.00::numeric, 'garbage 300 kg at $150/t');
select tests.eq((select signed_amount from disposal_material_txn t join material_type m using (material_type_id)
                 where m.code = 'donation'), -30.00::numeric, 'donation credit 400 kg at $75/t');
select tests.eq((select signed_amount from disposal_material_txn t join material_type m using (material_type_id)
                 where m.code = 'mattress_clean'), 0.00::numeric, 'clean mattresses free');
select tests.eq((select billable_kg from disposal_material_txn t join material_type m using (material_type_id)
                 where m.code = 'mixed'), 500.0::numeric, 'outside dump half-ton minimum');
select tests.eq((select signed_amount from disposal_material_txn t join material_type m using (material_type_id)
                 where m.code = 'mixed'), 80.00::numeric, 'outside dump 500 kg at $160/t');
select tests.eq((select net_disposal from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                95.00::numeric, 'net disposal on the scoreboard');

-- test: a rate change does not rewrite history
insert into disposal_visit (disposal_visit_id, shift_id, site_id, ticket_number, visit_at)
select 'd0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', site_id, 'EJ-1',
       timestamptz '2026-06-15 12:00-04'
from site where code = 'eco_junk';
insert into disposal_material_txn (material_txn_id, disposal_visit_id, material_type_id, weight_kg)
select 'f0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', material_type_id, 300
from material_type where code = 'garbage';

update site_rate_config set effective_to = date '2026-06-30'
where material_type_id = (select material_type_id from material_type where code = 'garbage');
insert into site_rate_config (site_id, material_type_id, rate_per_ton, direction, effective_from)
select s.site_id, m.material_type_id, 200, 'cost', date '2026-07-01'
from site s, material_type m where s.code = 'eco_junk' and m.code = 'garbage';

select tests.eq((select signed_amount from disposal_material_txn where material_txn_id = 'f0000000-0000-0000-0000-000000000001'),
                45.00::numeric, 'existing line keeps its price');
update disposal_material_txn set weight_kg = 400 where material_txn_id = 'f0000000-0000-0000-0000-000000000001';
select tests.eq((select signed_amount from disposal_material_txn where material_txn_id = 'f0000000-0000-0000-0000-000000000001'),
                60.00::numeric, 'June weight change still uses the June rate');
update disposal_visit set visit_at = timestamptz '2026-07-02 12:00-04'
where disposal_visit_id = 'd0000000-0000-0000-0000-000000000001';
select tests.eq((select signed_amount from disposal_material_txn where material_txn_id = 'f0000000-0000-0000-0000-000000000001'),
                80.00::numeric, 'moving the visit to July re-prices at $200/t');

-- test: overlapping rates are rejected
select tests.throws($q$
  insert into site_rate_config (site_id, material_type_id, rate_per_ton, direction, effective_from)
  select s.site_id, m.material_type_id, 175, 'cost', date '2026-06-01'
  from site s, material_type m where s.code = 'eco_junk' and m.code = 'garbage'
$q$, 'rate_overlap%');

-- test: a missing rate blocks the line instead of guessing
insert into disposal_visit (disposal_visit_id, shift_id, site_id, ticket_number)
select 'd0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000001', site_id, 'OD-1'
from site where code = 'outside_dump';
select tests.throws($q$
  insert into disposal_material_txn (disposal_visit_id, material_type_id, weight_kg)
  select 'd0000000-0000-0000-0000-000000000009', material_type_id, 100 from material_type where code = 'wood'
$q$, 'no_rate%');

-- test: three-way tip split sums to the tip
insert into shift_crew_member (shift_id, employee_id, joined_at)
values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000004', now() - interval '9 hours');
select tests.login('a0000000-0000-0000-0000-000000000001');
insert into job (job_id, shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax, tip_amount)
values ('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'OPP-1', 'completed', 'card', 100, 114.98, 10.00);

select tests.eq((select array_agg(tip_share order by tip_share desc) from v_tip_split
                 where job_id = 'e0000000-0000-0000-0000-000000000001'),
                array[3.34, 3.33, 3.33]::numeric[], 'shares');
select tests.eq((select sum(tip_share) from v_tip_split where job_id = 'e0000000-0000-0000-0000-000000000001'),
                10.00::numeric, 'shares sum to tip');

-- test: crew member who left before the job gets no tip share
update shift_crew_member set left_at = now() - interval '1 hour'
where employee_id = 'b0000000-0000-0000-0000-000000000002';
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax, tip_amount)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-2', 'completed', 'card', 100, 114.98, 9.00);
select tests.eq((select count(*) from v_tip_split where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                1::bigint, 'only the remaining member shares');
select tests.eq((select tip_share from v_tip_split where shift_id = 'c0000000-0000-0000-0000-000000000001'),
                9.00::numeric, 'full tip');

-- test: scoreboard totals and expected cash
select tests.login('a0000000-0000-0000-0000-000000000001');
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax, tip_amount)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-10', 'completed', 'cash', 100.00, 114.98, 10.00),
       ('c0000000-0000-0000-0000-000000000001', 'OPP-11', 'completed', 'card', 200.00, 229.95, 0),
       ('c0000000-0000-0000-0000-000000000001', 'OPP-12', 'cancelled_pending', null, null, null, 0),
       ('c0000000-0000-0000-0000-000000000001', 'OPP-13', null, null, null, null, 0);
select tests.eq((select jobs_completed from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'), 2::bigint, 'completed');
select tests.eq((select jobs_cancelled from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'), 1::bigint, 'cancelled');
select tests.eq((select jobs_draft from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'), 1::bigint, 'drafts');
select tests.eq((select revenue_pre_tax from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'), 300.00::numeric, 'revenue');
select tests.eq((select tips from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'), 10.00::numeric, 'tips');
select tests.eq((select expected_cash from v_shift_totals where shift_id = 'c0000000-0000-0000-0000-000000000001'), 124.98::numeric, 'cash incl. tip');

-- test: completed job needs its financial fields
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($q$
  insert into job (shift_id, opportunity_id, outcome, payment_method_code)
  values ('c0000000-0000-0000-0000-000000000001', 'OPP-20', 'completed', 'card')
$q$, '%job_completed_requires_financials%');
select tests.throws($q$
  insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax)
  values ('c0000000-0000-0000-0000-000000000001', 'OPP-21', 'completed', 'card', 100, 90)
$q$, '%check%');

-- test: tax and repeated-opportunity warnings
reset role;
insert into job (shift_id, opportunity_id, outcome, payment_method_code, revenue_pre_tax, revenue_total_incl_tax)
values ('c0000000-0000-0000-0000-000000000001', 'OPP-30', 'completed', 'card', 100, 120.00),
       ('c0000000-0000-0000-0000-000000000002', 'OPP-30', 'completed', 'card', 100, 114.98);
select tests.ok(exists (select 1 from shift_problems('c0000000-0000-0000-0000-000000000001')
                        where code = 'tax_check' and severity = 'warning'), 'tax warning');
select tests.ok(exists (select 1 from shift_problems('c0000000-0000-0000-0000-000000000001')
                        where code = 'opportunity_repeated' and severity = 'warning'), 'repeat warning');
select tests.ok(not exists (select 1 from shift_problems('c0000000-0000-0000-0000-000000000002')
                            where code = 'tax_check'), 'correct tax has no warning');
