-- Truck Team OS: the business calls a truck's day a "route" (Daily Route Journal), not a "shift".
-- Only the wording people read changes; tables, columns and error codes keep the name `shift`.
-- Client answers are kept as they were written.

create function pg_temp.route_words(t text) returns text language sql immutable as $$
  select regexp_replace(regexp_replace(t, '\mshift(s?)\M', 'route\1', 'g'), '\mShift(s?)\M', 'Route\1', 'g')
$$;

update public.spec_item
   set title = pg_temp.route_words(title),
       detail = pg_temp.route_words(detail),
       area = pg_temp.route_words(area),
       blocks = pg_temp.route_words(blocks),
       build_default = pg_temp.route_words(build_default);
