// Runs on a device or emulator against a real on-phone PowerSync database (not connected to
// any server): checks the crew app's queries, writes and upload queue.
// flutter test integration_test -d <device>
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:truck_team_os/data/repo.dart';
import 'package:truck_team_os/data/schema.dart';

const user = 'u-1';
const me = 'e-1';
const mate = 'e-2';
const shiftId = 's-1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late PowerSyncDatabase db;
  late Repo repo;
  late String path;

  setUp(() async {
    final dir = await getTemporaryDirectory();
    path = join(dir.path, 'repo_test_${DateTime.now().microsecondsSinceEpoch}.db');
    db = PowerSyncDatabase(schema: schema, path: path);
    await db.initialize();
    repo = Repo(db);

    // Seed what sync would normally download. Server timestamps use a space separator
    // ("2026-10-27 13:00:00.000000Z"), unlike phone-created ones ("…T…Z").
    final hourAgo = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final serverTime = '${hourAgo.toIso8601String().replaceFirst('T', ' ').replaceFirst('Z', '')}000Z';
    await db.writeTransaction((tx) async {
      await tx.execute("INSERT INTO app_user (id, employee_id, role) VALUES (?, ?, 'ttm')", [user, me]);
      await tx.execute("INSERT INTO employee (id, full_name) VALUES (?, 'Crew One'), (?, 'Crew Two')", [me, mate]);
      await tx.execute("INSERT INTO truck (id, unit_number) VALUES ('t-1', 'T-01')");
      await tx.execute("INSERT INTO phone (id, label) VALUES ('p-1', 'P-01')");
      await tx.execute(
          "INSERT INTO payment_method (id, name_fr, name_en, is_cash, active) VALUES "
          "('card', 'Carte', 'Card', 0, 1), ('cash', 'Comptant', 'Cash', 1, 1), ('old', 'Vieux', 'Old', 0, 0)");
      await tx.execute("INSERT INTO app_setting (id, value) VALUES ('sales_tax_rate', '0.14975')");
      await tx.execute(
          "INSERT INTO shift (id, shift_date, status, truck_id, phone_id, lead_employee_id) VALUES (?, ?, 'open', 't-1', 'p-1', ?)",
          [shiftId, todayLocal(), me]);
      await tx.execute(
          'INSERT INTO shift_crew_member (id, shift_id, employee_id, joined_at) VALUES (?, ?, ?, ?), (?, ?, ?, ?)',
          ['m-1', shiftId, me, serverTime, 'm-2', shiftId, mate, serverTime]);
    });
    // Drop the seed's own upload entries: only the crew's actions should be queued.
    await _clearQueue(db);
  });

  tearDown(() async {
    await db.close();
    if (File(path).existsSync()) File(path).deleteSync();
  });

  testWidgets('finds my employee and today\'s shift with truck and phone', (_) async {
    expect(await repo.myEmployeeId(user).first, me);
    expect(await repo.myEmployeeId('nobody').first, isNull);
    final shift = await repo.currentShift(me).first;
    expect(shift?['id'], shiftId);
    expect(shift?['truck'], 'T-01');
    expect(shift?['phone'], 'P-01');
    final crew = await repo.crew(shiftId).first;
    expect(crew.map((c) => c['full_name']), ['Crew One', 'Crew Two']);
  });

  testWidgets('starting the shift queues one status change', (_) async {
    await repo.startShift(shiftId, 'regular_junk');
    final shift = await repo.currentShift(me).first;
    expect(shift?['status'], 'in_progress');
    expect(shift?['hours_type'], 'regular_junk');

    final tx = await db.getNextCrudTransaction();
    expect(tx!.crud, hasLength(1));
    expect(tx.crud.single.table, 'shift');
    expect(tx.crud.single.op, UpdateType.patch);
    final sent = tx.crud.single.opData!;
    expect(sent.keys.toSet(), {'hours_type', 'start_time', 'status'}, reason: 'only columns crew may change');
    expect(sent['status'], 'in_progress');
    expect(DateTime.now().toUtc().difference(DateTime.parse(sent['start_time'] as String)).inMinutes, 0,
        reason: "the phone's start time, not the upload time");
  });

  testWidgets('a completed job keeps the moment it was completed', (_) async {
    await repo.startShift(shiftId, 'regular_junk');
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'OPP-9', outcome: 'cancelled_pending'));
    final job = await db.get("SELECT id, completed_at FROM job WHERE opportunity_id = 'OPP-9'");
    expect(job['completed_at'], isNull);

    final draft = JobDraft(id: job['id'] as String, shiftId: shiftId, opportunityId: 'OPP-9', outcome: 'completed',
        paymentMethod: 'card', preTax: 100, total: 114.98);
    await repo.saveJob(draft);
    final completedAt = (await db.get('SELECT completed_at FROM job WHERE id = ?', [job['id']]))['completed_at'];
    expect(completedAt, isNotNull);
    await repo.saveJob(draft); // edited later: same completion time
    expect((await db.get('SELECT completed_at FROM job WHERE id = ?', [job['id']]))['completed_at'], completedAt);

    expect(await repo.opportunityTaken(shiftId, 'opp-9'), isTrue, reason: 'same number, any case');
    expect(await repo.opportunityTaken(shiftId, 'OPP-9', exceptJobId: job['id'] as String), isFalse);
  });

  testWidgets('a second shift the same day shows instead of the submitted first one', (_) async {
    await repo.startShift(shiftId, 'regular_junk');
    await repo.submitShift(shiftId);
    await db.writeTransaction((tx) async {
      await tx.execute(
          "INSERT INTO shift (id, shift_date, status, truck_id, phone_id) VALUES ('s-2', ?, 'open', 't-1', 'p-1')",
          [todayLocal()]);
      await tx.execute(
          "INSERT INTO shift_crew_member (id, shift_id, employee_id, joined_at) VALUES ('m-3', 's-2', ?, ?)",
          [me, nowUtc()]);
    });
    expect((await repo.currentShift(me).first)?['id'], 's-2');
  });

  testWidgets('scoreboard counts completed jobs and splits tips', (_) async {
    await repo.startShift(shiftId, 'regular_junk');
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'OPP-1', outcome: 'completed',
        paymentMethod: 'card', preTax: 200, total: 229.95, tip: 20));
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'OPP-2', outcome: 'cancelled_pending'));
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'OPP-3', outcome: null));

    var s = await repo.scoreboard(shiftId).first;
    expect(s.jobs, 1);
    expect(s.revenue, 200);
    expect(s.tips, 20);
    Map<String, double> shares(List<TipShare> l) => {for (final x in l) x.name ?? x.employeeId: x.amount};
    expect(shares(await repo.tipShares(shiftId).first), {'Crew One': 10, 'Crew Two': 10});

    // Crewmate leaves after OPP-1 (server-format timestamp); later tips go to whoever is still on the truck.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final left = DateTime.now().toUtc();
    await db.execute('UPDATE shift_crew_member SET left_at = ? WHERE id = ?',
        ['${left.toIso8601String().replaceFirst('T', ' ').replaceFirst('Z', '')}000Z', 'm-2']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(shares(await repo.tipShares(shiftId).first), {'Crew One': 10, 'Crew Two': 10},
        reason: 'OPP-1 still split with the crewmate');
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'OPP-4', outcome: 'completed',
        paymentMethod: 'cash', preTax: 100, total: 114.98, tip: 9));
    s = await repo.scoreboard(shiftId).first;
    expect(s.jobs, 2);
    expect(s.tips, 29);
    expect(shares(await repo.tipShares(shiftId).first), {'Crew One': 19, 'Crew Two': 10});
  });

  testWidgets('only the lead changes the shift; a crew member takes over once the lead has left', (_) async {
    var lead = await repo.lead(shiftId, me).first;
    expect(lead.isMe, isTrue);
    expect(lead.canTakeOver, isFalse);

    lead = await repo.lead(shiftId, mate).first;
    expect(lead.isMe, isFalse, reason: 'a crewmate signed in on the phone only views the shift');
    expect(lead.leadName, 'Crew One');
    expect(lead.canTakeOver, isFalse, reason: 'the lead is still on the truck');

    final past = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    await db.execute('UPDATE shift_crew_member SET left_at = ? WHERE id = ?',
        ['${past.toIso8601String().replaceFirst('T', ' ').replaceFirst('Z', '')}000Z', 'm-1']);
    await _clearQueue(db);
    lead = await repo.lead(shiftId, mate).first;
    expect(lead.leadLeft, isTrue);
    expect(lead.canTakeOver, isTrue);

    await repo.takeOver(shiftId, mate);
    lead = await repo.lead(shiftId, mate).first;
    expect(lead.isMe, isTrue);
    expect(lead.canTakeOver, isFalse);
    final tx = await db.getNextCrudTransaction();
    final op = tx!.crud.single;
    expect(op.table, 'shift', reason: 'the takeover is queued before anything the new lead enters');
    expect(op.opData!.keys.toSet(), {'truck_phone_confirmed_at'}, reason: 'crew may not send lead_employee_id');
  });

  testWidgets('a shift with no lead can be taken over', (_) async {
    await db.execute('UPDATE shift SET lead_employee_id = NULL WHERE id = ?', [shiftId]);
    final lead = await repo.lead(shiftId, mate).first;
    expect(lead.isMe, isFalse);
    expect(lead.leadName, isNull);
    expect(lead.canTakeOver, isTrue);
  });

  testWidgets('a new job uploads as an insert without server-calculated fields', (_) async {
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'OPP-9', outcome: 'completed',
        paymentMethod: 'card', preTax: 50, total: 57.49, tip: 0));
    final tx = await db.getNextCrudTransaction();
    final op = tx!.crud.single;
    expect(op.table, 'job');
    expect(op.op, UpdateType.put);
    expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7').hasMatch(op.id), isTrue, reason: 'UUIDv7 made on the phone');
    expect(op.opData!['opportunity_id'], 'OPP-9');
    expect(op.opData!.containsKey('expected_payment_total'), isFalse);
    expect(op.opData!.containsKey('id'), isFalse);
    expect(writablePrimaryKeys[op.table], 'job_id');
  });

  testWidgets('editing and deleting a job', (_) async {
    await repo.saveJob(JobDraft(shiftId: shiftId, opportunityId: 'OPP-5', outcome: 'completed',
        paymentMethod: 'card', preTax: 10, total: 11.50));
    final id = (await repo.jobs(shiftId).first).single['id'] as String;
    await repo.saveJob(JobDraft(id: id, shiftId: shiftId, opportunityId: 'OPP-5B', outcome: 'completed',
        paymentMethod: 'card', preTax: 20, total: 22.99));
    final job = (await repo.jobs(shiftId).first).single;
    expect(job['opportunity_id'], 'OPP-5B');
    expect(job['revenue_pre_tax'], 20);
    await repo.deleteJob(id);
    expect(await repo.jobs(shiftId).first, isEmpty);
  });

  testWidgets('submit stamps the finish time once and queues the change', (_) async {
    await repo.startShift(shiftId, 'regular_junk');
    await repo.submitShift(shiftId);
    final shift = (await db.get('SELECT status, finish_time FROM shift WHERE id = ?', [shiftId]));
    expect(shift['status'], 'submitted');
    expect(shift['finish_time'], isNotNull);
    expect(await repo.pendingUploads().first, greaterThan(0));
  });

  testWidgets('only active payment methods are offered; tax rate is read', (_) async {
    final methods = await repo.paymentMethods().first;
    expect(methods.map((m) => m['id']), ['card', 'cash']);
    expect(await repo.salesTaxRate(), closeTo(0.14975, 1e-9));
  });

  testWidgets('server refusals are stored locally and can be dismissed', (_) async {
    await db.execute(
        "INSERT INTO sync_rejection (id, table_name, record_id, code, message, created_at) "
        "VALUES ('r-1', 'shift', ?, 'P0001', 'shift_not_ready: finish_time_missing', ?)",
        [shiftId, nowUtc()]);
    expect((await repo.rejections().first).single['code'], 'P0001');
    expect(await repo.pendingUploads().first, 0, reason: 'local-only table is never uploaded');
    await repo.dismissRejection('r-1');
    expect(await repo.rejections().first, isEmpty);
  });

  testWidgets('no shift today shows nothing; a returned earlier shift still shows', (_) async {
    await db.execute("UPDATE shift SET shift_date = '2020-01-01', status = 'locked' WHERE id = ?", [shiftId]);
    expect(await repo.currentShift(me).first, isNull);
    await db.execute("UPDATE shift SET status = 'returned', return_reason = 'Fix ticket' WHERE id = ?", [shiftId]);
    expect((await repo.currentShift(me).first)?['return_reason'], 'Fix ticket');
  });
}

Future<void> _clearQueue(PowerSyncDatabase db) async {
  while (true) {
    final tx = await db.getNextCrudTransaction();
    if (tx == null) return;
    await tx.complete();
  }
}
