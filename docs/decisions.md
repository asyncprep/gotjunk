# Build decisions and working defaults

The backend implements these defaults for spec open items so building can start. Each is a
setting or seed value that can change without a redesign. Open questions and client answers are
tracked on the admin app's **Projet** page (table `spec_item`).

## Decided by the client

| Item | Decision | Where it shows |
| --- | --- | --- |
| S1 – stack | Approved: Flutter crew app, React admin, Supabase in Canada | — |
| S2 / S3 – devices | Company-owned **iPhones only**, managed by an MDM | iOS builds (Codemagic, TestFlight) |
| H2 – trucks | **A truck can run two shifts the same day** | No per-day uniqueness on truck/phone (migration 1000) |
| F1 – Stripe | Montréal's Stripe is a sub-account of HQ; API keys can be created | V1b integration |
| F2 – Stripe data | Payments carry the Opportunity ID, GST and pre-tax amount | Crew amount entry can be replaced by import later |
| F3 – HQ export | Headquarters can't provide an export of the HQ app | Reconciliation is Truck Team OS ↔ Stripe |
| Payment methods (J2) | **Cash, credit card, debit card, invoice, e-transfer** | Payment methods list (migration 1600); Configuration → Payment methods |
| Cash tips (B4) | **Cash tips stay with the crew**: not in the cash envelope | Setting cash_includes_tips = false (admin and phone) |
| Cash difference (C3) | **Nothing happens in the system**: the difference is shown, it doesn't block acceptance and needs no note | Readiness warning cash_variance |
| Cash envelope (C1, C2) | **Label: date, name and amount; dispatcher signs off** | Envelope label prefilled with date · crew lead · amount; dispatch's count stores who and when |
| Tip split (B1, B2) | **Equal split; dispatch can change it** | Route page → Split by hand; amounts must add up to the route's tips (tip_override_mismatch blocks acceptance) |
| Disposal (R3a–d, sheet) | **Metric tonnes; no minimum at Eco-Junk; each outside dump has its own $/ton and minimum; metal is a 0 credit** | Sites have an address; Waste Management, EBI, Dépôt du Nord, Waste Connections at 60/t, min 1,000 kg |
| Ranks (A5) | **Recruit, Wingman, Professional, Expert, JR Coach**; Trainer is a role | Rank list (migration 1600) |
| Profit share (R1, A1–A9) | **Rank % × route revenue, by COGS band** | Live on the crew app (Nov 3, migration 1700); plan and % per rank are configuration. Formula and worked examples in profit-share.md |
| Wording | **"Route", not "shift"** (Nov 2): a truck's day is a route, as in the Daily Route Journal | Admin and crew app labels, Projet items (migration 1200). Tables, columns and error codes keep `shift` |
| Crew positions (S11) | **Each member is the driver or a navigator**; exactly one driver per route | Picked per member when creating the route; dispatch can change it on the route page. `shift_crew_member.position` (migration 1300) |
| Crew phone (S10) | **One shared phone per truck, signed in by the crew lead**; the rest of the crew has no login | `shift.lead_employee_id`: only the lead's login writes; dispatch picks/changes the lead; if the lead leaves, the next crew member who signs in takes over (migration 1100) |

## Working defaults (until the client answers)

| Item | Default in the build | Where to change it |
| --- | --- | --- |
| E – assignments | Dispatch creates shifts and crew in Truck Team OS | `shift` insert rules (workflow migration) |
| R3 – disposal units | Metric tonnes (kg ÷ 1000) | `price_material_txn()` |
| R3 – minimums | Minimum applies per transaction, to costs only; credits never use a minimum (enforced by constraint). Eco-Junk minimums = 0 until confirmed; outside dump 500 kg | `site_rate_config.min_billable_kg`, `min_applies_to` |
| R5 – repeated Opportunity ID | Unique per shift; a repeat on another shift is a warning, not a block | `shift_problems()` |
| R4 – crew changes | Tips split among crew present when the job was completed (`joined_at` / `left_at`); a tip with nobody present blocks acceptance until dispatch fixes the times | `v_tip_split`, `shift_problems()` |
| B – tip split | Equal shares; leftover cents to the earliest-joined member. No overrides yet | `v_tip_split` |
| B/C – cash tips | Cash tips count in expected cash | `app_setting.cash_includes_tips` |
| C – cash variance | Any variance needs a written resolution before lock | `shift_problems()` |
| D – checklist | The spec WF-006 items, all required | `checklist_item` table |
| Crew size | 2–3 active members to submit | `app_setting.crew_min`, `crew_max` |
| Same person, two shifts | Allowed once their earlier shift that day is submitted | `check_crew_double_booking()` |
| Tax check | Warning when total ≠ pre-tax × 1.14975 (±$0.05) | `app_setting.sales_tax_rate`, `tax_tolerance` |
| Statuses | Adds `in_progress` and `returned` to the spec's list; dispatch can cancel an open shift (→ `archived`, with a reason) | `shift_status`, `transition_allowed()` |
| Times | Start and job completion times come from the phone's clock (work done offline keeps its real time) | `shift_before_update()`, `job_rules()` |
| Drafts | A job with no outcome is a draft; drafts block submission | `job.outcome` |
| Data residency (sync) | PowerSync Cloud, **US region**, for the pilot (no Canadian region offered). Supabase, the system of record, stays in ca-central-1. Revisit self-hosting PowerSync in Canada before production (P4) | PowerSync dashboard, `docs/powersync-setup.md` |

Placeholders that must be replaced: cancellation reasons, payment method list, rank list (Trainer).

Not built yet (V1b): profit share on the admin side, Stripe ingestion, scale import, reconciliation exceptions.
