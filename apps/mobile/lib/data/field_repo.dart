import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'repo.dart';

const _uuid = Uuid();

/// Local estimate of a disposal line's amount, mirroring the server's pricing
/// (metric tonnes; minimum applied per weigh-in to costs only; credits negative).
/// The server's figure replaces it once synced.
const lineAmountSql = '''
  coalesce(t.signed_amount, round(
    max(t.weight_kg, CASE WHEN r.min_applies_to = 'transaction' THEN coalesce(r.min_billable_kg, 0) ELSE 0 END)
    / 1000.0 * r.rate_per_ton, 2)
    * CASE r.direction WHEN 'cost' THEN 1 WHEN 'credit' THEN -1 ELSE 0 END)''';

/// Rate in effect for the line: same site + material, active, covering the visit's local date.
const rateJoinSql = '''
  LEFT JOIN site_rate_config r
    ON r.site_id = v.site_id AND r.material_type_id = t.material_type_id AND coalesce(r.active, 1) = 1
   AND date(v.visit_at, 'localtime') >= r.effective_from
   AND (r.effective_to IS NULL OR date(v.visit_at, 'localtime') <= r.effective_to)''';

/// Disposal, cash, photos and the pre-submit checks.
extension FieldRepo on Repo {
  // ---- Reference lists ----

  Stream<List<Map<String, dynamic>>> sites() => db
      .watch('SELECT * FROM site WHERE coalesce(active, 1) = 1 ORDER BY name')
      .map((rows) => rows.map(Map<String, dynamic>.of).toList());

  /// Materials that have an active rate at this site today (others would be refused).
  Stream<List<Map<String, dynamic>>> materialsForSite(String siteId) => db.watch('''
      SELECT DISTINCT m.* FROM material_type m
      JOIN site_rate_config r ON r.material_type_id = m.id AND r.site_id = ? AND coalesce(r.active, 1) = 1
       AND date('now', 'localtime') >= r.effective_from
       AND (r.effective_to IS NULL OR date('now', 'localtime') <= r.effective_to)
      WHERE coalesce(m.active, 1) = 1
      ORDER BY m.code''', parameters: [siteId]).map((rows) => rows.map(Map<String, dynamic>.of).toList());

  // ---- Disposal ----

  Stream<List<Map<String, dynamic>>> visits(String shiftId) => db.watch('''
      SELECT v.*, s.name AS site_name, s.issues_tickets, s.requires_ticket_photo,
        (SELECT count(*) FROM photo ph WHERE ph.entity_id = v.id) AS photos
      FROM disposal_visit v LEFT JOIN site s ON s.id = v.site_id
      WHERE v.shift_id = ? ORDER BY v.visit_at, v.id''', parameters: [shiftId])
      .map((rows) => rows.map(Map<String, dynamic>.of).toList());

  Stream<List<Map<String, dynamic>>> lines(String visitId) => db.watch('''
      SELECT t.*, m.name_fr, m.name_en, r.rate_per_ton, r.direction AS rate_direction,
        $lineAmountSql AS amount,
        t.signed_amount IS NOT NULL AS confirmed
      FROM disposal_material_txn t
      JOIN disposal_visit v ON v.id = t.disposal_visit_id
      LEFT JOIN material_type m ON m.id = t.material_type_id
      $rateJoinSql
      WHERE t.disposal_visit_id = ? ORDER BY t.created_at, t.id''', parameters: [visitId])
      .map((rows) => rows.map(Map<String, dynamic>.of).toList());

  Stream<double> netDisposal(String shiftId) => db.watch('''
      SELECT coalesce(sum($lineAmountSql), 0) AS net
      FROM disposal_material_txn t
      JOIN disposal_visit v ON v.id = t.disposal_visit_id
      $rateJoinSql
      WHERE v.shift_id = ?''', parameters: [shiftId]).map((rows) => _num(rows.first['net']));

