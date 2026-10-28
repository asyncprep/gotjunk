// Renders the real crew screens on a device over a local database and taps through them.
// Layout overflows or exceptions fail the test. flutter test integration_test -d <device>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:truck_team_os/data/photo_uploader.dart';
import 'package:truck_team_os/data/repo.dart';
import 'package:truck_team_os/data/schema.dart';
import 'package:truck_team_os/l10n/app_localizations.dart';
import 'package:truck_team_os/providers.dart';
import 'package:truck_team_os/ui/home_page.dart';

const user = 'u-1';
const shiftId = 's-1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late PowerSyncDatabase db;
  late String path;
  late Directory dir;

  Future<void> seed({String status = 'in_progress'}) => db.writeTransaction((tx) async {
        await tx.execute("INSERT INTO app_user (id, employee_id, role) VALUES (?, 'e1', 'ttm')", [user]);
        await tx.execute("INSERT INTO employee (id, full_name) VALUES ('e1', 'Crew One'), ('e2', 'Crew Two')");
        await tx.execute("INSERT INTO truck (id, unit_number) VALUES ('t1', 'T-01')");
        await tx.execute("INSERT INTO phone (id, label) VALUES ('p1', 'P-01')");
        await tx.execute(
            "INSERT INTO shift (id, shift_date, status, truck_id, phone_id, hours_type, start_time) VALUES (?, ?, ?, 't1', 'p1', 'regular_junk', ?)",
            [shiftId, todayLocal(), status, nowUtc()]);
        await tx.execute(
            "INSERT INTO shift_crew_member (id, shift_id, employee_id, joined_at) VALUES ('m1', ?, 'e1', '2020-01-01 00:00:00Z'), ('m2', ?, 'e2', '2020-01-01 00:00:00Z')",
            [shiftId, shiftId]);
        await tx.execute(
            "INSERT INTO payment_method (id, name_fr, name_en, is_cash, active) VALUES ('cash', 'Comptant', 'Cash', 1, 1), ('card', 'Carte', 'Card', 0, 1)");
        await tx.execute("INSERT INTO site (id, code, name, issues_tickets, requires_ticket_photo, active) VALUES ('eco', 'eco_junk', 'Eco-Junk', 1, 1, 1)");
        await tx.execute("INSERT INTO material_type (id, code, name_fr, name_en, active) VALUES ('garbage', 'garbage', 'Déchets', 'Garbage', 1)");
        await tx.execute(
            "INSERT INTO site_rate_config (id, site_id, material_type_id, rate_per_ton, direction, min_billable_kg, min_applies_to, effective_from, active) VALUES ('r1', 'eco', 'garbage', 150, 'cost', 0, 'transaction', '2026-01-01', 1)");
        await tx.execute(
            "INSERT INTO app_setting (id, value) VALUES ('sales_tax_rate', '0.14975'), ('cash_includes_tips', 'true'), ('crew_min', '2'), ('crew_max', '3')");
      });

  Widget app(Locale locale) => ProviderScope(
        overrides: [
          repoProvider.overrideWithValue(Repo(db)),
          photoDirProvider.overrideWithValue(Directory(join(dir.path, 'ui_photos'))),
          photoUploaderProvider.overrideWithValue(PhotoUploader(db)),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomePage(userId: user),
        ),
      );

  // Streams from the database arrive asynchronously; give them real time, then settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() async {
    dir = await getTemporaryDirectory();
    path = join(dir.path, 'ui_test_${DateTime.now().microsecondsSinceEpoch}.db');
    db = PowerSyncDatabase(schema: schema, path: path);
    await db.initialize();
  });

  tearDown(() async {
    await db.close();
    if (File(path).existsSync()) File(path).deleteSync();
  });

  testWidgets('shift screen shows the shift, scoreboard, jobs, disposal and cash (French)', (tester) async {
    await seed();
    await tester.pumpWidget(app(const Locale('fr')));
    await settle(tester);

    expect(find.textContaining('T-01'), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(find.textContaining('Crew One'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.textContaining('Hors ligne'), findsOneWidget, reason: 'no sync configured in tests');

    await tester.scrollUntilVisible(find.text('Soumettre le quart'), 300);
    expect(find.text('Dépotoir'), findsOneWidget);
    expect(find.text('Comptant'), findsOneWidget);
  });

  testWidgets('add a job through the form; the scoreboard updates', (tester) async {
    await seed();
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);

    await tester.tap(find.text('Add a job'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Opportunity ID'), 'OPP-77');
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Payment'));
    await settle(tester);
    await tester.tap(find.text('Card').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount before tax'), '200');
    await tester.tap(find.text('Calculate tax'));
    await settle(tester);
    expect(find.text('229.95'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Tip'), '20');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    expect(find.text('OPP-77'), findsOneWidget);
    expect(find.text('\$200.00'), findsWidgets);
    expect(find.text('\$10.00'), findsOneWidget, reason: 'my half of the tip');
  });

  testWidgets('job form rejects a total below the pre-tax amount', (tester) async {
    await seed();
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);
    await tester.tap(find.text('Add a job'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Opportunity ID'), 'OPP-1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount before tax'), '100');
    await tester.enterText(find.widgetWithText(TextFormField, 'Total including tax'), '90');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text("Total can't be lower than the amount before tax"), findsOneWidget);
    expect(find.text('Required'), findsOneWidget, reason: 'payment method missing');
  });

  testWidgets('add a disposal visit with a weigh-in; estimate shows', (tester) async {
    await seed();
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Add a visit'), 300);
    await tester.tap(find.text('Add a visit'));
    await settle(tester);
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Site'));
    await settle(tester);
    await tester.tap(find.text('Eco-Junk').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Ticket number'), 'EJ-42');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Material'));
    await settle(tester);
    await tester.tap(find.text('Garbage').last);
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Weight (kg)'), '300');
    await tester.tap(find.text('Add weigh-in'));
    await settle(tester);
    expect(find.text('\$45.00 (estimate)'), findsOneWidget);

    await tester.scrollUntilVisible(find.widgetWithText(FilledButton, 'Done'), 300,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Eco-Junk'), 300);
    expect(find.text('Eco-Junk'), findsOneWidget);
  });

  testWidgets('submit lists what is missing instead of sending', (tester) async {
    await seed();
    await Repo(db).saveJob(JobDraft(shiftId: shiftId, opportunityId: 'CASH-1', outcome: 'completed',
        paymentMethod: 'cash', preTax: 100, total: 114.98));
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Submit shift'), 300);
    await tester.tap(find.text('Submit shift'));
    await settle(tester);
    expect(find.text('Fix before submitting:'), findsOneWidget);
    expect(find.text('Cash photo missing'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect((await db.get('SELECT status FROM shift WHERE id = ?', [shiftId]))['status'], 'in_progress');
  });

  testWidgets('a ready shift submits after confirmation', (tester) async {
    await seed();
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Submit shift'), 300);
    await tester.tap(find.text('Submit shift'));
    await settle(tester);
    expect(find.textContaining("won't be able to change it"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit shift').last);
    await settle(tester);
    expect((await db.get('SELECT status FROM shift WHERE id = ?', [shiftId]))['status'], 'submitted');
    expect(find.text('Submitted — under review'), findsOneWidget);
    expect(find.text('Add a job'), findsNothing, reason: 'read-only after submit');
  });

  testWidgets('not started: choose hours type and start', (tester) async {
    await seed(status: 'open');
    await db.execute('UPDATE shift SET hours_type = NULL, start_time = NULL');
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);
    expect(find.text('Not started'), findsOneWidget);
    await tester.tap(find.text('Warehouse hours'));
    await settle(tester);
    await tester.tap(find.text('Start shift'));
    await settle(tester);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Scoreboard'), findsOneWidget);
  });

  testWidgets('an account not linked to an employee sees a clear message', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);
    expect(find.textContaining("isn't linked to a crew member"), findsOneWidget);
  });

  testWidgets('signing out with unsent changes warns first', (tester) async {
    await seed();
    await Repo(db).saveJob(JobDraft(shiftId: shiftId, opportunityId: 'UNSENT', outcome: null));
    await tester.pumpWidget(app(const Locale('en')));
    await settle(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Sign out'));
    await settle(tester);
    expect(find.textContaining('not sent to the server yet'), findsOneWidget);
    await tester.tap(find.text('Stay signed in'));
    await settle(tester);
    expect(find.text('UNSENT'), findsOneWidget, reason: 'still signed in, nothing wiped');
  });
}
