-- Tickets start empty: the copies of the old Projet items are removed (asked by Khalil on
-- Nov 11, 2026). The items themselves stay in spec_item, unchanged.
-- A copy someone has already commented on or changed is kept.

delete from public.ticket t
where t.spec_ref is not null
  and not exists (select 1 from public.ticket_comment c where c.ticket_id = t.ticket_id and c.author_id is not null);

-- Numbering carries on from the tickets that remain, so the first new ticket is #1 when none do.
select setval(pg_get_serial_sequence('public.ticket', 'number'),
              coalesce((select max(number) from public.ticket), 0) + 1, false);
