-- Client answers on the profit share (Nov 12):
-- 1. Training day: the trainer's removed hours (up to 3) also come off revenue per hour, so a
--    training route has a better chance to qualify.
-- 2. Recruits: their share is calculated (at Wingman's %) but paid to the trainer, as an incentive.
--    Dispatch chooses who the trainer is on the route.
-- 3. Damages: no longer cancel the route's profit share. The share of the person who caused the
--    damage is still calculated, then held back to pay for the repair instead of going to payroll.
--    Dispatch marks the person.

update public.app_setting
   set value = value || '{"training_hours_off_revenue_per_hour": true}'::jsonb
 where key = 'profit_share_plan';

alter table public.rank
  add column share_to_trainer boolean not null default false;
comment on column public.rank.share_to_trainer is
  'Profit share is calculated with this rank''s % but paid to the route''s trainer (Recruit)';

update public.rank
   set share_pct_high_cogs = 1, share_pct_mid_cogs = 2, share_pct_low_cogs = 3, share_to_trainer = true
 where code = 'recruit';

alter table public.shift_crew_member
  add column trainer boolean not null default false,
  add column damage_hold boolean not null default false;
comment on column public.shift_crew_member.trainer is
  'The trainer on this route (set by dispatch): receives the share of Recruits on the route';
comment on column public.shift_crew_member.damage_hold is
  'Caused damage (set by dispatch): this person''s profit share is held back for the repair';

-- One trainer per route. (Only staff write shift_crew_member, so the crew can't set either flag.)
create unique index shift_crew_member_one_trainer on public.shift_crew_member (shift_id) where trainer;

comment on column public.shift.damages is
  'No longer used (Nov 12): damages are per person, see shift_crew_member.damage_hold. Kept for crew app 0.1.0.';
