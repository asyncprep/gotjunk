-- Truck Team OS: specification tracker (admin "Projet" page)
-- Inconsistencies found in the product spec (v0.3) and the questions to settle with the client,
-- with their status and the client's answers. Content is loaded below; the admin app edits it.

create table public.spec_item (
  item_id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('inconsistency', 'question')),
  ref text not null unique,
  area text not null,
  priority text not null default 'pilot' check (priority in ('blocker', 'pilot', 'v1b', 'info')),
  title text not null,
  detail text,
  spec_refs text,
  blocks text,
  build_default text,
  status text not null default 'open' check (status in ('open', 'asked', 'answered', 'resolved', 'deferred')),
  answer text,
  answered_by uuid,
  answered_at timestamptz,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create index on public.spec_item (kind, sort_order);

-- Recording an answer stamps who recorded it and when.
create function public.spec_item_answer_stamp() returns trigger
language plpgsql as $$
begin
  if new.answer is distinct from (case when tg_op = 'UPDATE' then old.answer end)
     and coalesce(trim(new.answer), '') <> '' then
    new.answered_at := now();
    new.answered_by := auth.uid();
  end if;
  return new;
end $$;

create trigger spec_item_answer
  before insert or update on public.spec_item
  for each row execute function public.spec_item_answer_stamp();

create trigger spec_item_row_audit
  before insert or update on public.spec_item
  for each row execute function public.set_row_audit_columns();

create trigger spec_item_z_audit
  after insert or update or delete on public.spec_item
  for each row execute function public.write_audit_log('item_id');

alter table public.spec_item enable row level security;
create policy spec_read on public.spec_item for select to authenticated using (public.is_staff());
create policy spec_write on public.spec_item for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
grant select, insert, update, delete on public.spec_item to authenticated;

-- ---------------------------------------------------------------------------
-- Inconsistencies in "Truck Team OS – Product Specification" (file named v0.1, content v0.3)
-- ---------------------------------------------------------------------------

insert into public.spec_item (kind, ref, area, priority, title, detail, spec_refs, blocks, build_default, sort_order) values
('inconsistency', 'I-01', 'Document', 'info',
 $s$Version number doesn't match$s$,
 $s$The file is named v0.1 but the content says v0.3. The change log has v0.2 and v0.3 (both dated Oct 26, 2026) and no v0.1 entry.$s$,
 $s$Title page; change log$s$,
 $s$Confusion about which version was approved$s$,
 $s$Treat v0.3 as current; ask the client to rename the file and date each version$s$, 10),

('inconsistency', 'I-02', 'Profit share', 'v1b',
 $s$Profit-share % by rank or by margin tier?$s$,
 $s$§6.9 says each eligible employee gets their rank's % × the shift's qualifying revenue. §9 asks the dashboard to show a "profit-share tier/percentage" and "progress toward next tier", which implies tiers based on gross margin.$s$,
 $s$§6.9, §9, §15-A$s$,
 $s$Profit-share engine, scoreboard, Plan Rank Rate table shape$s$,
 $s$Not built; scoreboard shows revenue and tips only (question R1)$s$, 20),

('inconsistency', 'I-03', 'Jobs', 'pilot',
 $s$Crew must re-enter payment data — or must not?$s$,
 $s$§6.2 makes pre-tax revenue, total with tax and tip required crew entries. WF-002 says not to make the field team re-enter payment or tip data the approved source can provide. Stripe may not provide pre-tax amounts, discounts or tips (§3A), so the crew probably has to enter them in V1.$s$,
 $s$§6.2, WF-002, §3A$s$,
 $s$Job form, reconciliation design$s$,
 $s$Crew enters the amounts in V1; they become references once Stripe data is available$s$, 30),

