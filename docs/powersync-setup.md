# PowerSync setup (crew app offline sync)

The crew app keeps its shift on the phone and syncs through PowerSync. Until a PowerSync
instance is configured, the app signs in but has no data to show.

## 1. Account and instance (owner: you)

1. Create an account at powersync.com, ideally under the business's email.
2. Project `gotjunk` (instances: Development, Production), **US region** — PowerSync Cloud has
   no Canadian region. Decided Oct 27, 2026: US for the pilot, revisit self-hosting in Canada
   before production (client question P4).

## 2. Connection (done Oct 28, 2026)

Set up with PowerSync's guided Supabase setup on the **Development** instance:
- PowerSync created its own replication role in `gotjunk-ca` with read access to the 20 tables
  in the `powersync` publication. Left out on purpose: `audit_log`, `employee_rank_history`,
  `spec_item`.
- Client auth: Supabase Auth via the project's JWKS
  (`https://vrtvjnaykhlzyfbrllup.supabase.co/auth/v1/.well-known/jwks.json`); development tokens off.
- Sync streams: `supabase/powersync/sync-streams.yaml`, validated and deployed. Source tables are
  not aliased (an alias renames the table on the phone) and only the columns the app uses are sent.
- Instance URL (public endpoint, the app's default):
  `https://6ae136d7fb9e144e4ed9a04e.powersync.journeyapps.com`

## 3. Changing the sync rules

Edit `supabase/powersync/sync-streams.yaml`, paste it into PowerSync → Sync Streams, **Validate**
(fix every warning), then **Deploy**. Keep the file and the dashboard identical.

## 4. Production instance (before the pilot)

Repeat the guided setup on the Production instance and build the app with
`--dart-define=POWERSYNC_URL=<production instance URL>`.

## How uploads behave

- Every change is saved on the phone first, then uploaded table by table through Supabase,
  so row-level security and the database triggers apply exactly as in the admin app.
- If the server refuses a change (for example, a submit with missing items), the app shows
  the reason to the crew, drops that change, and the next sync restores the server's version.
- Network or server outages are retried automatically.
