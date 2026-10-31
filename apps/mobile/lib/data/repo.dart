import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

import '../business_time.dart';

/// Statuses in which the crew may change their shift (server enforces the same rule).
const crewEditableStatuses = {'open', 'in_progress', 'returned', 'reopened'};
const crewJobStatuses = {'in_progress', 'returned', 'reopened'};

String nowUtc() => DateTime.now().toUtc().toIso8601String();
/// Today's business (Montréal) date; shifts are dated by it.
String todayLocal() => businessToday();

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
  /// A truck can run two shifts a day: one the crew can still work on comes before a submitted one.
  Stream<Map<String, dynamic>?> currentShift(String employeeId) => db.watch('''
      SELECT s.*, t.unit_number AS truck, p.label AS phone
      FROM shift s
      JOIN shift_crew_member m ON m.shift_id = s.id
      LEFT JOIN truck t ON t.id = s.truck_id
      LEFT JOIN phone p ON p.id = s.phone_id
      WHERE m.employee_id = ?
        AND (s.shift_date = ? OR s.status IN ('in_progress', 'returned', 'reopened'))
        AND s.status <> 'archived'
      ORDER BY s.status IN ('open', 'in_progress', 'returned', 'reopened') DESC, s.shift_date DESC,
        coalesce(s.start_time, '') DESC
      LIMIT 1''', parameters: [employeeId, todayLocal()]).map((rows) => rows.isEmpty ? null : Map.of(rows.first));

  Stream<List<Map<String, dynamic>>> crew(String shiftId) => db.watch('''
      SELECT m.employee_id, e.full_name, m.joined_at, m.left_at
      FROM shift_crew_member m LEFT JOIN employee e ON e.id = m.employee_id
      WHERE m.shift_id = ? ORDER BY m.joined_at, e.full_name''', parameters: [shiftId]).map(_list);

  Stream<List<Map<String, dynamic>>> jobs(String shiftId) => db.watch('''
      SELECT j.*, r.name_fr AS reason_fr, r.name_en AS reason_en
      FROM job j LEFT JOIN cancellation_reason r ON r.id = j.cancellation_reason_id
      WHERE j.shift_id = ? ORDER BY j.created_at, j.id''', parameters: [shiftId]).map(_list);

  /// Who may change the shift from this phone: only the lead's login. With no lead, or once the
  /// lead has left, the signed-in crew member can take over.
  Stream<LeadState> lead(String shiftId, String employeeId) => db.watch('''
      SELECT s.lead_employee_id AS lead_id, e.full_name AS lead_name,
        EXISTS (SELECT 1 FROM shift_crew_member m WHERE m.shift_id = s.id AND m.employee_id = s.lead_employee_id
                  AND m.left_at IS NOT NULL AND julianday(m.left_at) <= julianday('now')) AS lead_left,
        EXISTS (SELECT 1 FROM shift_crew_member m WHERE m.shift_id = s.id AND m.employee_id = ?
                  AND (m.left_at IS NULL OR julianday(m.left_at) > julianday('now'))) AS me_on_crew,
        EXISTS (SELECT 1 FROM lead_claim c WHERE c.shift_id = s.id AND c.employee_id = ?) AS claimed
      FROM shift s LEFT JOIN employee e ON e.id = s.lead_employee_id
      WHERE s.id = ?''', parameters: [employeeId, employeeId, shiftId]).map((rows) {
        final r = rows.isEmpty ? const <String, dynamic>{} : rows.first;
        final leadId = r['lead_id'] as String?;
        final open = leadId == null || r['lead_left'] == 1;
        return LeadState(
          leadName: leadId == null ? null : r['lead_name'] as String?,
          leadLeft: leadId != null && r['lead_left'] == 1,
          isMe: leadId == employeeId || (open && r['claimed'] == 1),
          canTakeOver: open && r['claimed'] != 1 && r['me_on_crew'] == 1,
        );
      });

  /// The server makes the next crew login to change the shift its lead. This change is queued
  /// before anything else this person does, so their jobs and disposal arrive after the takeover.
  Future<void> takeOver(String shiftId, String employeeId) => db.writeTransaction((tx) async {
        await tx.execute('INSERT INTO lead_claim (id, shift_id, employee_id) VALUES (?, ?, ?)',
            [_uuid.v7(), shiftId, employeeId]);
        await tx.execute('UPDATE shift SET truck_phone_confirmed_at = ? WHERE id = ?', [nowUtc(), shiftId]);
      });

  /// Live scoreboard, calculated on the phone so it works offline.
  Stream<Scoreboard> scoreboard(String shiftId) => db.watch('''
      SELECT
        count(*) FILTER (WHERE j.outcome = 'completed') AS jobs,
        coalesce(sum(j.revenue_pre_tax) FILTER (WHERE j.outcome = 'completed'), 0) AS revenue,
        coalesce(sum(j.tip_amount) FILTER (WHERE j.outcome = 'completed'), 0) AS tips
      FROM job j WHERE j.shift_id = ?''', parameters: [shiftId]).map((rows) {
        final r = rows.first;
        return Scoreboard(jobs: (r['jobs'] as int?) ?? 0, revenue: _num(r['revenue']), tips: _num(r['tips']));
      });

  /// Each crew member's share of the tips: a tip is split among the crew on the truck when the
  /// job was completed. The phone is shared, so everyone's share shows.
  Stream<List<TipShare>> tipShares(String shiftId) => db.watch('''
      SELECT m.employee_id, e.full_name,
        coalesce(sum(j.tip_amount / (
          SELECT count(*) FROM shift_crew_member o WHERE o.shift_id = j.shift_id
            AND julianday(o.joined_at) <= julianday(coalesce(j.completed_at, j.created_at))
            AND (o.left_at IS NULL OR julianday(o.left_at) > julianday(coalesce(j.completed_at, j.created_at))))), 0) AS tips
      FROM shift_crew_member m
      LEFT JOIN employee e ON e.id = m.employee_id
      LEFT JOIN job j ON j.shift_id = m.shift_id AND j.outcome = 'completed' AND j.tip_amount > 0
        AND julianday(m.joined_at) <= julianday(coalesce(j.completed_at, j.created_at))
        AND (m.left_at IS NULL OR julianday(m.left_at) > julianday(coalesce(j.completed_at, j.created_at)))
      WHERE m.shift_id = ?
      GROUP BY m.employee_id, e.full_name
      ORDER BY min(m.joined_at), e.full_name''', parameters: [shiftId]).map((rows) => [
            for (final r in rows)
              TipShare(employeeId: r['employee_id'] as String, name: r['full_name'] as String?, amount: _num(r['tips'])),
          ]);

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

  /// The start time is the phone's: offline, the server would otherwise stamp it at upload.
  Future<void> startShift(String shiftId, String hoursType) => db.execute(
      "UPDATE shift SET hours_type = ?, start_time = coalesce(start_time, ?), status = 'in_progress' WHERE id = ?",
      [hoursType, nowUtc(), shiftId]);

  Future<void> setHoursType(String shiftId, String hoursType) =>
      db.execute('UPDATE shift SET hours_type = ? WHERE id = ?', [hoursType, shiftId]);

  Future<void> submitShift(String shiftId) => db.execute(
      "UPDATE shift SET finish_time = coalesce(finish_time, ?), status = 'submitted' WHERE id = ?",
      [nowUtc(), shiftId]);

  /// completed_at is the moment the phone marked the job completed: it decides who shares the tip.
  Future<void> saveJob(JobDraft job) async {
    final now = nowUtc();
    if (job.id == null) {
      await db.execute('''
          INSERT INTO job (id, shift_id, opportunity_id, outcome, payment_method_code, discount_amount,
                           revenue_pre_tax, revenue_total_incl_tax, tip_amount, completed_at, created_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''', [
        _uuid.v7(), job.shiftId, job.opportunityId, job.outcome, job.paymentMethod, job.discount,
        job.preTax, job.total, job.tip, job.outcome == 'completed' ? now : null, now,
      ]);
    } else {
      await db.execute('''
          UPDATE job SET opportunity_id = ?, outcome = ?, payment_method_code = ?, discount_amount = ?,
                         revenue_pre_tax = ?, revenue_total_incl_tax = ?, tip_amount = ?,
                         completed_at = CASE WHEN ? = 'completed' THEN coalesce(completed_at, ?) END
          WHERE id = ?''', [
        job.opportunityId, job.outcome, job.paymentMethod, job.discount, job.preTax, job.total, job.tip,
        job.outcome, now, job.id,
      ]);
    }
  }

  /// The server refuses a second job with the same opportunity on one shift; say so before saving.
  Future<bool> opportunityTaken(String shiftId, String opportunityId, {String? exceptJobId}) async {
    final row = await db.getOptional(
        'SELECT 1 FROM job WHERE shift_id = ? AND upper(opportunity_id) = upper(?) AND id IS NOT ?',
        [shiftId, opportunityId, exceptJobId]);
    return row != null;
  }

  Future<void> deleteJob(String jobId) => db.execute('DELETE FROM job WHERE id = ?', [jobId]);

  Future<void> dismissRejection(String id) => db.execute('DELETE FROM sync_rejection WHERE id = ?', [id]);

  static List<Map<String, dynamic>> _list(Iterable<Map<String, dynamic>> rows) =>
      rows.map(Map<String, dynamic>.of).toList();
  static double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
}

class Scoreboard {
  const Scoreboard({required this.jobs, required this.revenue, required this.tips});
  final int jobs;
  final double revenue;
  final double tips;
}

class TipShare {
  const TipShare({required this.employeeId, required this.name, required this.amount});
  final String employeeId;
  final String? name;
  final double amount;
}

class LeadState {
  const LeadState({this.leadName, this.leadLeft = false, this.isMe = false, this.canTakeOver = false});
  /// The lead's name; null when the shift has no lead.
  final String? leadName;
  final bool leadLeft;
  /// This login may change the shift.
  final bool isMe;
  /// No lead, or the lead left: this crew member can take over the phone.
  final bool canTakeOver;
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
