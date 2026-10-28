# PowerSync setup (crew app offline sync)

The crew app keeps its shift on the phone and syncs through PowerSync. Until a PowerSync
instance is configured, the app signs in but has no data to show.

## 1. Account and instance (owner: you)

1. Create an account at powersync.com, ideally under the business's email.
2. Project `gotjunk` (instances: Development, Production), **US region** — PowerSync Cloud has
   no Canadian region. Decided Oct 27, 2026: US for the pilot, revisit self-hosting in Canada
   before production (client question P4).

## 2. Database user for replication (owner: you, in the Supabase SQL editor)

Choose a strong password and keep it in your password manager. Never commit it.

```sql
create role powersync_role with replication bypassrls login password 'CHOOSE_A_STRONG_PASSWORD';
grant select on all tables in schema public to powersync_role;
alter default privileges in schema public grant select on tables to powersync_role;
```

The `powersync` publication already exists (migration 600).

## 3. Connect the instance

- **Database connection:** the Supabase direct connection string for `gotjunk-ca`, user
  `powersync_role`, SSL mode `verify-full`.
- **Client auth:** Supabase Auth. The project uses JWT signing keys, so leave the JWT secret empty.
- **Sync config:** paste `supabase/powersync/sync-streams.yaml` and validate it.

## 4. Point the app at it

Build or run the app with the instance URL:

```
flutter run --dart-define=POWERSYNC_URL=https://YOUR-INSTANCE.powersync.journeyapps.com
```

## How uploads behave

- Every change is saved on the phone first, then uploaded table by table through Supabase,
  so row-level security and the database triggers apply exactly as in the admin app.
- If the server refuses a change (for example, a submit with missing items), the app shows
  the reason to the crew, drops that change, and the next sync restores the server's version.
- Network or server outages are retried automatically.
