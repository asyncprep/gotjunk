import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import 'connector.dart';
import 'schema.dart';

/// Opens the on-phone database and keeps it connected while someone is signed in.
Future<PowerSyncDatabase> openDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final db = PowerSyncDatabase(schema: schema, path: join(dir.path, 'truck_team_os.db'));
  await db.initialize();

  final auth = Supabase.instance.client.auth;
  Future<void> connect() async {
    if (AppConfig.powersyncUrl.isEmpty) return; // offline-only until the instance exists
    await db.connect(connector: SupabaseConnector());
  }

  if (auth.currentSession != null) await connect();
  auth.onAuthStateChange.listen((change) async {
    switch (change.event) {
      case AuthChangeEvent.signedIn:
        await connect();
      case AuthChangeEvent.signedOut:
        // Shared truck phones: remove the previous crew's local data.
        await db.disconnectAndClear();
      default:
        break;
    }
  });
  return db;
}
