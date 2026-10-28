import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_config.dart';
import 'connector.dart';
import 'schema.dart';

/// The app's database once open (null in a background isolate until it opens its own).
PowerSyncDatabase? appDatabase;

/// Where photos wait on the phone until they are uploaded.
Future<Directory> photoDirectory() async =>
    Directory(join((await getApplicationDocumentsDirectory()).path, 'photos'));

/// Opens the on-phone database file without connecting to sync.
Future<PowerSyncDatabase> openLocalDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final db = PowerSyncDatabase(schema: schema, path: join(dir.path, 'truck_team_os.db'));
  await db.initialize();
  return db;
}

/// Opens the on-phone database and keeps it connected while someone is signed in.
Future<PowerSyncDatabase> openDatabase() async {
  final db = await openLocalDatabase();
  appDatabase = db;

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
        // Shared truck phones: remove the previous crew's data and photos.
        await db.disconnectAndClear();
        final photos = await photoDirectory();
        if (photos.existsSync()) photos.deleteSync(recursive: true);
      default:
        break;
    }
  });
  return db;
}

/// Changes and photos on this phone that haven't reached the server yet.
Future<int> unsentItems(PowerSyncDatabase db) async {
  final crud = await db.get('SELECT count(*) AS n FROM ps_crud');
  final photos = await db.get('SELECT count(*) AS n FROM photo_upload_queue');
  return (crud['n'] as int) + (photos['n'] as int);
}
