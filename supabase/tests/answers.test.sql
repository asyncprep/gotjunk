-- Client answers of Nov 2, 2026 (Projet page) and the Oct 25 route sheets.

-- test: payment methods and ranks follow the client's lists
select tests.eq((select string_agg(code, ',' order by code) from payment_method where active),
                'card,cash,debit_card,etransfer,invoice', 'J2 payment methods');
select tests.eq((select string_agg(name_en, ',' order by sort_order) from rank where active),
                'Recruit,Wingman,Professional,Expert,JR Coach', 'A5 ranks');

-- test: metal and electronics at Eco-Junk earn a credit
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift set hours_type = 'regular_junk', status = 'in_progress' where shift_id = 'c0000000-0000-0000-0000-000000000001';
insert into disposal_visit (disposal_visit_id, shift_id, site_id, ticket_number)
select 'd0000000-0000-0000-0000-000000000009', 'c0000000-0000-0000-0000-000000000001', site_id, '48953'
from site where code = 'eco_junk';
insert into disposal_material_txn (disposal_visit_id, material_type_id, weight_kg)
select 'd0000000-0000-0000-0000-000000000009', material_type_id, 660 from material_type where code = 'metal_electronics';
select tests.eq((select signed_amount from disposal_material_txn where disposal_visit_id = 'd0000000-0000-0000-0000-000000000009'),
                -33.00::numeric, '660 kg of metal = $33 credit, as on the Oct 25 sheet');

-- test: dispatch sets the tip split by hand; it must add up to the route's tips
select tests.prepare_ready_shift();
select tests.login('a0000000-0000-0000-0000-000000000010');
update shift_crew_member set tip_override = 15.00
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000001';
select tests.eq((select string_agg(tips::text, ',' order by employee_id) from v_shift_tips_by_employee
                 where shift_id = 'c0000000-0000-0000-0000-000000000001'), '15.00,0.00', 'override replaces the equal split');
select tests.eq((select detail from shift_problems('c0000000-0000-0000-0000-000000000001', 'lock') where code = 'tip_override_mismatch'),
                '-5.00', '$5 of the $20 tip not handed out');
update shift_crew_member set tip_override = 5.00
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000002';
select tests.eq((select count(*) from shift_problems('c0000000-0000-0000-0000-000000000001', 'lock') where code = 'tip_override_mismatch'),
                0::bigint, 'split adds up');

-- test: crew cannot set the tip split
select tests.prepare_ready_shift();
select tests.login('a0000000-0000-0000-0000-000000000001');
update shift_crew_member set tip_override = 20.00
 where shift_id = 'c0000000-0000-0000-0000-000000000001' and employee_id = 'b0000000-0000-0000-0000-000000000001';
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.eq((select count(*) from shift_crew_member where tip_override is not null), 0::bigint, 'crew change matched no row');
