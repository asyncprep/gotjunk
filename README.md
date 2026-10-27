# Truck Team OS

Mobile-first replacement for the Montréal truck teams' paper Daily Route Journal.
- [Project overview](docs/project.md): goal, systems, stack, scope, plan and status
- [Questions for the client](docs/client-questions.md): what still needs an answer, and what it blocks
- [Working defaults](docs/decisions.md): what the build assumes until those answers arrive

The product specification (v0.3) is a client document and is not stored in this repo.

## Layout

| Path | What |
| --- | --- |
| `supabase/migrations/` | Database schema, business rules, permissions (the system of record) |
| `supabase/seed.sql` | Development reference data (sites, rates, lookups, demo fleet) |
| `supabase/tests/` | SQL tests: `_fixture.sql` per test, `*.test.sql` cases |
| `tools/dbtest/` | Test runner: migrations + tests in PGlite, no Docker needed |
| `apps/mobile/` | Flutter crew app (next) |
| `apps/admin/` | React dispatch/admin web app (later) |

## Database tests

```bash
cd tools/dbtest && npm install && npm test
```

Filter by name: `node run.mjs "tip split"`.

## How the backend works

- **Rules live in Postgres.** Both apps are thin; constraints, triggers and RLS enforce the spec.
- **Status changes are column updates** (`shift.status`), validated by triggers, so they sync offline:
  `open → in_progress → submitted → locked → reconciled → archived`, with `returned` and `reopened`
  (reason required).
- **`shift_problems(shift_id, 'submit' | 'lock')`** returns error/warning codes the apps translate;
  submit and lock are refused while errors remain.
- **Calculations:** disposal lines are priced from effective-dated `site_rate_config` and keep a
  snapshot; `v_shift_totals` is the scoreboard; `v_tip_split` splits tips.
- **Audit:** every change to operational and config tables lands in `audit_log` with actor and reason.
- **Offline IDs:** records the crew creates use UUIDv7 keys generated on the device.

## Local Supabase

Needs Docker and the Supabase CLI: `npx supabase start`, then `npx supabase db reset` applies
migrations and the seed. The PGlite runner covers the schema without Docker.
