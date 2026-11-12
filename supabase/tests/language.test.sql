-- test: each person saves their own language, crew included
select tests.login('a0000000-0000-0000-0000-000000000001');
select public.set_my_language('en');
select tests.eq((select language from app_user where user_id = 'a0000000-0000-0000-0000-000000000001'), 'en', 'crew reads it back');
reset role;
select tests.login('a0000000-0000-0000-0000-000000000010');
select public.set_my_language('fr');
reset role;
select tests.eq((select language from app_user where user_id = 'a0000000-0000-0000-0000-000000000010'), 'fr', 'dispatcher');
select tests.eq((select language from app_user where user_id = 'a0000000-0000-0000-0000-000000000001'), 'en', 'others unchanged');

-- test: only fr or en, and nothing else about the account changes
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.throws($$select public.set_my_language('es')$$, 'not_allowed%');
update app_user set language = 'fr', role = 'admin' where user_id = 'a0000000-0000-0000-0000-000000000001';
reset role;
select tests.eq((select role::text from app_user where user_id = 'a0000000-0000-0000-0000-000000000001'), 'ttm', 'role unchanged');
select tests.eq((select language from app_user where user_id = 'a0000000-0000-0000-0000-000000000001'), null::text, 'direct edits do nothing');
