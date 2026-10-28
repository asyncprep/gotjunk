// Public client configuration. The publishable key is designed to ship in apps;
// data access is enforced by row-level security on the server.
class AppConfig {
  static const supabaseUrl = 'https://vrtvjnaykhlzyfbrllup.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_i7X4yASErntePq4th3kAEA_-xOv32g9';

  // PowerSync Development instance (US region for the pilot, see docs/decisions.md).
  // Override per build with --dart-define=POWERSYNC_URL=… (e.g. the Production instance).
  static const powersyncUrl = String.fromEnvironment(
    'POWERSYNC_URL',
    defaultValue: 'https://6ae136d7fb9e144e4ed9a04e.powersync.journeyapps.com',
  );

  static const timeZoneNote = 'Business dates follow the phone clock (Montréal).';
}
