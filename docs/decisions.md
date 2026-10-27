# Build decisions and working defaults

The backend implements these defaults for spec open items so building can start. Each is a
setting or seed value that can change without a redesign. Confirm or correct them with the client.

| Item | Default in the build | Where to change it |
| --- | --- | --- |
| E – assignments | Dispatch creates shifts and crew in Truck Team OS | `shift` insert rules (workflow migration) |
| R3 – disposal units | Metric tonnes (kg ÷ 1000) | `price_material_txn()` |
| R3 – minimums | Minimum applies per transaction, to costs only; credits never use a minimum. Eco-Junk minimums = 0 until confirmed; outside dump 500 kg | `site_rate_config.min_billable_kg`, `min_applies_to` |
| R5 – repeated Opportunity ID | Unique per shift; a repeat on another shift is a warning, not a block | `shift_problems()` |
| R4 – crew changes | Tips split among crew present when the job was completed (`joined_at` / `left_at`) | `v_tip_split` |
| B – tip split | Equal shares; leftover cents to the earliest-joined member. No overrides yet | `v_tip_split` |
| B/C – cash tips | Cash tips count in expected cash | `app_setting.cash_includes_tips` |
| C – cash variance | Any variance needs a written resolution before lock | `shift_problems()` |
| D – checklist | The spec WF-006 items, all required | `checklist_item` table |
| Crew size | 2–3 active members to submit | `app_setting.crew_min`, `crew_max` |
| Tax check | Warning when total ≠ pre-tax × 1.14975 (±$0.05) | `app_setting.sales_tax_rate`, `tax_tolerance` |
| Statuses | Adds `in_progress` and `returned` to the spec's list | `shift_status` enum |
| Drafts | A job with no outcome is a draft; drafts block submission | `job.outcome` |

Placeholders that must be replaced: cancellation reasons, payment method list, rank list (Trainer).

Not built yet (V1b): profit share engine, Stripe ingestion, scale import, reconciliation exceptions.
