-- test: senior ops changes the role of another login, both ways
select tests.login('a0000000-0000-0000-0000-000000000020');
update app_user set role = 'senior_ops' where user_id = 'a0000000-0000-0000-0000-000000000010';
select tests.eq((select role::text from app_user where user_id = 'a0000000-0000-0000-0000-000000000010'), 'senior_ops', 'dispatcher made senior ops');
update app_user set role = 'dispatcher' where user_id = 'a0000000-0000-0000-0000-000000000010';
select tests.eq((select role::text from app_user where user_id = 'a0000000-0000-0000-0000-000000000010'), 'dispatcher', 'back to dispatcher');
reset role;

-- test: a crew login becomes a dispatcher and keeps its employee
select tests.login('a0000000-0000-0000-0000-000000000020');
update app_user set role = 'dispatcher' where user_id = 'a0000000-0000-0000-0000-000000000003';
reset role;
select tests.eq((select role::text || ' ' || employee_id::text from app_user where user_id = 'a0000000-0000-0000-0000-000000000003'),
  'dispatcher b0000000-0000-0000-0000-000000000003', 'crew to dispatcher, still linked');

-- test: a crew role needs a linked employee
select tests.login('a0000000-0000-0000-0000-000000000020');
select tests.throws($q$
  update app_user set role = 'ttm' where user_id = 'a0000000-0000-0000-0000-000000000010'
$q$, '%check constraint%');
reset role;

-- test: configuration rights are cleared when senior ops gets another role
insert into auth.users (id) values ('a0000000-0000-0000-0000-000000000040'), ('a0000000-0000-0000-0000-000000000041');
insert into app_user (user_id, role, can_edit_config) values
  ('a0000000-0000-0000-0000-000000000040', 'senior_ops', true),
  ('a0000000-0000-0000-0000-000000000041', 'admin', false);
select tests.login('a0000000-0000-0000-0000-000000000020');
update app_user set role = 'dispatcher' where user_id = 'a0000000-0000-0000-0000-000000000040';
update app_user set role = 'senior_ops' where user_id = 'a0000000-0000-0000-0000-000000000040';
reset role;
select tests.eq((select can_edit_config from app_user where user_id = 'a0000000-0000-0000-0000-000000000040'), false, 'rights not back');

-- test: senior ops cannot give or take admin, nor change their own role
insert into auth.users (id) values ('a0000000-0000-0000-0000-000000000040'), ('a0000000-0000-0000-0000-000000000041');
insert into app_user (user_id, role, can_edit_config) values
  ('a0000000-0000-0000-0000-000000000040', 'senior_ops', true),
  ('a0000000-0000-0000-0000-000000000041', 'admin', false);
select tests.login('a0000000-0000-0000-0000-000000000020');
select tests.throws($q$
  update app_user set role = 'admin' where user_id = 'a0000000-0000-0000-0000-000000000010'
$q$, 'not_allowed: only an admin%');
select tests.throws($q$
  update app_user set role = 'senior_ops' where user_id = 'a0000000-0000-0000-0000-000000000041'
$q$, 'not_allowed: only an admin%');
select tests.throws($q$
  update app_user set role = 'dispatcher' where user_id = 'a0000000-0000-0000-0000-000000000020'
$q$, 'not_allowed: you cannot change your own access');
reset role;

-- test: an admin gives admin; a dispatcher changes no role
insert into auth.users (id) values ('a0000000-0000-0000-0000-000000000040'), ('a0000000-0000-0000-0000-000000000041');
insert into app_user (user_id, role, can_edit_config) values
  ('a0000000-0000-0000-0000-000000000040', 'senior_ops', true),
  ('a0000000-0000-0000-0000-000000000041', 'admin', false);
select tests.login('a0000000-0000-0000-0000-000000000041');
update app_user set role = 'admin' where user_id = 'a0000000-0000-0000-0000-000000000010';
reset role;
select tests.eq((select role::text from app_user where user_id = 'a0000000-0000-0000-0000-000000000010'), 'admin', 'admin gives admin');
select tests.login('a0000000-0000-0000-0000-000000000002');
update app_user set role = 'senior_ops' where user_id = 'a0000000-0000-0000-0000-000000000040';
reset role;
select tests.eq((select role::text from app_user where user_id = 'a0000000-0000-0000-0000-000000000040'), 'senior_ops', 'crew changes nothing');
select tests.eq((select count(*)::int from audit_log where entity_type = 'app_user' and action = 'update'
                 and entity_id::text = 'a0000000-0000-0000-0000-000000000010' and field_changes ? 'role'), 1, 'role change audited');
