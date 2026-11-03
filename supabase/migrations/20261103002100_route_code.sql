-- The route's name on dispatch's daily tracker (C1, E1, RN W1…), so a pasted tracker finds the
-- route it already created. Set by dispatch; the crew can't change it (not in the crew's list).

alter table public.shift add column route_code text check (route_code is null or length(trim(route_code)) > 0);
comment on column public.shift.route_code is 'Route name on dispatch''s daily tracker (C1, E1…)';
create index on public.shift (shift_date, route_code);
