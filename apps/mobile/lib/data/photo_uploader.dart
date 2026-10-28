import 'dart:async';
import 'dart:io';

import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends queued photo files to the private `photos` bucket while the app is open.
/// The photo's database row syncs separately; the file only needs to arrive eventually.
class PhotoUploader {
  PhotoUploader(this.db, {this.bucketOverride});
  final PowerSyncDatabase db;

  /// For tests; normally the signed-in user's `photos` bucket.
  final StorageFileApi? bucketOverride;
  Timer? _timer;
  bool _running = false;

  StorageFileApi get bucket => bucketOverride ?? Supabase.instance.client.storage.from('photos');

  void start({Duration every = const Duration(seconds: 30)}) {
    _timer ??= Timer.periodic(every, (_) => runOnce());
    runOnce();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Uploads what it can; returns how many files were sent.
  Future<int> runOnce() async {
    if (_running) return 0;
    if (bucketOverride == null && Supabase.instance.client.auth.currentSession == null) return 0;
    _running = true;
    var sent = 0;
    try {
      final queue = await db.getAll('SELECT * FROM photo_upload_queue ORDER BY id');
      for (final item in queue) {
        final file = File(item['local_path'] as String);
        if (!file.existsSync()) {
          await _fail(item['id'] as String, 'local file missing');
          continue;
        }
        try {
          await bucket.upload(item['storage_path'] as String, file,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
          await _done(item['id'] as String, file);
          sent++;
        } on StorageException catch (e) {
          // Already uploaded by an earlier attempt that lost its reply: treat as success.
          if (e.statusCode == '409' || e.message.toLowerCase().contains('already exists')) {
            await _done(item['id'] as String, file);
            sent++;
          } else {
            await _fail(item['id'] as String, e.message);
          }
        } on SocketException catch (e) {
          await _fail(item['id'] as String, e.message);
          break; // offline: stop here, retry on the next run
        }
      }
    } finally {
      _running = false;
    }
    return sent;
  }

  Future<void> _done(String id, File file) async {
    await db.execute('DELETE FROM photo_upload_queue WHERE id = ?', [id]);
    try {
      file.deleteSync();
    } catch (_) {
      // a leftover copy is harmless
    }
  }

  Future<void> _fail(String id, String error) => db.execute(
      'UPDATE photo_upload_queue SET attempts = coalesce(attempts, 0) + 1, last_error = ? WHERE id = ?',
      [error, id]);
}
