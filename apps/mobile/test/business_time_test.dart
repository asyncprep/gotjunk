import 'package:flutter_test/flutter_test.dart';
import 'package:truck_team_os/business_time.dart';

void main() {
  group('business time is Montréal, not the phone', () {
    test('today rolls over at Montréal midnight', () {
      // 23:30 in Montréal (EDT, UTC-4) is already the next day in UTC.
      expect(businessToday(DateTime.utc(2026, 10, 28, 3, 30)), '2026-10-27');
      expect(businessToday(DateTime.utc(2026, 10, 28, 4, 30)), '2026-10-28');
      // Winter (EST, UTC-5).
      expect(businessToday(DateTime.utc(2026, 12, 1, 4, 30)), '2026-11-30');
    });

    test('times of day', () {
      final t = inBusinessZone(DateTime.parse('2026-10-28T07:38:31.872443Z'));
      expect([t.hour, t.minute], [3, 38]);
      expect(inBusinessZone(DateTime.utc(2026, 12, 1, 15)).hour, 10);
    });

    test('SQLite offset follows daylight saving', () {
      expect(businessOffsetModifier(DateTime.utc(2026, 10, 28, 12)), "'-240 minutes'");
      expect(businessOffsetModifier(DateTime.utc(2026, 11, 2, 12)), "'-300 minutes'");
    });
  });
}
