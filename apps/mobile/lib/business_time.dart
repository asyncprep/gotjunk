import 'package:intl/intl.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Business time zone (Montréal), the same as the server's `timezone` setting and the admin app.
/// Shift dates, rate dates and the times crews see use it, whatever the phone's own clock says.
const businessTimeZone = 'America/Toronto';

tz.Location? _zone;

tz.Location get businessZone {
  if (_zone == null) {
    tzdata.initializeTimeZones();
    _zone = tz.getLocation(businessTimeZone);
  }
  return _zone!;
}

/// A moment as Montréal wall-clock time.
tz.TZDateTime inBusinessZone(DateTime moment) => tz.TZDateTime.from(moment, businessZone);

/// Today's business date, `yyyy-MM-dd`.
String businessToday([DateTime? now]) => DateFormat('yyyy-MM-dd').format(inBusinessZone(now ?? DateTime.now()));

/// SQLite date modifier turning a UTC timestamp into Montréal time, e.g. `'-240 minutes'`.
/// Uses the current offset: a timestamp from the other side of a daylight-saving change (shifts
/// don't span one at day level) would be off by an hour, which never changes its date in practice.
String businessOffsetModifier([DateTime? now]) =>
    "'${inBusinessZone(now ?? DateTime.now()).timeZoneOffset.inMinutes} minutes'";
