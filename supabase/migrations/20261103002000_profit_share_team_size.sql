-- Profit share: the short-day minimum ($1,500 under 18 team hours) applies to a team of 2 or more.
-- That size becomes a plan value like the others, so the admin can change it.
update public.app_setting
   set value = value || '{"small_team_min_crew": 2}'::jsonb
 where key = 'profit_share_plan' and not value ? 'small_team_min_crew';
