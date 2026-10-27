import 'package:intl/intl.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

/// Statuses in which the crew may change their shift (server enforces the same rule).
const crewEditableStatuses = {'open', 'in_progress', 'returned', 'reopened'};
const crewJobStatuses = {'in_progress', 'returned', 'reopened'};

String nowUtc() => DateTime.now().toUtc().toIso8601String();
String todayLocal() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// All reads and writes the crew app makes against the on-phone database.
class Repo {
  Repo(this.db);
  final PowerSyncDatabase db;
  static const _uuid = Uuid();

  // ---- Reads (live: they re-emit whenever the data changes, synced or local) ----

  Stream<String?> myEmployeeId(String userId) => db
      .watch('SELECT employee_id FROM app_user WHERE id = ?', parameters: [userId])
      .map((rows) => rows.isEmpty ? null : rows.first['employee_id'] as String?);

  /// Today's shift, or an earlier one still waiting on the crew (returned/reopened/unfinished).
  Stream<Map<String, dynamic>?> currentShift(String employeeId) => db.watch('''
      SELECT s.*, t.unit_number AS truck, p.label AS phone
      FROM shift s
      JOIN shift_crew_member m ON m.shift_id = s.id
      LEFT JOIN truck t ON t.id = s.truck_id
      LEFT JOIN phone p ON p.id = s.phone_id
      WHERE m.employee_id = ?
        AND (s.shift_date = ? OR s.status IN ('in_progress', 'returned', 'reopened'))
        AND s.status <> 'archived'
      ORDER BY s.shift_date DESC
      LIMIT 1''', parameters: [employeeId, todayLocal()]).map((rows) => rows.isEmpty ? null : Map.of(rows.first));

  Stream<List<Map<String, dynamic>>> crew(String shiftId) => db.watch('''
      SELECT m.employee_id, e.full_name, m.joined_at, m.left_at
      FROM shift_crew_member m LEFT JOIN employee e ON e.id = m.employee_id
      WHERE m.shift_id = ? ORDER BY m.joined_at, e.full_name''', parameters: [shiftId]).map(_list);

  Stream<List<Map<String, dynamic>>> jobs(String shiftId) => db.watch(
      'SELECT * FROM job WHERE shift_id = ? ORDER BY created_at, id', parameters: [shiftId]).map(_list);

  /// Live scoreboard, calculated on the phone so it works offline.
  Stream<Scoreboard> scoreboard(String shiftId, String employeeId) => db.watch('''
      SELECT
        count(*) FILTER (WHERE j.outcome = 'completed') AS jobs,
        coalesce(sum(j.revenue_pre_tax) FILTER (WHERE j.outcome = 'completed'), 0) AS revenue,
        coalesce(sum(j.tip_amount) FILTER (WHERE j.outcome = 'completed'), 0) AS tips,
        coalesce(sum(
          CASE WHEN j.outcome = 'completed' AND j.tip_amount > 0 AND EXISTS (
            SELECT 1 FROM shift_crew_member me WHERE me.shift_id = j.shift_id AND me.employee_id = ?
              AND me.joined_at <= coalesce(j.completed_at, j.created_at)
              AND (me.left_at IS NULL OR me.left_at > coalesce(j.completed_at, j.created_at)))
          THEN j.tip_amount / (
            SELECT count(*) FROM shift_crew_member m WHERE m.shift_id = j.shift_id
              AND m.joined_at <= coalesce(j.completed_at, j.created_at)
              AND (m.left_at IS NULL OR m.left_at > coalesce(j.completed_at, j.created_at)))
          END), 0) AS my_tips
      FROM job j WHERE j.shift_id = ?''', parameters: [employeeId, shiftId]).map((rows) {
        final r = rows.first;
        return Scoreboard(
          jobs: (r['jobs'] as int?) ?? 0,
          revenue: _num(r['revenue']),
          tips: _num(r['tips']),
          myTips: _num(r['my_tips']),
        );
      });

  Stream<List<Map<String, dynamic>>> paymentMethods() => db.watch(
      'SELECT id, name_fr, name_en, is_cash FROM payment_method WHERE coalesce(active, 1) = 1 ORDER BY id').map(_list);

  Stream<List<Map<String, dynamic>>> rejections() =>
      db.watch('SELECT * FROM sync_rejection ORDER BY created_at DESC').map(_list);

  Stream<int> pendingUploads() =>
      db.watch('SELECT count(*) AS n FROM ps_crud').map((rows) => (rows.first['n'] as int?) ?? 0);

  Future<double> salesTaxRate() async {
    final row = await db.getOptional("SELECT value FROM app_setting WHERE id = 'sales_tax_rate'");
    return double.tryParse('${row?['value'] ?? ''}'.replaceAll('"', '')) ?? 0.14975;
  }

  // ---- Writes (saved on the phone immediately, uploaded when there is signal) ----

  Future<void> startShift(String shiftId, String hoursType) => db.execute(
      "UPDATE shift SET hours_type = ?, status = 'in_progress' WHERE id = ?", [hoursType, shiftId]);

  Future<void> setHoursType(String shiftId, String hoursType) =>
      db.execute('UPDATE shift SET hours_type = ? WHERE id = ?', [hoursType, shiftId]);

  Future<void> submitShift(String shiftId) => db.execute(
      "UPDATE shift SET finish_time = coalesce(finish_time, ?), status = 'submitted' WHERE id = ?",
      [nowUtc(), shiftId]);

  Future<void> saveJob(JobDraft job) async {
    if (job.id == null) {
      await db.execute('''
          INSERT INTO job (id, shift_id, opportunity_id, outcome, payment_method_code, discount_amount,
                           revenue_pre_tax, revenue_total_incl_tax, tip_amount, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', [
        _uuid.v7(), job.shiftId, job.opportunityId, job.outcome, job.paymentMethod, job.discount,
        job.preTax, job.total, job.tip, nowUtc(),
      ]);
    } else {
      await db.execute('''
          UPDATE job SET opportunity_id = ?, outcome = ?, payment_method_code = ?, discount_amount = ?,
                         revenue_pre_tax = ?, revenue_total_incl_tax = ?, tip_amount = ?
          WHERE id = ?''', [
        job.opportunityId, job.outcome, job.paymentMethod, job.discount, job.preTax, job.total, job.tip, job.id,
      ]);
    }
  }

  Future<void> deleteJob(String jobId) => db.execute('DELETE FROM job WHERE id = ?', [jobId]);

  Future<void> dismissRejection(String id) => db.execute('DELETE FROM sync_rejection WHERE id = ?', [id]);

  static List<Map<String, dynamic>> _list(Iterable<Map<String, dynamic>> rows) =>
      rows.map(Map<String, dynamic>.of).toList();
  static double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}

class Scoreboard {
  const Scoreboard({required this.jobs, required this.revenue, required this.tips, required this.myTips});
  final int jobs;
  final double revenue;
  final double tips;
  final double myTips;
}

class JobDraft {
  JobDraft({
    this.id,
    required this.shiftId,
    required this.opportunityId,
    required this.outcome,
    this.paymentMethod,
    this.discount = 0,
    this.preTax,
    this.total,
    this.tip = 0,
  });
  final String? id;
  final String shiftId;
  final String opportunityId;
  final String? outcome; // null = draft
  final String? paymentMethod;
  final double discount;
  final double? preTax;
  final double? total;
  final double tip;
}
