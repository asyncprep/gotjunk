# Questions for the client

The live list is on the admin app's **Projet** page (Projet → Questions pour le client). It has
the questions and the 17 spec inconsistencies, with their status, priority, what each blocks,
what the app does meanwhile, and the client's answers. Use **Imprimer** for a meeting handout and
**Exporter (CSV)** for a spreadsheet.

This file only records the answers received so far, so they are also in the repository history.

## Questions added since

| Ref | Question |
| --- | --- |
| A10 | Is the Aug 2024 profit-share sheet still current (each rate and threshold)? |
| A11 | What is a "split day" and "2 trucks" for fuel, and when is the $60 swing truck fee charged? |
| A12 | Which ranks exist? Do Recruits get profit share? Are Expert and JR Coach one rank or two? |
| A13 | How are the trainer's 3 hours removed, and who records damages? |
| A14 | Donation credit: $75 per 1,000 kg, or what the Oct 25 sheet shows (about $10)? |
| F9 | Are card payments taken with Helcim, Stripe, or both? |
| S12 | Which GOT-JUNK address sends invitations, and can we get its SMTP settings? |
| F8 | How can a Stripe payment be linked to the crew who did the job, without anyone typing anything? (Payments carry the Opportunity ID, but the crew types it today. Does HQ know which truck did each job? Is the card reader or payment link tied to a truck or phone? Does the payment carry anything identifying the truck or crew?) |
| F10 | Can dispatch get today's jobs per truck out of Pipeline without typing? (A Salesforce report with Opportunity ID, truck or crew, address and time, exported to CSV or emailed each morning. Can we get a sample? Failing that, read-only API access to those fields from HQ?) |

## Answers received (as of Nov 2, 2026)

| Ref | Question | Answer |
| --- | --- | --- |
| S1 | Approve the technology stack? | Yes |
| S2 | Crew phones? | All iPhones, company-owned |
| S3 | Device management (MDM)? | Yes; iPhones only |
| S5 | Who signs off and approves costs? | Khalil, for now |
| S6 | Who owns the accounts? | Not needed for now |
| S7 | Who maintains the system after launch? | Khalil |
| S8 | Upgrade hosting to paid plans before the pilot? | Later |
| H2 | Can a truck run two shifts the same day? | Yes |
| F1 | Stripe API keys and webhooks? | Stripe is a sub-account of HQ; API keys can be created |
| F2 | What do Stripe payments carry? | Opportunity ID, GST (TPS) and the pre-tax amount |
| F3 | Export of what crews enter in the HQ app? | No |
| P4 | US region for the offline-sync service during the pilot? | Accepted for the pilot |
| R1 | Profit-share % by rank, by margin tier, or both? | Both: rank × COGS % band (profit-share sheet, Aug 2024) |
| A1 | Gross-margin formula and costs? | COGS % = (wages + dumps − credits + franchise 16% + fuel 4–7% + swing truck $60) ÷ revenue; see `profit-share.md` |
| A2 | Wage cost source and rate? | Flat $26 × team hours |
| A3 | Fuel cost source? | % of revenue: 4%, 5.5% split day, 7% for 2 trucks |
| A4 | Threshold to qualify? | COGS ≤ 50%, revenue ≥ $2,000 ($1,500 under 18 team hours), RPH ≥ $135 |
| A5 | Ranks and %? | Wingman 1–3%, Professional 2–4%, Expert & JR Coach 3–5% of revenue by COGS band; Trainer is a role (−3 hours) |
| A8 | Do disposal costs/credits count? | Yes: dumps − credits; donations credit $75 per 1,000 kg |
| A9 | Other criteria? | Paperwork complete, no damages, policies respected, donations never dumped |
| E | Where do route assignments come from? | Dispatch enters them by hand |
| G | How long can the phone work without signal? | No limit |
| S4 | Does HQ need to approve the app or brand use? | No |
| S9 | Which email sends invitations? | GOT-JUNK addresses (see S12) |
| A6 | Which hours types count for profit share? | Regular Junk |
| A7 | Worked examples? | Daily tracker Excel to come; three filled route sheets of Oct 25 received |
| B1 | Tips split equally? | Yes |
| B2 | Can the tip split be overridden? | Yes, by the dispatcher |
| B3 | Payroll format for tips? | Not needed |
| B4 | Cash tips in the envelope? | No: the crew keeps cash tips |
| C1 | Envelope identifier? | Date, name and amount, signed off by the dispatcher |
| C2 | Who receives the envelope? | Dispatch, with a sign-off |
| C3 | Cash doesn't match? | Nothing in the system |
| D1 | End-of-day checklist? | Kept in the admin; admin sets which items are required |
| R2 | Ticket number on scale records? | Yes, at Eco-Junk (internal) |
| R3a | Metric or short tons? | Metric |
| R3b | Minimum billable weights? | None at Eco-Junk; 500 or 1,000 kg at outside dumps |
| R3c | Minimum on donation credits? | No |
| R3d | Which outside dumps? | A list kept in the admin: name, address, $ per ton, minimum |
| J2 | Payment methods? | Cash, invoice, credit card, debit card, e-transfer |
| J3 | Cancellation reasons? | On the sheet; to be shared |
| J4 | Revenue before tax after the discount? | Yes |
| J5 | Tax-exempt jobs or other rates? | No |
| S10 | How does the crew sign in on the shared truck phone? | The crew lead signs in; the rest of the crew has no login |

Also from the client: **each crew has one shared phone per truck.**
