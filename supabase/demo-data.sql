-- Truck Team OS: DEMO data for the development project only. Never run in production.
-- Every demo row uses an id starting with d0…d7 (d0000000-…), employee names end with
-- "(démo)", so supabase/demo-data-cleanup.sql can remove all of it. To reload, run the cleanup
-- script first (or paste both, cleanup first). Requires the seed (sites, materials, rates,
-- trucks, phones, payment methods, checklist). Times are relative to now, so it works any hour.
-- Photo rows have no files in storage: the admin app shows them as "not received yet".

begin;

-- Demo trucks and phones (separate from real ones, so demo shifts never collide with real shifts)
insert into public.truck (truck_id, unit_number) values
  ('d6000000-0000-0000-0000-000000000001', 'DÉMO-1'), ('d6000000-0000-0000-0000-000000000002', 'DÉMO-2'),
  ('d6000000-0000-0000-0000-000000000003', 'DÉMO-3');
insert into public.phone (phone_id, label) values
  ('d7000000-0000-0000-0000-000000000001', 'TÉL-DÉMO-1'), ('d7000000-0000-0000-0000-000000000002', 'TÉL-DÉMO-2'),
  ('d7000000-0000-0000-0000-000000000003', 'TÉL-DÉMO-3');

-- Employees and ranks
insert into public.employee (employee_id, full_name, ceridian_id, preferred_language) values
  ('d0000000-0000-0000-0000-0000000000e1', 'Alex Tremblay (démo)',   'DEMO-101', 'fr'),
  ('d0000000-0000-0000-0000-0000000000e2', 'Samira Haddad (démo)',   'DEMO-102', 'fr'),
  ('d0000000-0000-0000-0000-0000000000e3', 'Jordan Côté (démo)',     'DEMO-103', 'en'),
  ('d0000000-0000-0000-0000-0000000000e4', 'Maxime Gagnon (démo)',   'DEMO-104', 'fr'),
  ('d0000000-0000-0000-0000-0000000000e5', 'Priya Singh (démo)',     'DEMO-105', 'en'),
  ('d0000000-0000-0000-0000-0000000000e6', 'Félix Bouchard (démo)',  'DEMO-106', 'fr'),
  ('d0000000-0000-0000-0000-0000000000e7', 'Chloé Lavoie (démo)',    'DEMO-107', 'fr'),
  ('d0000000-0000-0000-0000-0000000000e8', 'Daniel Okafor (démo)',   'DEMO-108', 'en');

insert into public.employee_rank_history (employee_id, rank_id, effective_from)
select e.id::uuid, r.rank_id, date '2026-01-05'
from (values
  ('d0000000-0000-0000-0000-0000000000e1', 'trainer'), ('d0000000-0000-0000-0000-0000000000e2', 'sales_pro'),
  ('d0000000-0000-0000-0000-0000000000e3', 'wingman'), ('d0000000-0000-0000-0000-0000000000e4', 'recruit'),
  ('d0000000-0000-0000-0000-0000000000e5', 'sales_pro'), ('d0000000-0000-0000-0000-0000000000e6', 'wingman'),
  ('d0000000-0000-0000-0000-0000000000e7', 'recruit'), ('d0000000-0000-0000-0000-0000000000e8', 'wingman')
) as e(id, rank)
join public.rank r on r.code = e.rank;

-- Shifts. Today: DÉMO-1 in progress, DÉMO-2 submitted (waiting for dispatch), DÉMO-3 not started.
-- Yesterday: DÉMO-1 accepted and locked.
insert into public.shift (shift_id, shift_date, status, truck_id, phone_id, hours_type, hours_type_confirmed_at,
                          start_time, finish_time, submitted_at, locked_at, truck_phone_confirmed_at)
select v.id::uuid, public.business_date(now()) + v.day_offset, v.status::public.shift_status, t.truck_id, p.phone_id,
       v.hours::public.hours_type,
       case when v.status = 'locked' then now() - interval '23 hours' end,
       now() - make_interval(hours => v.start_ago),
       now() - make_interval(hours => v.end_ago),
       case when v.status in ('submitted', 'locked') then now() - make_interval(hours => v.end_ago) end,
       case when v.status = 'locked' then now() - interval '23 hours' end,
       now() - make_interval(hours => v.start_ago)
