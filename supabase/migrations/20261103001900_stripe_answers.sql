-- Projet page: what Stripe itself shows (read-only key, payments of Oct 25, 2026 compared with
-- the three filled route sheets: all 20 card jobs match to the cent). Answers F8 and F9, and
-- adds to the client's earlier answers to F1 and F2.

update public.spec_item set status = 'answered', answered_at = now(),
  answer = coalesce(spec_item.answer || E'\n\n', '') || v.answer
from (values
  ('F1', $s$Checked with the read-only key (Nov 3): payments belong to HQ's Stripe platform (they carry its application ID), and a restricted read-only key on Montréal's account works.$s$),
  ('F2', $s$Checked in Stripe (Nov 3): every payment carries opportunity_id, tip, username (the HQ app login of the crew member who took it), source (gj-ttm-service, the HQ crew app) and card_method_type (terminal or manual). The amount is the total with tax plus the tip. Tax and the pre-tax amount are not in the metadata; pre-tax = (amount − tip) ÷ 1.14975. Failed attempts appear too and are retried; only succeeded payments count.$s$),
  ('F8', $s$From Stripe (Nov 3): each payment's username is the HQ app login of the crew member who took it. With the day's crew list, that gives the route and its crew with no manual input. Card readers don't work for this: many cards are typed in (no reader), and one route used two logins and two readers. Needed: each employee's HQ login stored in the system. Cash jobs never reach Stripe.$s$),
  ('F9', $s$Stripe only, as far as the data shows: every card job on the Oct 25 route sheets is in Stripe, and the "Helcim Invoice #" column is empty on all three sheets.$s$)
) as v(ref, answer)
where spec_item.ref = v.ref;
