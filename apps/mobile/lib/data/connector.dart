import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../app_config.dart';
import 'schema.dart';

// Errors retrying can't fix: business-rule refusals raised by our triggers (P0001),
// bad data (class 22), constraint violations (class 23) and RLS refusals (42501).
final _rejectionCodes = [RegExp(r'^P0001$'), RegExp(r'^22...$'), RegExp(r'^23...$'), RegExp(r'^42501$')];

bool isRejection(PostgrestException e) =>
    e.code != null && _rejectionCodes.any((re) => re.hasMatch(e.code!));

/// Uploads the phone's queued changes to Supabase, one local transaction at a time.
class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    return PowerSyncCredentials(
      endpoint: AppConfig.powersyncUrl,
      token: session.accessToken,
      userId: session.user.id,
      expiresAt: session.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
    );
  }

  @override
  void invalidateCredentials() {
    _client.auth.refreshSession().timeout(const Duration(seconds: 5)).ignore();
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;

    for (final op in transaction.crud) {
      final pk = writablePrimaryKeys[op.table];
      if (pk == null) continue; // read-only reference data is never uploaded
      final table = _client.from(op.table);
      try {
        switch (op.op) {
          case UpdateType.put:
            await table.upsert({...?op.opData, pk: op.id});
          case UpdateType.patch:
            // A change that matches no row (gone, or hidden by access rules) is not a success.
            final rows = await table.update(op.opData!).eq(pk, op.id).select(pk);
            if (rows.isEmpty) await _reject(database, op, 'PGRST116', 'not_found: ${op.table} ${op.id}');
          case UpdateType.delete:
            await table.delete().eq(pk, op.id);
        }
      } on PostgrestException catch (e) {
        if (!isRejection(e)) rethrow; // network/server trouble: PowerSync retries the whole transaction later
        // Keep going with the rest, so one refusal doesn't take the other changes with it.
        // The crew is told why; the next sync restores the server's version of this record.
        await _reject(database, op, e.code, e.message);
      }
    }
    await transaction.complete();
  }

  Future<void> _reject(PowerSyncDatabase database, CrudEntry op, String? code, String message) => database.execute(
        'INSERT INTO sync_rejection (id, table_name, record_id, code, message, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [const Uuid().v7(), op.table, op.id, code, message, DateTime.now().toUtc().toIso8601String()],
      );
}
