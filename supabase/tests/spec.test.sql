-- test: spec tracker is loaded with inconsistencies and questions
select tests.eq((select count(*) from spec_item where kind = 'inconsistency'), 17::bigint, 'inconsistencies');
select tests.ok((select count(*) from spec_item where kind = 'question') >= 50, 'questions');
select tests.eq((select string_agg(ref, ',') from spec_item where status <> 'open'), 'S10', 'only the shared-phone decision is answered at start');

-- test: dispatch can read the tracker, crew cannot
select tests.login('a0000000-0000-0000-0000-000000000010');
select tests.ok((select count(*) from spec_item) > 0, 'dispatcher reads');
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.eq((select count(*) from spec_item), 0::bigint, 'crew sees nothing');

-- test: only administration records answers, and the answer is stamped
select tests.login('a0000000-0000-0000-0000-000000000010');
update spec_item set status = 'answered', answer = 'x' where ref = 'J3';
reset role;
select tests.eq((select status from spec_item where ref = 'J3'), 'open', 'dispatcher cannot edit');

select tests.login('a0000000-0000-0000-0000-000000000020');
update spec_item set status = 'answered', answer = 'Prix refusé, client absent, autre' where ref = 'J3';
reset role;
select tests.eq((select answered_by from spec_item where ref = 'J3'),
                'a0000000-0000-0000-0000-000000000020'::uuid, 'answer stamped with author');
select tests.ok(exists (select 1 from audit_log where entity_type = 'spec_item' and action = 'update'), 'audited');
