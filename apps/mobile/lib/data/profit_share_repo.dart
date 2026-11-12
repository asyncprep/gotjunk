import 'field_repo.dart';
import 'profit_share.dart';
import 'repo.dart';

/// One shift_crew_member row with its rank's % (a person who left and came back has several).
typedef CrewRow = ({
  String employeeId,
  String? name,
  DateTime? joined,
  DateTime? left,
  double? low,
  double? mid,
  double? high,
  bool toTrainer,
  bool trainer,
  bool damageHold,
});

/// Everything the live profit share needs, read from the phone (works offline). Hours depend on
/// the time of day, so the result is computed with [ProfitShareData.compute] at display time.
class ProfitShareData {
  const ProfitShareData({
    required this.plan,
    required this.route,
    required this.start,
    required this.finish,
    required this.crew,
  });
  final ProfitSharePlan plan;
  /// Route totals and inputs; crew hours are filled in by [compute].
  final RouteShareInput route;
  final DateTime? start;
  final DateTime? finish;
  final List<CrewRow> crew;

  bool get live => start != null && finish == null;

  ProfitShareResult compute(DateTime now) {
    // One line per person, even if they left and came back.
    final byPerson = <String, CrewShareInput>{};
    for (final c in crew) {
      final h = crewHours(routeStart: start, routeFinish: finish, joinedAt: c.joined, leftAt: c.left, now: now);
      final prior = byPerson[c.employeeId];
      byPerson[c.employeeId] = CrewShareInput(
        employeeId: c.employeeId,
        name: c.name,
        hours: (prior?.hours ?? 0) + h,
        pctLowCogs: c.low,
        pctMidCogs: c.mid,
        pctHighCogs: c.high,
        shareToTrainer: c.toTrainer,
        // A flag on any of their rows counts.
        trainer: c.trainer || (prior?.trainer ?? false),
        damageHold: c.damageHold || (prior?.damageHold ?? false),
      );
    }
    return computeProfitShare(plan, RouteShareInput(
      revenue: route.revenue,
      jobs: route.jobs,
      cancels: route.cancels,
      dumps: route.dumps,
      crew: byPerson.values.toList(),
      hoursType: route.hoursType,
      fuelMode: route.fuelMode,
      swingTrucks: route.swingTrucks,
      trainingDay: route.trainingDay,
      trainingHoursRemoved: route.trainingHoursRemoved,
    ));
  }
}

extension ProfitShareRepo on Repo {
  Stream<ProfitShareData?> profitShareData(String shiftId) => db.watch('''
      SELECT s.start_time, s.finish_time, s.hours_type, s.fuel_mode, s.swing_truck, s.swing_truck_count, s.training_day,
        s.training_hours_removed,
        m.employee_id, e.full_name, m.joined_at, m.left_at, m.trainer, m.damage_hold,
        r.share_pct_low_cogs, r.share_pct_mid_cogs, r.share_pct_high_cogs, r.share_to_trainer,
        (SELECT coalesce(sum(j.revenue_pre_tax), 0) FROM job j WHERE j.shift_id = s.id AND j.outcome = 'completed') AS revenue,
        (SELECT count(*) FROM job j WHERE j.shift_id = s.id AND j.outcome = 'completed') AS jobs,
        (SELECT count(*) FROM job j WHERE j.shift_id = s.id
           AND j.outcome IN ('cancelled_pending', 'cancelled_confirmed')) AS cancels,
        (SELECT coalesce(sum($lineAmountSql), 0)
           FROM disposal_material_txn t JOIN disposal_visit v ON v.id = t.disposal_visit_id
           $rateJoinSql
           WHERE v.shift_id = s.id) AS dumps,
        (SELECT value FROM app_setting WHERE id = 'profit_share_plan') AS plan
      FROM shift s
      LEFT JOIN shift_crew_member m ON m.shift_id = s.id
      LEFT JOIN employee e ON e.id = m.employee_id
      LEFT JOIN rank r ON r.id = m.rank_id_snapshot
      WHERE s.id = ?
      ORDER BY m.joined_at, e.full_name''', parameters: [shiftId]).map((rows) {
        if (rows.isEmpty) return null;
        final r = rows.first;
        double n(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
        double? pct(Object? v) => v == null ? null : n(v);
        DateTime? time(Object? v) => v == null ? null : DateTime.tryParse('$v');
        return ProfitShareData(
          plan: ProfitSharePlan.fromSetting(r['plan']),
          start: time(r['start_time']),
          finish: time(r['finish_time']),
          route: RouteShareInput(
            revenue: n(r['revenue']),
            jobs: (r['jobs'] as int?) ?? 0,
            cancels: (r['cancels'] as int?) ?? 0,
            dumps: n(r['dumps']),
            crew: const [],
            hoursType: r['hours_type'] as String?,
            fuelMode: (r['fuel_mode'] as String?) ?? 'one_truck',
            // Until the new column has synced, only the old yes/no is on the phone.
            swingTrucks: (r['swing_truck_count'] as int?) ?? (r['swing_truck'] == 1 ? 1 : 0),
            trainingDay: r['training_day'] == 1,
            trainingHoursRemoved: n(r['training_hours_removed']),
          ),
          crew: [
            for (final c in rows)
              if (c['employee_id'] != null)
                (
                  employeeId: c['employee_id'] as String,
                  name: c['full_name'] as String?,
                  joined: time(c['joined_at']),
                  left: time(c['left_at']),
                  low: pct(c['share_pct_low_cogs']),
                  mid: pct(c['share_pct_mid_cogs']),
                  high: pct(c['share_pct_high_cogs']),
                  toTrainer: c['share_to_trainer'] == 1,
                  trainer: c['trainer'] == 1,
                  damageHold: c['damage_hold'] == 1,
                ),
          ],
        );
      });

  // The route sheet's questions the crew lead answers (only these columns are sent).

  Future<void> setFuelMode(String shiftId, String mode) =>
      db.execute('UPDATE shift SET fuel_mode = ? WHERE id = ?', [mode, shiftId]);

  Future<void> setSwingTrucks(String shiftId, int count) =>
      db.execute('UPDATE shift SET swing_truck_count = ? WHERE id = ?', [count, shiftId]);

  Future<void> setTraining(String shiftId, {required bool day, required double hoursRemoved}) => db.execute(
      'UPDATE shift SET training_day = ?, training_hours_removed = ? WHERE id = ?',
      [day ? 1 : 0, day ? hoursRemoved : 0, shiftId]);
}