  Future<String> addVisit(String shiftId, String siteId, String? ticketNumber) async {
    final id = _uuid.v7();
    await db.execute(
        'INSERT INTO disposal_visit (id, shift_id, site_id, visit_at, ticket_number, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        [id, shiftId, siteId, nowUtc(), _blankToNull(ticketNumber), nowUtc()]);
    return id;
  }

  Future<void> updateVisit(String visitId, {required String siteId, String? ticketNumber}) => db.execute(
      'UPDATE disposal_visit SET site_id = ?, ticket_number = ? WHERE id = ?',
      [siteId, _blankToNull(ticketNumber), visitId]);

  Future<void> deleteVisit(String visitId) => db.writeTransaction((tx) async {
        await tx.execute('DELETE FROM disposal_material_txn WHERE disposal_visit_id = ?', [visitId]);
        await tx.execute('DELETE FROM photo WHERE entity_id = ?', [visitId]);
        await tx.execute('DELETE FROM photo_upload_queue WHERE photo_id NOT IN (SELECT id FROM photo)');
        await tx.execute('DELETE FROM disposal_visit WHERE id = ?', [visitId]);
      });

  Future<void> addLine(String visitId, String materialTypeId, double weightKg) => db.execute(
      'INSERT INTO disposal_material_txn (id, disposal_visit_id, material_type_id, weight_kg, created_at) VALUES (?, ?, ?, ?, ?)',
      [_uuid.v7(), visitId, materialTypeId, weightKg, nowUtc()]);

  Future<void> deleteLine(String lineId) => db.execute('DELETE FROM disposal_material_txn WHERE id = ?', [lineId]);

  // ---- Cash ----

  /// Cash the crew should hand in: cash jobs' total incl. tax (+ tips when the setting says so).
  Stream<double> expectedCash(String shiftId) => db.watch('''
      SELECT coalesce(sum(j.revenue_total_incl_tax + CASE
          WHEN coalesce((SELECT value FROM app_setting WHERE id = 'cash_includes_tips'), 'true') = 'true'
          THEN j.tip_amount ELSE 0 END), 0) AS cash
      FROM job j JOIN payment_method pm ON pm.id = j.payment_method_code
      WHERE j.shift_id = ? AND j.outcome = 'completed' AND pm.is_cash = 1''', parameters: [shiftId])
      .map((rows) => _num(rows.first['cash']));

  Stream<Map<String, dynamic>?> cashSubmission(String shiftId) => db.watch('''
      SELECT c.*, (SELECT count(*) FROM photo ph WHERE ph.entity_id = c.id) AS photos
      FROM cash_submission c WHERE c.shift_id = ?''', parameters: [shiftId])
      .map((rows) => rows.isEmpty ? null : Map<String, dynamic>.of(rows.first));

  Future<String> ensureCashSubmission(String shiftId) async {
    final existing = await db.getOptional('SELECT id FROM cash_submission WHERE shift_id = ?', [shiftId]);
    if (existing != null) return existing['id'] as String;
    final id = _uuid.v7();
    await db.execute('INSERT INTO cash_submission (id, shift_id, created_at) VALUES (?, ?, ?)', [id, shiftId, nowUtc()]);
    return id;
  }

  // ---- Photos ----

  /// Keeps the picture on the phone and records it; [PhotoUploader] sends the file when online.
  Future<String> addPhoto({
    required String shiftId,
    required String kind, // disposal_ticket | cash_submission
    required String entityType, // disposal_visit | cash_submission
    required String entityId,
    required File picture,
    required Directory photoDir,
  }) async {
    final id = _uuid.v7();
    final storagePath = '$shiftId/$id.jpg';
    await photoDir.create(recursive: true);
    final local = await picture.copy(p.join(photoDir.path, '$id.jpg'));
    await db.writeTransaction((tx) async {
      await tx.execute(
          'INSERT INTO photo (id, shift_id, photo_kind, entity_type, entity_id, storage_path, captured_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
          [id, shiftId, kind, entityType, entityId, storagePath, nowUtc()]);
      await tx.execute(
          'INSERT INTO photo_upload_queue (id, photo_id, local_path, storage_path, attempts) VALUES (?, ?, ?, ?, 0)',
          [id, id, local.path, storagePath]);
    });
    return id;
  }

  Stream<int> pendingPhotoUploads() => db
      .watch('SELECT count(*) AS n FROM photo_upload_queue')
      .map((rows) => (rows.first['n'] as int?) ?? 0);

  // ---- Pre-submit checks (same codes as the server's shift_problems) ----

  Future<List<String>> readinessProblems(String shiftId) async {
    final problems = <String>[];
    final shift = await db.getOptional('SELECT hours_type, start_time FROM shift WHERE id = ?', [shiftId]);
    if (shift == null) return ['shift_not_found'];
    if (shift['hours_type'] == null) problems.add('hours_type_missing');

    final crew = await db.get(
        'SELECT count(*) AS n FROM shift_crew_member WHERE shift_id = ? AND left_at IS NULL', [shiftId]);
    final min = await _setting('crew_min', 2);
    final max = await _setting('crew_max', 3);
    final n = crew['n'] as int;
    if (n < min || n > max) problems.add('crew_size');

    final drafts = await db.get(
        'SELECT count(*) AS n FROM job WHERE shift_id = ? AND outcome IS NULL', [shiftId]);
    if ((drafts['n'] as int) > 0) problems.add('job_incomplete');

    final visits = await db.getAll('''
        SELECT v.id, v.ticket_number, s.issues_tickets, s.requires_ticket_photo,
          (SELECT count(*) FROM photo ph WHERE ph.entity_id = v.id) AS photos,
          (SELECT count(*) FROM disposal_material_txn t WHERE t.disposal_visit_id = v.id) AS lines
        FROM disposal_visit v LEFT JOIN site s ON s.id = v.site_id WHERE v.shift_id = ?''', [shiftId]);
    for (final v in visits) {
      if (v['issues_tickets'] == 1 && '${v['ticket_number'] ?? ''}'.trim().isEmpty) {
        problems.add('ticket_number_missing');
      }
      if (v['requires_ticket_photo'] == 1 && (v['photos'] as int) == 0) problems.add('ticket_photo_missing');
      if ((v['lines'] as int) == 0) problems.add('visit_no_materials');
    }

    final cash = await expectedCash(shiftId).first;
    if (cash > 0) {
      final photos = await db.get('''
          SELECT count(*) AS n FROM photo WHERE shift_id = ? AND photo_kind = 'cash_submission' ''', [shiftId]);
      if ((photos['n'] as int) == 0) problems.add('cash_photo_missing');
    }
    return problems.toSet().toList();
  }

  Future<int> _setting(String key, int fallback) async {
    final row = await db.getOptional('SELECT value FROM app_setting WHERE id = ?', [key]);
    return int.tryParse('${row?['value'] ?? ''}'.replaceAll('"', '')) ?? fallback;
  }
}

String? _blankToNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
