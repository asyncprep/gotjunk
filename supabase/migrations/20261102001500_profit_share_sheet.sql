-- Projet page: answers from the client's paper "Profit Share" sheet (August 2024 version, received
-- Nov 2, 2026), plus the follow-up questions it raises. Formula written out in docs/profit-share.md.

update public.spec_item set status = 'answered', answered_at = now(), answer = v.answer
from (values
  ('R1', $s$Both: the % depends on the employee's rank AND on the route's COGS % band (profit-share sheet).$s$),
  ('A1', $s$The sheet uses COGS %, not gross margin. COGS = wages (team hours × $26) + dumps (dump costs − donation credits) + franchise fees (16% of revenue) + fuel (4% of revenue; 5.5% on a split day; 7% for 2 trucks) + swing truck fee ($60 per truck). COGS % = COGS ÷ revenue.$s$),
  ('A2', $s$A flat rate: $26 × total team hours. Not from Ceridian.$s$),
  ('A3', $s$Not actual fuel: a % of the route's revenue (4%; 5.5% on a split day; 7% for 2 trucks).$s$),
  ('A4', $s$COGS must be 50.00% or less. Bands: 47.01–50.00%, 43.01–47.00%, under 43.00%. Also minimum revenue $2,000 and at least $135 revenue per hour ($1,500 minimum if the team works under 18 hours in total, team of 2 or more).$s$),
  ('A5', $s$Per crew member, % × route revenue: Wingman 1% / 2% / 3%; Professional 2% / 3% / 4%; Expert & JR Coach 3% / 4% / 5% (for COGS 47.01–50%, 43.01–47%, under 43%). Trainer is not a rank: on a training day the trainer can remove up to 3 hours from the calculation, and the route then needs $1,500 revenue and $125 per hour.$s$),
  ('A8', $s$Yes: dumps count as dump costs minus credits. Accepted donations to Éco-Dépôt give a credit of $75 per 1,000 kg.$s$),
  ('A9', $s$Yes: minimum revenue and revenue per hour (see A4); paperwork completely filled out and no damages; all company policies respected; donations never dumped in the garbage. The sheet also shows RPH = revenue ÷ team hours, cancel rate = cancels ÷ jobs and AJS = revenue ÷ jobs.$s$)
) as v(ref, answer)
where spec_item.ref = v.ref;

update public.spec_item set detail = $s$The profit-share sheet has a Junk / Warehouse / Non-Junk column per person but no rule saying which hours count.$s$
 where ref = 'A6' and detail is null;

insert into public.spec_item (kind, ref, area, priority, title, detail, blocks, build_default, sort_order) values
('question', 'A10', 'Profit share', 'v1b',
 $s$Is the August 2024 profit-share sheet still current?$s$,
 $s$Check each value: $26 per hour, franchise fees 16%, fuel 4% / 5.5% / 7%, swing truck fee $60, minimums $2,000 and $135 per hour ($1,500 under 18 team hours; $1,500 and $125 with a trainer), COGS bands 43% / 47% / 50%, and the % per rank.$s$,
 $s$Profit-share engine$s$, $s$Values from the August 2024 sheet, stored as settings that can change$s$, 291),
('question', 'A11', 'Profit share', 'v1b',
 $s$What counts as a "split day" (fuel 5.5%) and "2 trucks" (fuel 7%), and when is the $60 swing truck fee charged?$s$,
 null, $s$Fuel and truck costs$s$, $s$4% fuel and no swing fee unless dispatch marks the route$s$, 292),
('question', 'A12', 'Profit share', 'v1b',
 $s$Which ranks exist, and do Recruits get a profit share?$s$,
 $s$The sheet lists Wingman, Professional, and "Expert & JR Coach" (same %). Recruit is not on it. Are Expert and JR Coach two ranks or one?$s$,
 $s$Rank list, profit-share engine$s$, $s$Recruit gets no profit share; Expert and JR Coach are separate ranks with the same %$s$, 293),
('question', 'A13', 'Profit share', 'v1b',
 $s$How are the trainer's 3 hours removed, and who records damages?$s$,
 $s$Are the 3 hours taken off the team hours for both wages and revenue per hour? Is it the trainer's hours only? Rule #4 needs "no damages": who records a damage, and does it cancel the whole team's profit share for that route?$s$,
 $s$Profit-share eligibility$s$, $s$Dispatch marks a training route and a damage on the route page$s$, 294)
on conflict (ref) do nothing;
