// Public client configuration. The publishable key is designed to ship in apps;
// data access is enforced by row-level security on the server.
class AppConfig {
  static const supabaseUrl = 'https://vrtvjnaykhlzyfbrllup.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_i7X4yASErntePq4th3kAEA_-xOv32g9';

  // PowerSync instance URL. Empty until the instance exists: the app then works
  // fully offline on the phone and starts syncing once this is set.
  static const powersyncUrl = String.fromEnvironment('POWERSYNC_URL');

  static const timeZoneNote = 'Business dates follow the phone clock (Montréal).';
}