('inconsistency', 'I-04', 'Disposal', 'v1b',
 $s$Manual disposal entries vs scale data: no matching rule$s$,
 $s$WF-004 has the crew enter weights by hand. §6.11 says scale data is imported and costs must never be counted twice, but no key is defined to match a manual ticket to a scale event (ticket number? truck + time window?). It's also unclear which sites have the internal scales.$s$,
 $s$WF-004, §6.4, §6.11$s$,
 $s$Scale import, double-counting protection$s$,
 $s$Manual entries only in V1 (question R2 needs a scale export sample)$s$, 40),

('inconsistency', 'I-05', 'Disposal', 'pilot',
 $s$Minimum billable weight applied to credits?$s$,
 $s$The half-ton minimum (§6.5) makes sense for costs. If it also applied to donation credits, a 100 kg donation would earn a 500 kg credit. The spec doesn't say.$s$,
 $s$§6.5, §6.6, §6.11$s$,
 $s$Disposal pricing$s$,
 $s$Minimums apply to costs only; credits use actual weight (question R3c)$s$, 50),

('inconsistency', 'I-06', 'Disposal', 'pilot',
 $s$"Ton" vs metric tonne$s$,
 $s$Rates are quoted per "ton" but §6.11 divides kilograms by 1,000 (metric tonnes). A short ton is 907 kg; the difference is about 10% on every disposal cost.$s$,
 $s$§6.5, §6.11$s$,
 $s$Disposal pricing, profit share$s$,
 $s$Metric tonne (question R3a)$s$, 60),

('inconsistency', 'I-07', 'Shifts', 'info',
 $s$Status list incomplete$s$,
 $s$§6.1 lists Open / Submitted / Locked / Reopened / Reconciled / Archived. WF-001 sets "Open/In Progress" and WF-006 has "Return for Correction", neither of which is in the list.$s$,
 $s$§6.1, WF-001, WF-006$s$,
 $s$Shift workflow$s$,
 $s$Built with In Progress and Returned added$s$, 70),

('inconsistency', 'I-08', 'Crew', 'pilot',
 $s$Crew changes mid-shift not supported by the data model$s$,
 $s$§11 lists "crew changes during the day" as a failure mode to design for, but §6.1 stores the crew at shift level only. Tip splits and individual profit share need to know who was present for each job.$s$,
 $s$§6.1, §6.8, §11$s$,
 $s$Tip split, profit share$s$,
 $s$Crew members have joined/left times; tips go to crew present when the job is completed (question R4)$s$, 80),

('inconsistency', 'I-09', 'Jobs', 'pilot',
 $s$Duplicate Opportunity IDs treated as errors$s$,
 $s$§11 treats a duplicate Opportunity ID as a failure, but the same opportunity can legitimately appear again (return visit, cancelled then rebooked).$s$,
 $s$§6.2, §11$s$,
 $s$Job validation$s$,
 $s$Unique per shift; a repeat on another shift is a warning (question R5)$s$, 90),

('inconsistency', 'I-10', 'Systems', 'info',
 $s$Pipeline and the HQ app merged in §8$s$,
 $s$§8 is titled "Pipeline / Corporate Salesforce Truck Team App", treating them as one system, while §3A takes care to separate HQ's Truck Team app from Pipeline.$s$,
 $s$§3A, §8$s$,
 $s$Integration planning$s$,
 $s$Treated as two systems; the spec should be corrected$s$, 100),

('inconsistency', 'I-11', 'Payments', 'v1b',
 $s$Stripe access "confirmed" but not verified$s$,
 $s$§3A and §8 say Montréal's independent Stripe access is CONFIRMED, while §8A says API read rights, webhooks and the Opportunity ID join key still need verification. Dashboard access doesn't prove API or webhook rights, especially if the account is a Connect account under HQ.$s$,
 $s$§3A, §8, §8A$s$,
 $s$Stripe ingestion$s$,
 $s$Not built; questions F1 and F2$s$, 110),

