# Truck Team OS – Project overview

Truck Team OS replaces the paper Daily Route Journal used by the Montréal 1-800-GOT-JUNK? truck
teams with a mobile app, a dispatch/admin web app and one backend. It keeps the discipline of the
paper journal, removes the arithmetic, and makes reconciliation electronic from day one.

Source of truth for requirements: *Truck Team OS – Product Specification v0.3* (Oct 26, 2026),
kept outside this repo. Open questions for the client: [client-questions.md](client-questions.md).
Working defaults the build uses until those are answered: [decisions.md](decisions.md).

## Goal

**North star:** eliminate routine human reconciliation. Validation moves to the moment data is
entered; external systems are matched automatically; admins handle only true exceptions.

**KPI:** Auto-Reconciliation Rate = share of shifts/jobs that reconcile with no human intervention.

## Systems and boundaries

| System | Owner | Role for Truck Team OS |
| --- | --- | --- |
| **Truck Team OS** (this project) | Montréal | Captures local journal data, live scoreboard, end-of-day handoff, reconciliation |
| HQ "Truck Team App" | Headquarters | Corporate job workflow; starts Stripe payments. Not replaced or imitated |
| Pipeline (Salesforce) | Headquarters | Job/opportunity record. No API access today |
| Stripe | Payment processor | Montréal can read its own account; ingestion planned (V1b) |
| Scale / weighing system | Montréal | Weigh events per truck, crew and material; ingestion planned (V1b) |
| Ceridian | Payroll | Authoritative clock-in/out; reconciliation source |
| Motive | Fleet | Vehicle/GPS/inspection; not duplicated |
| Google Sheets / Daily Tracker | Montréal | Current reporting and assignments; export target during migration |

## Users

| Role | Main jobs |
| --- | --- |
| Truck Team Member (TTM) | Start shift, enter jobs, disposal and cash, see the scoreboard, submit |
| Dispatcher | Assign trucks/phones/crews, confirm hours, finalize cancellations, count cash, accept & lock |
| Admin (ops admin) | Resolve reconciliation exceptions, manage config, payroll outputs, reopen with reason |
| Senior Ops / Owner | Dashboards, business-rule approval, audit history, overrides |

## Technology (decided Oct 27, 2026; pending client sign-off)

| Layer | Choice |
| --- | --- |
| Crew app | Flutter (iPhone first), offline with PowerSync + SQLite, Shorebird over-the-air updates |
| Dispatch/admin app | React + TypeScript web app |
| Backend | Supabase (PostgreSQL), Canada (Central) region; rules, permissions and audit in the database |
| Integrations | Supabase Edge Functions (TypeScript) + scheduled jobs |
| Languages | French (Canada) default, English available |
| Distribution | TestFlight for the pilot, then a private Apple Business Manager custom app |

```
 Crew app (Flutter) ──sync──> PowerSync ──> ┌──────────── Supabase (Canada) ────────────┐
        └──────────── photos ─────────────> │ PostgreSQL: data, rules, RLS, audit        │
 Dispatch/admin web (React) ──────────────> │ Auth + Storage   ·   Edge Functions        │
                                            └───────────────┬────────────────────────────┘
                                 Stripe · Scales · Ceridian/roster (in)   Google Sheets (out)
```

## Environments

| Environment | Supabase project | Region | Deploys |
| --- | --- | --- | --- |
| Development (current) | `gotjunk-ca` (`vrtvjnaykhlzyfbrllup`) | Canada (Central), ca-central-1 | Automatically from `main` via the Supabase GitHub integration |
| Admin web app | Vercel `gotjunk-admin` (Hobby for now; upgrade to Pro before the pilot) | https://gotjunk.innodigital.ca (also gotjunk-admin.vercel.app) | Automatically from `main`, root `apps/admin` |
| Local | PGlite (`tools/dbtest`) | Your machine | `npm test`, `node explorer.mjs` |

A separate production project (also ca-central-1, Pro plan) is planned before the pilot. The earlier
`gotjunk` project in us-west-2 is paused and not used.

## Scope

**V1a – paper journal replacement (in progress)**
- Shift lifecycle with lock/reopen and full audit trail
- Completed jobs (crew-entered financials) and cancellations finalized by dispatch
- Disposal visits and material lines priced from admin-controlled, effective-dated rates
- Cash: expected amount, mandatory photo, dispatcher count and variance
- Dispatcher end-of-day checklist
- Live scoreboard: revenue, jobs, tips and tip split, net disposal, revenue/hour
- Roles and row-level security; reconciliation-ready export

**V1b – integrations and compensation (after client answers)**
- Profit-share engine with versioned plans and a simulation tool
- Stripe webhooks and backfill; job ↔ payment matching
- Scale-event import and a single signed disposal-cost ledger
- Roster/rank and Ceridian imports
- Reconciliation exception queue and "X of Y shifts auto-reconciled" view

**Not in V1:** AI cancellation coaching, Pipeline write-back, App Store listing, computer-vision cash counting.

## Plan and status

| Phase | Content | Status |
| --- | --- | --- |
| 0 – Setup and decisions | Stack decision doc, repo, data dictionary, open-item defaults | Done, except client sign-off and offline spike |
| 1 – Backend foundation | Schema, workflow, calculations, RLS, audit, seed, 25 tests, local explorer | **Done**; deployed to `gotjunk-ca` (Canada) on Oct 27, 2026 |
| 2 – Admin web app (moved first) | Daily board and shift creation, review/accept/return/reopen, cash count, checklist, cancellations, config and rates, roster and ranks, user invites, audit log, CSV export, fr/en | **Built** (`apps/admin`); hosting and first login pending |
| 3 – First crew slice | Flutter (Android first): login, today's shift, start shift, jobs, live scoreboard, submit, offline storage and sync status | **Built** (`apps/mobile`), tested on an Android emulator |
| 4 – Crew app complete | Disposal visits and weigh-ins with price estimates, ticket and cash photos (queued offline), expected cash, pre-submit checklist, confirmed cancellation reasons, net disposal on the scoreboard | **Built**, tested on an Android emulator; live sync waits on the PowerSync database login ([setup](powersync-setup.md)); background photo upload and iOS still to do |
| 5 – Pilot | 1–2 trucks alongside the paper journal for 2–4 weeks, then rollout | Planned |
| 6 – Integrations (V1b) | Profit share, Stripe, scales, roster/Ceridian, exceptions queue | Blocked on client answers |

## Related documents

| Document | Where |
| --- | --- |
| Product specification v0.3 | Client document (not in repo) |
| V1 data dictionary | [Claude Doc](https://claude.ai/artifact/QD4S9DeHPGxCEtYPunfxGC) |
| Technology stack decision (for client approval) | [Claude Doc](https://claude.ai/artifact/SEmziqJqdMGBNsm9quMivz) |
| Working defaults for open items | [decisions.md](decisions.md) |
| Questions for the client | [client-questions.md](client-questions.md) |
