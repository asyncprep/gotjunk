import 'dart:io';

import 'package:flutter/foundation.dart';
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
        // The same person back after an expired sign-in keeps their unsent work;
        // someone else on this phone starts clean.
        final previous = await db.getOptional('SELECT id FROM app_user LIMIT 1');
        final userId = change.session?.user.id;
        if (previous != null && userId != null && previous['id'] != userId) await clearPhone(db);
        await connect();
      case AuthChangeEvent.signedOut:
        // Not a wipe: this also fires when a sign-in expires or can't be refreshed, and unsent
        // work must survive that. Only the crew's own sign-out (signOutAndClear) removes data.
        await db.disconnect();
      default:
        break;
    }
  }, onError: (Object e) => debugPrint('Auth state error: $e'));
  return db;
}

/// The crew's own sign-out (shared truck phones): removes their data and photos from the phone.
Future<void> signOutAndClear(PowerSyncDatabase db) async {
  await Supabase.instance.client.auth.signOut();
  await clearPhone(db);
}

Future<void> clearPhone(PowerSyncDatabase db) async {
  await db.disconnectAndClear();
  final photos = await photoDirectory();
  if (photos.existsSync()) photos.deleteSync(recursive: true);
}

/// Changes and photos on this phone that haven't reached the server yet.
Future<int> unsentItems(PowerSyncDatabase db) async {
  final crud = await db.get('SELECT count(*) AS n FROM ps_crud');
  final photos = await db.get('SELECT count(*) AS n FROM photo_upload_queue');
  return (crud['n'] as int) + (photos['n'] as int);
}
