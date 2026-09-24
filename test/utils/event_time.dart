/// Time and recurrence helpers for the event integration tests (#16).
///
/// The server accepts one programme rule shape, `FREQ=WEEKLY;BYDAY=…`
/// (club_server#384), refuses a camp or one-off more than 52 weeks out
/// (`BEYOND_SCHEDULING_HORIZON`), and expands occurrence slots on whole
/// seconds, so a start carrying milliseconds is never "on a boundary".
library;

const _weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// A programme rule anchored on [start]'s weekday.
String weeklyOn(DateTime start) =>
    'FREQ=WEEKLY;BYDAY=${_weekdays[start.weekday - 1]}';

/// A programme rule on several weekdays, one `BYDAY` entry per start.
String weeklyOnDays(Iterable<DateTime> starts) {
  final days = <String>{};
  for (final s in starts) {
    days.add(_weekdays[s.weekday - 1]);
  }
  return 'FREQ=WEEKLY;BYDAY=${days.join(',')}';
}

/// [t] truncated to the whole minute (UTC).
DateTime wholeMinute(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute);
}

/// Now, truncated to the whole minute (UTC).
DateTime nowUtcMinute() => wholeMinute(DateTime.now());

/// Today at [hour]:[minute] UTC plus [days] — a whole-minute anchor inside
/// the scheduling horizon.
DateTime dayAt(int days, {int hour = 10, int minute = 0}) {
  final now = DateTime.now().toUtc();
  return DateTime.utc(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  ).add(Duration(days: days));
}
