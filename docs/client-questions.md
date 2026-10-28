# Questions for the client

Answers to these unblock the rest of V1. Each question notes what it blocks and, where the build
already needed an answer, the working default now in place (also in [decisions.md](decisions.md)).
IDs A–G match the spec's §15 open items; R1–R5 came from the spec review; S, P and O are new.

**Priority:** 🔴 blocks the next phase · 🟠 needed before the pilot · 🟢 needed before V1b

## Most urgent

| ID | Question | Blocks | Working default |
| --- | --- | --- | --- |
| S1 🔴 | Do you approve the technology stack (Flutter app, React admin, Supabase in Canada)? | All development past the backend | Proceeding as recommended |
| S2 🔴 | Are the crew phones company-owned iPhones? Any Android? | App build and distribution | iPhone only |
| G 🔴 | How long must the app work without signal before crews are blocked? | Offline design (PowerSync scope, photo handling) | Full shift offline |
| E 🔴 | Does dispatch create truck/phone/crew assignments in Truck Team OS, or do they come from the Daily Tracker? | Assignment screens, sync | Dispatch creates them in the app |
| A 🟢 | Profit-share formula (see section A below) | Profit-share engine and scoreboard bonus | Not built; shows "pending plan" |

## A – Profit share

| ID | Question | Working default |
| --- | --- | --- |
| A1 | What is the exact gross-margin formula, and which costs count (wages, fuel, disposal)? | — |
| A2 | Where do wage costs come from (Ceridian, a rate table)? At what rate? | — |
| A3 | Where do fuel costs come from, and how are they assigned to a shift? | — |
| A4 | What gross-margin threshold(s) must a shift meet to qualify? | — |
| A5 | What are the ranks and their revenue-share %? Is Trainer a rank or an extra role? | Ranks seeded: Recruit, Wingman, Sales Professional, Trainer (to confirm) |
| A6 | Which hours types are eligible (Regular Junk, Warehouse, Non-Junk)? | — |
| A7 | Please provide 2–3 worked examples from real shifts, including a crew with different ranks | — |
| A8 | Do scale costs/credits count in the current plan? Could disposal be removed in a future plan? | Stored separately so either works |
| A9 | Other criteria (minimum revenue per hour, Res AJS)? | — |
| R1 | Is the % set by the employee's rank, by a gross-margin tier, or both? | — |

## B – Tips

| ID | Question | Working default |
| --- | --- | --- |
| B1 | Confirm tips split equally among the crew on the job | Equal split; leftover cents to the first crew member |
| B2 | When can the split be overridden, and who approves? | No overrides |
| B3 | What format does payroll need for tips? | — |
| B4 | Do cash tips go in the cash envelope (count in expected cash)? | Yes |

## C – Cash

| ID | Question | Working default |
| --- | --- | --- |
| C1 | Envelope identifier format? | Free text entered by dispatch |
| C2 | Who physically receives and stores the envelope? | Recorded as "received by" |
| C3 | What happens when counted cash ≠ expected? | A written resolution is required before lock |

## D – Dispatcher end-of-day checklist

| ID | Question | Working default |
| --- | --- | --- |
| D1 | Please provide the full checklist (keys, phone, tools, truck state, anything else) and which items are mandatory | Spec WF-006 items, all mandatory; editable by admin |

## Disposal

| ID | Question | Working default |
| --- | --- | --- |
| R3a | Are Eco-Junk and dump rates per metric tonne (1,000 kg) or short ton? | Metric tonne |
| R3b | Does Eco-Junk have minimum billable weights? Per weigh-in or per visit? | No minimum at Eco-Junk; 500 kg at outside dumps |
| R3c | Does a minimum ever apply to donation credits? | Never |
| R3d | Which outside dumps are used, and their rates/minimums? | One generic "outside dump" at $160/t, 500 kg minimum |
| R2 | On a scale record, is the disposal ticket number present (to match manual tickets)? | — (needs a scale data sample) |

## Jobs, shifts and crews

| ID | Question | Working default |
| --- | --- | --- |
| R5 | When can the same Opportunity ID appear on two shifts (return visit, rebooking)? | Allowed with a warning |
| J1 | What is the Opportunity ID format (Salesforce 15/18 characters, job number)? | Any text up to 40 characters |
| J2 | Full list of payment methods (cash, card, cheque, invoice/account, e-transfer)? | Cash, Card |
| J3 | Cancellation reasons dispatch uses? | Placeholders: price declined, customer absent, items not as described, other |
| J4 | Is revenue before tax entered after the discount? | Yes (net of discount) |
| J5 | Any tax-exempt jobs or other tax rates? | GST + QST 14.975%, warning only |
| R4 | When the crew changes mid-shift, how are tips and profit share split (by time, by job)? | Crew present when the job is completed |
| H1 | Can crews ever be solo or 4 people? | 2–3 required to submit |
| H2 | Can one truck run two shifts on the same day? | One active shift per truck per day |
| H3 | Should shift hours use Ceridian's 15-minute rounding, or only in reconciliation? | Exact times; rounding only in reconciliation |

## F – Data sources and integrations

| ID | Question | Blocks |
| --- | --- | --- |
| F1 | Can you create restricted API keys and webhooks on Montréal's Stripe account? Is it a Connect account under HQ? | Stripe ingestion |
| F2 | Can we see 5–10 recent Stripe payments? Do they carry an Opportunity ID or job number, tip, tax or discount? | Job ↔ payment matching |
| F3 | Can headquarters provide an export of what crews enter in the HQ app? | Three-way reconciliation |
| F4 | How does Pipeline report data reach Google Sheets today? Any scheduled exports? | Pipeline reconciliation |
| F5 | What scales platform is used? Can we get a sample export (truck, crew, materials, weights, IDs)? | Scale import |
| F6 | What is the authoritative employee roster and rank history, and which IDs match Ceridian and the scales? | Roster import |
| F7 | Can we get Ceridian time exports, and in what format? | Time reconciliation |

## Devices, distribution and approvals

| ID | Question |
| --- | --- |
| S3 | Is a device management (MDM) tool in place (Jamf, Kandji, Intune)? |
| S4 | Does headquarters need to approve a locally built app, its name or its use of the brand? |
| S5 | Who signs the stack decision and approves vendor costs? |
| S6 | Who will own the accounts: Apple Developer, Supabase, PowerSync, GitHub, Sentry? (Ideally the business, with us as collaborators.) |
| S7 | Who maintains the system after launch? |

## Privacy and language

| ID | Question | Working default |
| --- | --- | --- |
| P1 | Confirm French as the default language for crews and dispatch | French default, English available |
| P2 | How long should cash and ticket photos be kept? Who is the Law 25 privacy officer? | Not set |
| P3 | Can the product spec PDF be stored in the code repository? | Kept out of the repo |
| P4 🟠 | Offline sync (PowerSync Cloud) has no Canadian region, so its synced copy of crew data (shifts, jobs, amounts, crew names) is hosted in the **US** for the pilot. The main database stays in Canada. Is that acceptable for the pilot, and must production keep everything in Canada? | US region for the pilot; self-host PowerSync in Canada before production unless the client accepts the US region |

## Pilot and rollout

| ID | Question |
| --- | --- |
| O1 | Which trucks/crews pilot first, and for how long alongside the paper journal? |
| O2 | Who on the client side reviews the app in French before rollout? |
| O3 | What does "pilot successful" mean (e.g. reconciliation time, error rate, crew adoption)? Do you have a baseline for current reconciliation time per shift? |
