-- test: tickets start empty; the Projet items stay in spec_item
select tests.eq((select count(*) from ticket), 0::bigint, 'no copied tickets');
select tests.ok((select count(*) from spec_item) > 60, 'spec items kept');

-- test: dispatch files a ticket; reporter comes from the session, not the browser
select tests.login('a0000000-0000-0000-0000-000000000010');
insert into ticket (type, title) values ('question', 'First ticket');
reset role;
select tests.eq((select number from ticket where title = 'First ticket'), 1, 'numbering starts at 1');
select tests.login('a0000000-0000-0000-0000-000000000010');
insert into ticket (type, title, description, priority, area, reporter_email, reporter_name)
values ('bug', 'The board does not load', 'Blank page', 'high', 'board', 'someone@else.ca', 'Someone else');
reset role;
select tests.eq((select reporter_id from ticket where title = 'The board does not load'),
                'a0000000-0000-0000-0000-000000000010'::uuid, 'reporter is the signed-in user');
select tests.ok((select reporter_email from ticket where title = 'The board does not load') <> 'someone@else.ca', 'email not taken from the browser');

-- test: crew cannot see or file tickets
select tests.login('a0000000-0000-0000-0000-000000000001');
select tests.eq((select count(*) from ticket), 0::bigint, 'crew sees nothing');
select tests.throws($$insert into ticket (type, title) values ('bug', 'Crew ticket')$$, '%row-level security%');
reset role;

-- test: closing stamps the date and writes the trail; reopening clears it; comments bump activity
select tests.login('a0000000-0000-0000-0000-000000000010');
insert into ticket (type, title) values ('suggestion', 'Show tips on the board');
update ticket set status = 'done' where title = 'Show tips on the board';
reset role;
select tests.ok((select resolved_at from ticket where title = 'Show tips on the board') is not null, 'closed date');
select tests.ok(exists (select 1 from ticket_comment c join ticket t using (ticket_id)
                        where t.title = 'Show tips on the board' and c.kind = 'event'
                          and c.event_field = 'status' and c.event_from = 'new' and c.event_to = 'done'
                          and c.author_id = 'a0000000-0000-0000-0000-000000000010'), 'status change in the trail');
select tests.login('a0000000-0000-0000-0000-000000000020');
update ticket set status = 'in_progress' where title = 'Show tips on the board';
insert into ticket_comment (ticket_id, body)
select ticket_id, 'Working on it' from ticket where title = 'Show tips on the board';
reset role;
select tests.ok((select resolved_at from ticket where title = 'Show tips on the board') is null, 'reopened');
select tests.eq((select author_id from ticket_comment where body = 'Working on it'),
                'a0000000-0000-0000-0000-000000000020'::uuid, 'comment author from the session');

-- test: nobody fakes a trail entry or deletes a ticket
select tests.login('a0000000-0000-0000-0000-000000000020');
insert into ticket (type, title) values ('bug', 'Something');
select tests.throws($$insert into ticket_comment (ticket_id, kind, event_field, event_to)
                      select ticket_id, 'event', 'status', 'done' from ticket limit 1$$, '%row-level security%');
select tests.throws($$delete from ticket$$, '%permission denied%');
