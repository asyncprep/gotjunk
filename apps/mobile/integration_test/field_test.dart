// On-device tests for disposal, cash, photos and the pre-submit checks.
// flutter test integration_test -d <device>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:truck_team_os/data/background.dart';
import 'package:truck_team_os/data/database.dart';
import 'package:truck_team_os/data/field_repo.dart';
import 'package:truck_team_os/data/photo_uploader.dart';
import 'package:truck_team_os/data/repo.dart';
import 'package:truck_team_os/data/schema.dart';

const shiftId = 's-1';

/// Stands in for Supabase Storage: records uploads, can fail or report "already exists".
class FakeBucket implements StorageFileApi {
  final uploaded = <String>[];
  Object? failWith;

  @override
  Future<String> upload(String path, dynamic file,
      {FileOptions fileOptions = const FileOptions(), int? retryAttempts, StorageRetryController? retryController}) async {
    if (failWith != null) throw failWith!;
    uploaded.add(path);
    return path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late PowerSyncDatabase db;
  late Repo repo;
  late String path;
  late Directory dir;

  setUp(() async {
    dir = await getTemporaryDirectory();
    path = join(dir.path, 'field_test_${DateTime.now().microsecondsSinceEpoch}.db');
    db = PowerSyncDatabase(schema: schema, path: path);
    await db.initialize();
    repo = Repo(db);
    await db.writeTransaction((tx) async {
      await tx.execute(
          "INSERT INTO shift (id, shift_date, status, hours_type) VALUES (?, ?, 'in_progress', 'regular_junk')",
          [shiftId, todayLocal()]);
      await tx.execute(
          "INSERT INTO shift_crew_member (id, shift_id, employee_id, joined_at) VALUES ('m1', ?, 'e1', '2020-01-01 00:00:00Z'), ('m2', ?, 'e2', '2020-01-01 00:00:00Z')",
          [shiftId, shiftId]);
      await tx.execute(
          "INSERT INTO site (id, code, name, issues_tickets, requires_ticket_photo, active) VALUES "
          "('eco', 'eco_junk', 'Eco-Junk', 1, 1, 1), ('dump', 'outside_dump', 'Outside dump', 1, 1, 1)");
      await tx.execute(
          "INSERT INTO material_type (id, code, name_fr, name_en, active) VALUES "
          "('garbage', 'garbage', 'Déchets', 'Garbage', 1), ('donation', 'donation', 'Dons', 'Donations', 1), "
          "('mattress', 'mattress_clean', 'Matelas', 'Mattresses', 1), ('mixed', 'mixed', 'Mixte', 'Mixed', 1), "
          "('wood', 'wood', 'Bois', 'Wood', 1)");
      await tx.execute(
          "INSERT INTO site_rate_config (id, site_id, material_type_id, rate_per_ton, direction, min_billable_kg, min_applies_to, effective_from, active) VALUES "
          "('r1', 'eco', 'garbage', 150, 'cost', 0, 'transaction', '2026-01-01', 1), "
          "('r2', 'eco', 'donation', 75, 'credit', 0, 'never', '2026-01-01', 1), "
          "('r3', 'eco', 'mattress', 0, 'no_charge', 0, 'never', '2026-01-01', 1), "
          "('r4', 'dump', 'mixed', 160, 'cost', 500, 'transaction', '2026-01-01', 1), "
          "('r5', 'eco', 'wood', 999, 'cost', 0, 'transaction', '2020-01-01', 1)");
      await tx.execute("UPDATE site_rate_config SET effective_to = '2020-12-31' WHERE id = 'r5'");
      await tx.execute(
          "INSERT INTO payment_method (id, name_fr, name_en, is_cash, active) VALUES ('cash', 'Comptant', 'Cash', 1, 1), ('card', 'Carte', 'Card', 0, 1)");
      await tx.execute(
          "INSERT INTO app_setting (id, value) VALUES ('cash_includes_tips', 'true'), ('crew_min', '2'), ('crew_max', '3')");
    });
  });

  tearDown(() async {
    await db.close();
    if (File(path).existsSync()) File(path).deleteSync();
  });

  testWidgets('disposal lines are priced like the server: costs, credits, free, minimum', (_) async {
    final eco = await repo.addVisit(shiftId, 'eco', 'EJ-1');
    await repo.addLine(eco, 'garbage', 300);
    await repo.addLine(eco, 'donation', 400);
    await repo.addLine(eco, 'mattress', 120);
    final dump = await repo.addVisit(shiftId, 'dump', 'OD-7');
    await repo.addLine(dump, 'mixed', 300);

    final ecoLines = await repo.lines(eco).first;
    final byMaterial = {for (final l in ecoLines) l['material_type_id']: l['amount']};
    expect(byMaterial['garbage'], 45.0);
    expect(byMaterial['donation'], -30.0);
    expect(byMaterial['mattress'], 0.0);
    expect((await repo.lines(dump).first).single['amount'], 80.0, reason: r'500 kg minimum at $160/t');
    expect(ecoLines.every((l) => l['confirmed'] == 0), isTrue, reason: 'estimates until the server prices them');
    expect(await repo.netDisposal(shiftId).first, closeTo(95, 0.001));
  });

  testWidgets('the server price replaces the estimate once synced', (_) async {
    final eco = await repo.addVisit(shiftId, 'eco', 'EJ-2');
    await repo.addLine(eco, 'garbage', 300);
    await db.execute('UPDATE disposal_material_txn SET signed_amount = 44.5');
    final line = (await repo.lines(eco).first).single;
    expect(line['amount'], 44.5);
    expect(line['confirmed'], 1);
  });

  testWidgets('expired or missing rates give no estimate and only valid materials are offered', (_) async {
    final eco = await repo.addVisit(shiftId, 'eco', 'EJ-3');
    await repo.addLine(eco, 'wood', 100);
    expect((await repo.lines(eco).first).single['amount'], isNull);
    final offered = (await repo.materialsForSite('eco').first).map((m) => m['id']).toSet();
    expect(offered, {'garbage', 'donation', 'mattress'});
    expect((await repo.materialsForSite('dump').first).map((m) => m['id']), ['mixed']);
  });

  testWidgets('expected cash counts cash jobs with tips', (_) async {
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'A', outcome: 'completed',
        paymentMethod: 'cash', preTax: 100, total: 114.98, tip: 10));
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'B', outcome: 'completed',
        paymentMethod: 'card', preTax: 200, total: 229.95, tip: 5));
    expect(await repo.expectedCash(shiftId).first, closeTo(124.98, 0.001));
    await db.execute("UPDATE app_setting SET value = 'false' WHERE id = 'cash_includes_tips'");
    expect(await repo.expectedCash(shiftId).first, closeTo(114.98, 0.001));
  });

  testWidgets('readiness checks match the server codes and clear when fixed', (_) async {
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'D', outcome: null));
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'C', outcome: 'completed',
        paymentMethod: 'cash', preTax: 100, total: 114.98));
    final visit = await repo.addVisit(shiftId, 'eco', null);

    expect(await repo.readinessProblems(shiftId),
        unorderedEquals(['job_incomplete', 'ticket_number_missing', 'ticket_photo_missing', 'visit_no_materials', 'cash_photo_missing']));

    final picture = File(join(dir.path, 'pic_${DateTime.now().microsecondsSinceEpoch}.jpg'))..writeAsBytesSync([1, 2, 3]);
    final photoDir = Directory(join(dir.path, 'photos_test'));
    await db.execute("UPDATE job SET outcome = 'cancelled_pending' WHERE opportunity_id = 'D'");
    await repo.updateVisit(visit, siteId: 'eco', ticketNumber: 'EJ-9');
    await repo.addLine(visit, 'garbage', 50);
    await repo.addPhoto(shiftId: shiftId, kind: 'disposal_ticket', entityType: 'disposal_visit',
        entityId: visit, picture: picture, photoDir: photoDir);
    final cashId = await repo.ensureCashSubmission(shiftId);
    expect(await repo.ensureCashSubmission(shiftId), cashId, reason: 'one cash record per shift');
    await repo.addPhoto(shiftId: shiftId, kind: 'cash_submission', entityType: 'cash_submission',
        entityId: cashId, picture: picture, photoDir: photoDir);

    expect(await repo.readinessProblems(shiftId), isEmpty);

    await db.execute("UPDATE shift_crew_member SET left_at = '2020-01-02 00:00:00Z' WHERE id = 'm2'");
    expect(await repo.readinessProblems(shiftId), ['crew_size']);
  });

  testWidgets('photos queue on the phone and upload when possible', (_) async {
    final visit = await repo.addVisit(shiftId, 'eco', 'EJ-5');
    final picture = File(join(dir.path, 'pic2_${DateTime.now().microsecondsSinceEpoch}.jpg'))..writeAsBytesSync([9, 9, 9]);
    final photoDir = Directory(join(dir.path, 'photos_test2'));
    final photoId = await repo.addPhoto(shiftId: shiftId, kind: 'disposal_ticket', entityType: 'disposal_visit',
        entityId: visit, picture: picture, photoDir: photoDir);

    final row = await db.get('SELECT * FROM photo WHERE id = ?', [photoId]);
    expect(row['storage_path'], '$shiftId/$photoId.jpg');
    expect(await repo.pendingPhotoUploads().first, 1);
    final local = File(join(photoDir.path, '$photoId.jpg'));
    expect(local.existsSync(), isTrue);

    final bucket = FakeBucket()..failWith = const SocketException('no signal');
    final uploader = PhotoUploader(db, bucketOverride: bucket);
    expect(await uploader.runOnce(), 0);
    expect(await repo.pendingPhotoUploads().first, 1, reason: 'kept for retry while offline');
    expect((await db.get('SELECT attempts FROM photo_upload_queue'))['attempts'], 1);

    bucket.failWith = null;
    expect(await uploader.runOnce(), 1);
    expect(bucket.uploaded, ['$shiftId/$photoId.jpg']);
    expect(await repo.pendingPhotoUploads().first, 0);
    expect(local.existsSync(), isFalse, reason: 'local copy removed after upload');
  });

  testWidgets('an upload that already reached storage counts as done', (_) async {
    final visit = await repo.addVisit(shiftId, 'eco', 'EJ-6');
    final picture = File(join(dir.path, 'pic3_${DateTime.now().microsecondsSinceEpoch}.jpg'))..writeAsBytesSync([7]);
    await repo.addPhoto(shiftId: shiftId, kind: 'disposal_ticket', entityType: 'disposal_visit',
        entityId: visit, picture: picture, photoDir: Directory(join(dir.path, 'photos_test3')));
    final bucket = FakeBucket()..failWith = const StorageException('The resource already exists', statusCode: '409');
    expect(await PhotoUploader(db, bucketOverride: bucket).runOnce(), 1);
    expect(await repo.pendingPhotoUploads().first, 0);
  });

  testWidgets('deleting a visit removes its lines, photos and queued uploads', (_) async {
    final visit = await repo.addVisit(shiftId, 'eco', 'EJ-7');
    await repo.addLine(visit, 'garbage', 10);
    final picture = File(join(dir.path, 'pic4_${DateTime.now().microsecondsSinceEpoch}.jpg'))..writeAsBytesSync([5]);
    await repo.addPhoto(shiftId: shiftId, kind: 'disposal_ticket', entityType: 'disposal_visit',
        entityId: visit, picture: picture, photoDir: Directory(join(dir.path, 'photos_test4')));
    await repo.deleteVisit(visit);
    expect(await repo.visits(shiftId).first, isEmpty);
    expect((await db.get('SELECT count(*) AS n FROM disposal_material_txn'))['n'], 0);
    expect((await db.get('SELECT count(*) AS n FROM photo'))['n'], 0);
    expect(await repo.pendingPhotoUploads().first, 0);
  });

  testWidgets('a new visit and line upload with only phone-entered fields', (_) async {
    while (true) {
      final tx = await db.getNextCrudTransaction();
      if (tx == null) break;
      await tx.complete();
    }
    final visit = await repo.addVisit(shiftId, 'eco', 'EJ-8');
    await repo.addLine(visit, 'garbage', 120);
    final ops = <CrudEntry>[];
    while (true) {
      final tx = await db.getNextCrudTransaction();
      if (tx == null) break;
      ops.addAll(tx.crud);
      await tx.complete();
    }
    expect(ops.map((o) => o.table), ['disposal_visit', 'disposal_material_txn']);
    final line = ops.last.opData!;
    expect(line.keys.toSet(), {'disposal_visit_id', 'material_type_id', 'weight_kg', 'created_at'});
    expect(writablePrimaryKeys['disposal_material_txn'], 'material_txn_id');
  });

  testWidgets('background pass uploads queued photos and reports what is left', (_) async {
    final visit = await repo.addVisit(shiftId, 'eco', 'EJ-B');
    Future<void> queuePhoto(String name) async {
      final pic = File(join(dir.path, '${name}_${DateTime.now().microsecondsSinceEpoch}.jpg'))..writeAsBytesSync([1]);
      await repo.addPhoto(shiftId: shiftId, kind: 'disposal_ticket', entityType: 'disposal_visit',
          entityId: visit, picture: pic, photoDir: Directory(join(dir.path, 'photos_bg')));
    }

    await queuePhoto('a');
    await queuePhoto('b');
    expect(await unsentItems(db), greaterThanOrEqualTo(2), reason: 'rows + files waiting');

    final bucket = FakeBucket()..failWith = const SocketException('no signal');
    expect(await uploadPhotosInBackground(db: db, bucket: bucket), isFalse, reason: 'ask Android to retry');
    bucket.failWith = null;
    expect(await uploadPhotosInBackground(db: db, bucket: bucket), isTrue);
    expect(bucket.uploaded, hasLength(2));
    expect(await repo.pendingPhotoUploads().first, 0);
  });

  testWidgets('a photo that keeps failing stops blocking the background job', (_) async {
    final visit = await repo.addVisit(shiftId, 'eco', 'EJ-C');
    final pic = File(join(dir.path, 'c_${DateTime.now().microsecondsSinceEpoch}.jpg'))..writeAsBytesSync([1]);
    await repo.addPhoto(shiftId: shiftId, kind: 'disposal_ticket', entityType: 'disposal_visit',
        entityId: visit, picture: pic, photoDir: Directory(join(dir.path, 'photos_bg2')));
    await db.execute('UPDATE photo_upload_queue SET attempts = 20');
    final bucket = FakeBucket()..failWith = const StorageException('forbidden', statusCode: '403');
    expect(await uploadPhotosInBackground(db: db, bucket: bucket), isTrue);
    expect(await repo.pendingPhotoUploads().first, 1, reason: 'kept on the phone, retried by the in-app uploader');
  });

  testWidgets('Android accepts the background upload schedule', (_) async {
    if (!Platform.isAndroid) return;
    await initBackgroundUploads();
    await schedulePhotoUpload();
    await schedulePhotoUpload(); // a second request while one is pending is ignored, not an error
    await Workmanager().cancelAll();
  });
}
