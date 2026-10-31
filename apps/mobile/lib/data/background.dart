import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../app_config.dart';
import 'database.dart';
import 'photo_uploader.dart';

/// Android WorkManager runs this even when the app is closed, once there is a network.
const photoUploadTask = 'tto.photoUpload';
const _oneOffName = 'tto.photoUpload.oneoff';
/// Also the iOS task identifier: keep in sync with Info.plist and AppDelegate.swift.
const _periodicName = 'tto.photoUpload.periodic';

/// Queue rows that keep failing (e.g. a deleted file) stop counting as "still to do".
const _maxAttempts = 20;

bool _supabaseReady = false;

/// Call once Supabase is initialized in the main isolate.
void markSupabaseReady() => _supabaseReady = true;

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      return await uploadPhotosInBackground();
    } catch (_) {
      return false; // Android retries later with backoff
    }
  });
}

/// One background pass: restores the crew's saved sign-in, uploads queued photos.
/// Returns false while photos remain, so Android tries again later.
Future<bool> uploadPhotosInBackground({PowerSyncDatabase? db, StorageFileApi? bucket}) async {
  if (bucket == null) {
    if (!_supabaseReady) {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      // Reads the app's saved sign-in but never refreshes, saves or removes it: a refresh here
      // would use up the refresh token the app itself needs, and sign the crew out.
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabasePublishableKey,
        authOptions: FlutterAuthClientOptions(
          autoRefreshToken: false,
          localStorage: _ReadOnlySessionStorage(
              persistSessionKey: 'sb-${Uri.parse(AppConfig.supabaseUrl).host.split('.').first}-auth-token'),
        ),
      );
      _supabaseReady = true;
    }
    // Signed out, or the sign-in expired: the app uploads once it is open and signed in again.
    if (Supabase.instance.client.auth.currentSession == null) return true;
  }

  // Inside the running app, reuse its database; in a background isolate, open our own.
  final database = db ?? appDatabase ?? await openLocalDatabase();
  final ownsDatabase = db == null && appDatabase == null;
  try {
    await PhotoUploader(database, bucketOverride: bucket).runOnce();
    final left = await database.get(
        'SELECT count(*) AS n FROM photo_upload_queue WHERE coalesce(attempts, 0) < ?', [_maxAttempts]);
    return (left['n'] as int) == 0;
  } finally {
    if (ownsDatabase) await database.close();
  }
}

/// Registers the background work. On iOS the periodic task is a background app refresh: iOS
/// decides when it runs (it must also be listed in Info.plist and registered in AppDelegate).
Future<void> initBackgroundUploads() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  await Workmanager().initialize(backgroundDispatcher);
  await Workmanager().registerPeriodicTask(
    _periodicName,
    photoUploadTask,
    frequency: const Duration(minutes: 15), // Android's minimum
    initialDelay: const Duration(minutes: 15), // don't compete with app start-up
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

/// Asks Android to upload as soon as there is a network, even if the app is closed first.
/// iOS runs it right away and gives it about 30 seconds if the crew leaves the app.
Future<void> schedulePhotoUpload() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  await Workmanager().registerOneOffTask(
    _oneOffName,
    photoUploadTask,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// The app's saved sign-in, read-only for the background engine.
class _ReadOnlySessionStorage extends SharedPreferencesLocalStorage {
  _ReadOnlySessionStorage({required super.persistSessionKey});

  @override
  Future<void> persistSession(String persistSessionString) async {}

  @override
  Future<void> removePersistedSession() async {}
}
