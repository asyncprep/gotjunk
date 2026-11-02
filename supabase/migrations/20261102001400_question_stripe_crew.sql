-- Projet page: new client question (Nov 2). Link each Stripe payment to the route and crew that
-- did the job, with no one typing anything.

insert into public.spec_item (kind, ref, area, priority, title, detail, blocks, build_default, sort_order)
values ('question', 'F8', 'Integrations', 'v1b',
  $s$How can a Stripe payment be linked to the crew who did the job, without anyone typing anything?$s$,
  $s$Stripe payments carry the Opportunity ID (answer F2), but today the crew has to type that ID on the phone for each job. To link a payment to a route and its crew automatically we need one of these: (1) Does the HQ booking system know which truck a job was assigned to, and can we read it (export or API)? (2) Is the payment taken on a card reader or payment link tied to a truck or phone, and does Stripe record which one? (3) Does the payment carry anything else that identifies the truck or crew (metadata, description, terminal ID)? Can you show us where each of these appears in a few recent payments?$s$,
  $s$Automatic payment ↔ job ↔ crew matching$s$,
  $s$The crew types the Opportunity ID for each job; payments are matched to jobs by that ID$s$,
  670)
on conflict (ref) do nothing;