from (values
  ('d1000000-0000-0000-0000-000000000001', 0,  'in_progress', 'DÉMO-1', 'TÉL-DÉMO-1', 'regular_junk', 5,    null::int),
  ('d1000000-0000-0000-0000-000000000002', 0,  'submitted',   'DÉMO-2', 'TÉL-DÉMO-2', 'regular_junk', 9,    1),
  ('d1000000-0000-0000-0000-000000000003', 0,  'open',        'DÉMO-3', 'TÉL-DÉMO-3', null,           null, null),
  ('d1000000-0000-0000-0000-000000000004', -1, 'locked',      'DÉMO-1', 'TÉL-DÉMO-1', 'regular_junk', 33,   24)
) as v(id, day_offset, status, truck, phone, hours, start_ago, end_ago)
join public.truck t on t.unit_number = v.truck
join public.phone p on p.label = v.phone;

insert into public.shift_crew_member (shift_id, employee_id, joined_at)
select c.shift_id::uuid, c.employee_id::uuid, now() - interval '2 days'
from (values
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-0000000000e1'),
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-0000000000e4'),
  ('d1000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-0000000000e2'),
  ('d1000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-0000000000e3'),
  ('d1000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-0000000000e7'),
  ('d1000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-0000000000e5'),
  ('d1000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-0000000000e6'),
  ('d1000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-0000000000e1'),
  ('d1000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-0000000000e8')
) as c(shift_id, employee_id)
join public.shift s on s.shift_id = c.shift_id::uuid;

-- Jobs (amounts include QC tax 14.975%)
insert into public.job (job_id, shift_id, opportunity_id, outcome, payment_method_code, discount_amount,
                        revenue_pre_tax, revenue_total_incl_tax, tip_amount, completed_at, cancellation_reason_id)
select j.id::uuid, j.shift_id::uuid, j.opp, j.outcome::public.job_outcome, j.method, j.discount, j.pre, j.total, j.tip,
       case when j.outcome = 'completed' then now() - make_interval(hours => j.hours_ago) end,
       (select reason_id from public.cancellation_reason where code = j.reason)
from (values
  -- DÉMO-1 today, in progress
  ('d2000000-0000-0000-0000-000000000101', 'd1000000-0000-0000-0000-000000000001', 'OPP-24811', 'completed', 'card', 0,    349.00, 401.26, 30.00, 3, null),
  ('d2000000-0000-0000-0000-000000000102', 'd1000000-0000-0000-0000-000000000001', 'OPP-24815', 'completed', 'cash', 20,   189.00, 217.30, 10.00, 2, null),
  ('d2000000-0000-0000-0000-000000000103', 'd1000000-0000-0000-0000-000000000001', 'OPP-24822', 'cancelled_pending', null, 0, null, null, 0, 1, null),
  -- DÉMO-2 today, submitted
  ('d2000000-0000-0000-0000-000000000201', 'd1000000-0000-0000-0000-000000000002', 'OPP-24790', 'completed', 'card', 0,    629.00, 723.19, 45.00, 7, null),
  ('d2000000-0000-0000-0000-000000000202', 'd1000000-0000-0000-0000-000000000002', 'OPP-24799', 'completed', 'cash', 0,    259.00, 297.79, 0,     5, null),
  ('d2000000-0000-0000-0000-000000000203', 'd1000000-0000-0000-0000-000000000002', 'OPP-24803', 'completed', 'card', 50,   419.00, 481.75, 25.00, 4, null),
  ('d2000000-0000-0000-0000-000000000204', 'd1000000-0000-0000-0000-000000000002', 'OPP-24808', 'cancelled_pending', null, 0, null, null, 0, 3, null),
  -- DÉMO-1 yesterday, locked
  ('d2000000-0000-0000-0000-000000000401', 'd1000000-0000-0000-0000-000000000004', 'OPP-24702', 'completed', 'card', 0,    549.00, 631.21, 40.00, 30, null),
  ('d2000000-0000-0000-0000-000000000402', 'd1000000-0000-0000-0000-000000000004', 'OPP-24710', 'completed', 'cash', 0,    199.00, 228.80, 20.00, 28, null),
  ('d2000000-0000-0000-0000-000000000403', 'd1000000-0000-0000-0000-000000000004', 'OPP-24714', 'cancelled_confirmed', null, 0, null, null, 0, 27, 'price_declined')
) as j(id, shift_id, opp, outcome, method, discount, pre, total, tip, hours_ago, reason);

