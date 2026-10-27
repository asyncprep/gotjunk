-- Per-test fixture (runs as system inside each test's transaction).
-- Users:  a…01 ttm1 (e1), a…02 ttm2 (e2), a…03 ttm3 (e3, other shift), a…10 dispatcher, a…20 admin
-- Shifts: c…01 = T-01 / P-01 with e1 + e2;  c…02 = T-02 / P-02 with e3
reset role;

insert into auth.users (id) values
  ('a0000000-0000-0000-0000-000000000001'), ('a0000000-0000-0000-0000-000000000002'),
  ('a0000000-0000-0000-0000-000000000003'), ('a0000000-0000-0000-0000-000000000010'),
  ('a0000000-0000-0000-0000-000000000020');

insert into public.employee (employee_id, full_name) values
  ('b0000000-0000-0000-0000-000000000001', 'Crew One'),
  ('b0000000-0000-0000-0000-000000000002', 'Crew Two'),
  ('b0000000-0000-0000-0000-000000000003', 'Crew Three'),
  ('b0000000-0000-0000-0000-000000000004', 'Crew Four');

insert into public.app_user (user_id, employee_id, role, can_edit_config) values
  ('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'ttm', false),
  ('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'ttm', false),
  ('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'ttm', false),
  ('a0000000-0000-0000-0000-000000000010', null, 'dispatcher', false),
  ('a0000000-0000-0000-0000-000000000020', null, 'admin', true);

insert into public.employee_rank_history (employee_id, rank_id, effective_from)
select 'b0000000-0000-0000-0000-000000000001'::uuid, rank_id, date '2025-01-01' from public.rank where code = 'recruit'
union all
select 'b0000000-0000-0000-0000-000000000002'::uuid, rank_id, date '2025-01-01' from public.rank where code = 'wingman';

insert into public.shift (shift_id, truck_id, phone_id, dispatcher_id)
select 'c0000000-0000-0000-0000-000000000001', t.truck_id, p.phone_id, 'a0000000-0000-0000-0000-000000000010'
from public.truck t, public.phone p where t.unit_number = 'T-01' and p.label = 'P-01';

insert into public.shift (shift_id, truck_id, phone_id, dispatcher_id)
select 'c0000000-0000-0000-0000-000000000002', t.truck_id, p.phone_id, 'a0000000-0000-0000-0000-000000000010'
from public.truck t, public.phone p where t.unit_number = 'T-02' and p.label = 'P-02';

insert into public.shift_crew_member (shift_id, employee_id, joined_at) values
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', now() - interval '9 hours'),
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', now() - interval '9 hours'),
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000003', now() - interval '9 hours');
