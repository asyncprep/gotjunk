-- A third crew position from the client's tracker (Nov 3): Onboarding, a new hire learning on
-- the route. Still exactly one driver per route; any number of navigators or onboarding members.

alter type public.crew_position add value if not exists 'onboarding';

update public.spec_item set answer = answer || $s$ Update Nov 3: a third position, Onboarding, for a new hire learning on the route.$s$
 where ref = 'S11' and answer not like '%Onboarding%';

insert into public.spec_item (kind, ref, area, priority, title, detail, blocks, build_default, sort_order)
values ('question', 'A15', 'Profit share', 'v1b',
  $s$Does a crew member in Onboarding count in the team hours, and do they get a profit share?$s$,
  $s$The tracker has three positions: Driver, Navigator and Onboarding. Their hours raise wages and lower revenue per hour; their share depends on their rank.$s$,
  $s$Profit-share calculation$s$,
  $s$Their hours count like everyone's, and their share follows their rank (a Recruit gets none)$s$,
  296)
on conflict (ref) do nothing;