('inconsistency', 'I-12', 'Scope', 'pilot',
 $s$V1 scope depends on open items$s$,
 $s$§13 puts the live profit-share dashboard, scale import and roster ranks in V1, but their inputs (formula, thresholds, rank %, scale data format, roster source) are all open items in §15.$s$,
 $s$§13, §15-A, §15-F$s$,
 $s$V1 delivery date$s$,
 $s$V1 split: V1a = journal replacement (built); V1b = integrations and profit share after answers$s$, 120),

('inconsistency', 'I-13', 'Technology', 'info',
 $s$Spec says web app (PWA); a native app was chosen$s$,
 $s$§3 and §4 call for a mobile-first web app installable on iPhone. Offline needs (§11) led to a native Flutter app, Android first, iOS after the Apple account. The spec should be updated.$s$,
 $s$§3, §4, §11$s$,
 $s$Stack decision sign-off$s$,
 $s$Flutter crew app + React admin + Supabase (Canada); see the stack decision document$s$, 130),

('inconsistency', 'I-14', 'Offline', 'blocker',
 $s$Offline is required before production but undefined$s$,
 $s$§11 says poor/no signal must be handled before production, yet how long the app must work offline is still open item G.$s$,
 $s$§11, §15-G$s$,
 $s$Offline sync design, photo handling$s$,
 $s$Designed for a full shift offline (question G)$s$, 140),

('inconsistency', 'I-15', 'Compliance', 'pilot',
 $s$No French-language or privacy requirements$s$,
 $s$The spec never mentions language. In Québec, the Charter of the French Language (Bill 96) generally requires workplace software in French, and Law 25 applies to employee data and photos (retention, privacy officer). Neither is in the spec.$s$,
 $s$Whole document$s$,
 $s$Rollout, data retention$s$,
 $s$French by default with English available; photo retention not set yet (question P2)$s$, 150),

('inconsistency', 'I-16', 'Jobs', 'pilot',
 $s$Is "revenue before tax" before or after the discount?$s$,
 $s$§6.2 asks for a discount, revenue before tax and total with tax, but doesn't say whether the pre-tax amount is net of the discount. This changes revenue, the tax check and profit share.$s$,
 $s$§6.2$s$,
 $s$Revenue totals, tax check$s$,
 $s$Pre-tax revenue is net of discount (question J4)$s$, 160),

('inconsistency', 'I-17', 'Cash', 'info',
 $s$Expected cash has no independent source$s$,
 $s$§6.7 calculates expected cash from the crew's own payment-method entries. Cash never goes through Stripe, so the dispatcher's physical count is the only check. This is acceptable but should be stated as a known limit.$s$,
 $s$§6.7$s$,
 $s$Cash reconciliation$s$,
 $s$Variance requires a written explanation before lock (question C3)$s$, 170);

-- ---------------------------------------------------------------------------
-- Questions for the client
-- ---------------------------------------------------------------------------

