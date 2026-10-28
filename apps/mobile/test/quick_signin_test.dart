import 'package:flutter_test/flutter_test.dart';
import 'package:truck_team_os/ui/quick_signin.dart';

void main() {
  test('reads label, email and optional password', () {
    expect(parseQuickAccounts('Crew|a@x.ca|pw1; Lead | b@x.ca '), const [
      QuickAccount('Crew', 'a@x.ca', 'pw1'),
      QuickAccount('Lead', 'b@x.ca'),
    ]);
  });

  test('ignores empty and malformed entries', () {
    expect(parseQuickAccounts(''), isEmpty);
    expect(parseQuickAccounts(';Nope|not-an-email;|c@x.ca'), isEmpty);
  });

  test('no accounts unless provided at run time', () {
    expect(quickAccounts, isEmpty);
  });
}
