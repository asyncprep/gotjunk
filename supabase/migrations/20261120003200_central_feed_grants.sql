-- The central-tickets Edge Function reads and writes as service_role, which has no table rights in
-- this project (they are granted per table, to authenticated). Without these the feed answers 500
-- "permission denied for table ticket". Only what the function uses: read tickets, comments and
-- the people Central can wait on; change a ticket's status; add a comment.
grant select, update on public.ticket to service_role;
grant select, insert on public.ticket_comment to service_role;
grant select on public.app_user, public.employee to service_role;
