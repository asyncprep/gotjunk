-- Projet page: new client question (Nov 3). Get each truck's jobs for the day out of Pipeline
-- automatically, so Opportunity IDs reach the phone without typing. Truck-to-job assignments
-- live only in Pipeline/HQ (no Daily Tracker).

insert into public.spec_item (kind, ref, area, priority, title, detail, blocks, build_default, sort_order)
values ('question', 'F10', 'Integrations', 'v1b',
  $s$Can dispatch get today's jobs per truck out of Pipeline without typing?$s$,
  $s$For example a Salesforce report (Opportunity ID, truck or crew, address, time) exported to CSV, or emailed automatically each morning. Could we get a sample of that report? Failing that, can HQ give read-only API access to those fields? This adds to F1, F8 and F9.$s$,
  $s$Crew job list filled in automatically$s$,
  $s$The crew picks the day's Stripe payments on the phone (one tap); cash jobs are scanned with the camera$s$,
  672)
on conflict (ref) do nothing;