-- Disposal visits and weigh-ins (priced by the database from the seed rates)
insert into public.disposal_visit (disposal_visit_id, shift_id, site_id, visit_at, ticket_number)
select v.id::uuid, v.shift_id::uuid, s.site_id, now() - make_interval(hours => v.hours_ago), v.ticket
from (values
  ('d3000000-0000-0000-0000-000000000101', 'd1000000-0000-0000-0000-000000000001', 'eco_junk',     2, 'EJ-55102'),
  ('d3000000-0000-0000-0000-000000000201', 'd1000000-0000-0000-0000-000000000002', 'eco_junk',     6, 'EJ-55087'),
  ('d3000000-0000-0000-0000-000000000202', 'd1000000-0000-0000-0000-000000000002', 'outside_dump', 3, 'OD-3391'),
  ('d3000000-0000-0000-0000-000000000401', 'd1000000-0000-0000-0000-000000000004', 'eco_junk',     29, 'EJ-54960')
) as v(id, shift_id, site, hours_ago, ticket)
join public.site s on s.code = v.site;

insert into public.disposal_material_txn (disposal_visit_id, material_type_id, weight_kg)
select l.visit_id::uuid, m.material_type_id, l.kg
from (values
  ('d3000000-0000-0000-0000-000000000101', 'garbage', 420), ('d3000000-0000-0000-0000-000000000101', 'donation', 180),
  ('d3000000-0000-0000-0000-000000000201', 'garbage', 610), ('d3000000-0000-0000-0000-000000000201', 'wood', 240),
  ('d3000000-0000-0000-0000-000000000201', 'metal_electronics', 95), ('d3000000-0000-0000-0000-000000000202', 'mixed', 320),
  ('d3000000-0000-0000-0000-000000000401', 'garbage', 530), ('d3000000-0000-0000-0000-000000000401', 'mattress_clean', 60)
) as l(visit_id, material, kg)
join public.material_type m on m.code = l.material;

-- Cash records and photo rows (files are not in storage for demo data)
insert into public.cash_submission (cash_submission_id, shift_id, counted_cash, envelope_id, verified_at, mismatch_resolution) values
  ('d4000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', null, null, null, null),
  ('d4000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000004', 248.80, 'ENV-DEMO-1', now() - interval '23 hours', null);

insert into public.photo (photo_id, shift_id, photo_kind, entity_type, entity_id, storage_path, captured_at)
select p.id::uuid, p.shift_id::uuid, p.kind::public.photo_kind, p.entity_type, p.entity_id::uuid,
       p.shift_id || '/' || p.id || '.jpg', now() - make_interval(hours => p.hours_ago)
from (values
  ('d5000000-0000-0000-0000-000000000101', 'd1000000-0000-0000-0000-000000000001', 'disposal_ticket', 'disposal_visit',  'd3000000-0000-0000-0000-000000000101', 2),
  ('d5000000-0000-0000-0000-000000000201', 'd1000000-0000-0000-0000-000000000002', 'disposal_ticket', 'disposal_visit',  'd3000000-0000-0000-0000-000000000201', 6),
  ('d5000000-0000-0000-0000-000000000202', 'd1000000-0000-0000-0000-000000000002', 'disposal_ticket', 'disposal_visit',  'd3000000-0000-0000-0000-000000000202', 3),
  ('d5000000-0000-0000-0000-000000000203', 'd1000000-0000-0000-0000-000000000002', 'cash_submission', 'cash_submission', 'd4000000-0000-0000-0000-000000000002', 1),
  ('d5000000-0000-0000-0000-000000000401', 'd1000000-0000-0000-0000-000000000004', 'disposal_ticket', 'disposal_visit',  'd3000000-0000-0000-0000-000000000401', 29),
  ('d5000000-0000-0000-0000-000000000402', 'd1000000-0000-0000-0000-000000000004', 'cash_submission', 'cash_submission', 'd4000000-0000-0000-0000-000000000004', 25)
) as p(id, shift_id, kind, entity_type, entity_id, hours_ago);

-- Yesterday's locked shift: checklist done, ranks and expected cash frozen
insert into public.shift_checklist_check (shift_id, item_id, checked, checked_at)
select 'd1000000-0000-0000-0000-000000000004', item_id, true, now() - interval '23 hours'
from public.checklist_item where active;

update public.shift_crew_member m set rank_id_snapshot = public.rank_on(m.employee_id, s.shift_date)
from public.shift s where s.shift_id = m.shift_id and m.shift_id = 'd1000000-0000-0000-0000-000000000004';

update public.cash_submission c set expected_cash_snapshot = t.expected_cash
from public.v_shift_totals t where t.shift_id = c.shift_id and c.cash_submission_id = 'd4000000-0000-0000-0000-000000000004';

commit;

-- Quick summary
select s.shift_date, t.unit_number, s.status, tot.jobs_completed, tot.revenue_pre_tax, tot.tips,
       tot.net_disposal, tot.expected_cash
from public.shift s join public.truck t using (truck_id) join public.v_shift_totals tot using (shift_id)
where s.shift_id::text like 'd1000000-%'
order by s.shift_date desc, t.unit_number;