insert into public.spec_item (kind, ref, area, priority, title, blocks, build_default, sort_order) values
-- Approvals and setup
('question', 'S1', 'Approvals', 'blocker', $s$Do you approve the technology stack (Flutter crew app, React admin web app, Supabase hosted in Canada)?$s$, $s$All further development$s$, $s$Proceeding as recommended$s$, 10),
('question', 'S2', 'Approvals', 'blocker', $s$Are the crew phones company-owned? iPhone, Android, or both?$s$, $s$App build and distribution$s$, $s$Android first, iOS once the Apple account is ready$s$, 20),
('question', 'E', 'Shifts', 'blocker', $s$Does dispatch create truck/phone/crew assignments in Truck Team OS, or do they come from the Daily Tracker?$s$, $s$Assignment screens, sync$s$, $s$Dispatch creates them in the admin app$s$, 30),
('question', 'G', 'Offline', 'blocker', $s$How long must the app keep working without signal before crews are blocked?$s$, $s$Offline design, photo uploads$s$, $s$A full shift offline$s$, 40),
('question', 'S5', 'Approvals', 'blocker', $s$Who signs the stack decision and approves vendor costs?$s$, $s$Account upgrades, pilot$s$, null, 50),
('question', 'S6', 'Approvals', 'pilot', $s$Who will own the accounts (Apple/Google developer, Supabase, PowerSync, Vercel, GitHub)? Ideally the business, with us as collaborators.$s$, $s$Handover, billing$s$, $s$Currently under the developer's accounts$s$, 60),
('question', 'S8', 'Approvals', 'pilot', $s$Do you approve upgrading hosting to paid plans before the pilot (Vercel Pro ~US$20/month; Supabase Pro ~US$25/month for backups)?$s$, $s$Commercial use of the admin app, daily backups$s$, $s$Free plans during development$s$, 70),
('question', 'S4', 'Approvals', 'pilot', $s$Does headquarters need to approve a locally built app, its name, or its use of the 1-800-GOT-JUNK? brand? Can you provide the official logo files?$s$, $s$Branding, distribution$s$, $s$Brand colours and a typed wordmark; logo slot empty$s$, 80),
('question', 'S9', 'Approvals', 'pilot', $s$Which email address and provider should send invitations and password resets (e.g. an @1800gotjunk or company domain)?$s$, $s$Inviting the whole team$s$, $s$Supabase's built-in sender (a few emails per hour)$s$, 90),
('question', 'S3', 'Devices', 'pilot', $s$Is a device management (MDM) tool in place for the company phones?$s$, $s$App installation, lost-phone wipe$s$, null, 100),
('question', 'S7', 'Approvals', 'pilot', $s$Who maintains the system after launch?$s$, $s$Support plan$s$, null, 110),

-- Profit share
('question', 'R1', 'Profit share', 'v1b', $s$Is the profit-share % set by the employee's rank, by a gross-margin tier, or both?$s$, $s$Profit-share engine$s$, null, 200),
('question', 'A1', 'Profit share', 'v1b', $s$What is the exact gross-margin formula, and which costs count (wages, fuel, disposal)?$s$, $s$Profit-share engine$s$, null, 210),
('question', 'A2', 'Profit share', 'v1b', $s$Where do wage costs come from (Ceridian, a rate table), and at what rate?$s$, $s$Profit-share engine$s$, null, 220),
('question', 'A3', 'Profit share', 'v1b', $s$Where do fuel costs come from, and how are they assigned to a shift?$s$, $s$Profit-share engine$s$, null, 230),
('question', 'A4', 'Profit share', 'v1b', $s$What gross-margin threshold(s) must a shift meet to qualify?$s$, $s$Profit-share engine$s$, null, 240),
('question', 'A5', 'Profit share', 'v1b', $s$What are the ranks and their revenue-share %? Is Trainer a rank or an extra role?$s$, $s$Profit-share engine, roster$s$, $s$Ranks: Recruit, Wingman, Sales Professional, Trainer (to confirm)$s$, 250),
('question', 'A6', 'Profit share', 'v1b', $s$Which hours types are eligible for profit share (Regular Junk, Warehouse, Non-Junk)?$s$, $s$Profit-share eligibility$s$, null, 260),
('question', 'A7', 'Profit share', 'v1b', $s$Can you provide 2–3 worked examples from real shifts, including a crew with different ranks?$s$, $s$Testing the engine$s$, null, 270),
('question', 'A8', 'Profit share', 'v1b', $s$Do scale costs/credits count in the current plan? Could disposal be removed in a future plan?$s$, $s$Profit-share engine$s$, $s$Disposal stored separately so either works$s$, 280),
('question', 'A9', 'Profit share', 'v1b', $s$Are there other criteria (minimum revenue per hour, Res AJS)?$s$, $s$Profit-share engine$s$, null, 290),

-- Tips and cash
('question', 'B1', 'Tips', 'pilot', $s$Confirm tips are split equally among the crew on the job.$s$, $s$Tip split$s$, $s$Equal split; leftover cents to the first crew member$s$, 300),
('question', 'B2', 'Tips', 'pilot', $s$When can the tip split be overridden, and who approves?$s$, $s$Tip overrides$s$, $s$No overrides$s$, 310),
('question', 'B3', 'Tips', 'v1b', $s$What format does payroll need for tips?$s$, $s$Payroll export$s$, null, 320),
('question', 'B4', 'Cash', 'pilot', $s$Do cash tips go in the cash envelope (count in expected cash)?$s$, $s$Expected cash$s$, $s$Yes$s$, 330),
('question', 'C1', 'Cash', 'pilot', $s$What format should the cash envelope identifier have?$s$, $s$Cash handoff$s$, $s$Free text entered by dispatch$s$, 340),
('question', 'C2', 'Cash', 'pilot', $s$Who physically receives and stores the cash envelope?$s$, $s$Cash handoff$s$, $s$Recorded as "received by" the dispatcher$s$, 350),
('question', 'C3', 'Cash', 'pilot', $s$What happens when counted cash doesn't match expected cash?$s$, $s$Shift acceptance$s$, $s$A written explanation is required before lock$s$, 360),
('question', 'D1', 'Dispatch', 'pilot', $s$What is the full end-of-day checklist (keys, phone, tools, truck state…), and which items are mandatory?$s$, $s$Shift acceptance$s$, $s$Spec WF-006 items, all mandatory; editable in Configuration$s$, 370),

-- Disposal
('question', 'R3a', 'Disposal', 'pilot', $s$Are Eco-Junk and dump rates per metric tonne (1,000 kg) or per short ton?$s$, $s$Disposal pricing$s$, $s$Metric tonne$s$, 400),
('question', 'R3b', 'Disposal', 'pilot', $s$Does Eco-Junk have minimum billable weights? Per weigh-in or per visit?$s$, $s$Disposal pricing$s$, $s$No minimum at Eco-Junk; 500 kg at outside dumps$s$, 410),
('question', 'R3c', 'Disposal', 'pilot', $s$Does a minimum ever apply to donation credits?$s$, $s$Disposal pricing$s$, $s$Never$s$, 420),
('question', 'R3d', 'Disposal', 'pilot', $s$Which outside dumps are used, and what are their rates and minimums?$s$, $s$Site and rate setup$s$, $s$One generic "outside dump" at $160/t, 500 kg minimum$s$, 430),
('question', 'R2', 'Disposal', 'v1b', $s$On a scale record, is the disposal ticket number present, so it can be matched to the crew's ticket?$s$, $s$Scale import$s$, null, 440),

-- Jobs, shifts and crews
('question', 'J3', 'Jobs', 'pilot', $s$What cancellation reasons does dispatch use?$s$, $s$Cancellation finalization$s$, $s$Placeholders: price declined, customer absent, items not as described, other$s$, 500),
('question', 'J2', 'Jobs', 'pilot', $s$What is the full list of payment methods (cash, card, cheque, invoice/account, e-transfer…)?$s$, $s$Job entry, expected cash$s$, $s$Cash, Card$s$, 510),
('question', 'J4', 'Jobs', 'pilot', $s$Is "revenue before tax" entered after the discount?$s$, $s$Revenue totals$s$, $s$Yes, net of discount$s$, 520),
('question', 'J5', 'Jobs', 'pilot', $s$Are there tax-exempt jobs or other tax rates?$s$, $s$Tax check$s$, $s$GST + QST 14.975%, warning only$s$, 530),
('question', 'J1', 'Jobs', 'pilot', $s$What is the Opportunity ID format (Salesforce 15/18 characters, job number)?$s$, $s$Job validation$s$, $s$Any text up to 40 characters$s$, 540),
('question', 'R5', 'Jobs', 'pilot', $s$When can the same Opportunity ID appear on two shifts (return visit, rebooking)?$s$, $s$Job validation$s$, $s$Allowed with a warning$s$, 550),
('question', 'R4', 'Crew', 'pilot', $s$When the crew changes mid-shift, how are tips and profit share split (by time, by job)?$s$, $s$Tip split, profit share$s$, $s$Crew present when the job is completed$s$, 560),
('question', 'H1', 'Crew', 'pilot', $s$Can a crew ever be one person or four people?$s$, $s$Shift submission$s$, $s$2–3 people required to submit$s$, 570),
('question', 'H2', 'Shifts', 'pilot', $s$Can one truck run two shifts on the same day?$s$, $s$Shift creation$s$, $s$One active shift per truck per day$s$, 580),
('question', 'H3', 'Shifts', 'pilot', $s$Should shift hours use Ceridian's 15-minute rounding, or only in reconciliation?$s$, $s$Hours totals$s$, $s$Exact times; rounding only in reconciliation$s$, 590),

-- Data sources and integrations
('question', 'F1', 'Integrations', 'v1b', $s$Can restricted API keys and webhooks be created on Montréal's Stripe account? Is it a Connect account under HQ?$s$, $s$Stripe ingestion$s$, null, 600),
('question', 'F2', 'Integrations', 'v1b', $s$Can we see 5–10 recent Stripe payments? Do they carry an Opportunity ID or job number, tip, tax or discount?$s$, $s$Job ↔ payment matching$s$, null, 610),
('question', 'F3', 'Integrations', 'v1b', $s$Can headquarters provide an export of what crews enter in the HQ app?$s$, $s$Three-way reconciliation$s$, null, 620),
('question', 'F4', 'Integrations', 'v1b', $s$How does Pipeline report data reach Google Sheets today? Are there scheduled exports?$s$, $s$Pipeline reconciliation$s$, null, 630),
('question', 'F5', 'Integrations', 'v1b', $s$Which scales platform is used? Can we get a sample export (truck, crew, materials, weights, IDs)?$s$, $s$Scale import$s$, null, 640),
('question', 'F6', 'Integrations', 'v1b', $s$What is the authoritative employee roster and rank history, and which IDs match Ceridian and the scales?$s$, $s$Roster import$s$, null, 650),
('question', 'F7', 'Integrations', 'v1b', $s$Can we get Ceridian time exports, and in what format?$s$, $s$Time reconciliation$s$, null, 660),

-- Privacy, language, rollout
('question', 'P1', 'Compliance', 'pilot', $s$Confirm French as the default language for crews and dispatch.$s$, $s$Rollout$s$, $s$French by default, English available$s$, 700),
('question', 'P2', 'Compliance', 'pilot', $s$How long should cash and ticket photos be kept? Who is the Law 25 privacy officer?$s$, $s$Data retention$s$, $s$Not set$s$, 710),
('question', 'P4', 'Compliance', 'pilot', $s$If the offline-sync service (PowerSync) has no Canadian region, is a US-hosted copy of crew shift data acceptable for the pilot?$s$, $s$Offline sync setup$s$, $s$Database stays in Canada; sync region to confirm$s$, 720),
('question', 'P3', 'Compliance', 'info', $s$Can the product specification PDF be stored in the code repository?$s$, null, $s$Kept out of the repository$s$, 730),
('question', 'O1', 'Pilot', 'pilot', $s$Which trucks and crews pilot first, and for how long alongside the paper journal?$s$, $s$Pilot plan$s$, null, 800),
('question', 'O2', 'Pilot', 'pilot', $s$Who on your side reviews the app's French wording before rollout?$s$, $s$Rollout$s$, null, 810),
('question', 'O3', 'Pilot', 'pilot', $s$What does a successful pilot look like (reconciliation time, error rate, crew adoption)? Do you have a baseline for current reconciliation time per shift?$s$, $s$Pilot evaluation$s$, null, 820);
