/// Utility for translating a programme's RRule string to human-readable
/// text.
///
/// The only recurring rule a programme can carry on the server is weekly
/// on set days (`FREQ=WEEKLY;BYDAY=MO,WE`); COUNT, UNTIL, INTERVAL and
/// EXDATE are refused. That is the one case translated:
/// - FREQ=WEEKLY;BYDAY=MO -> "Weekly on Mondays"
/// - FREQ=WEEKLY;BYDAY=MO,WE -> "Weekly on Monday and Wednesday"
///
/// Camps and one-offs are summarised by `eventScheduleSummary`.
library;

import 'package:rrule/rrule.dart';

import 'rrule_util.dart';

/// Translates a programme's weekly RRule to human-readable format, e.g.
/// "Weekly on Mondays".
///
/// [occurrenceDate] is used to derive the day of week when BYDAY is not
/// specified.
///
/// Returns null if the rrule is null, cannot be parsed, or is not the
/// weekly shape the server allows for a programme (#36).
String? translateRRule(String? rrule, {DateTime? occurrenceDate}) {
  if (rrule == null || rrule.isEmpty) return null;

  final util = RruleUtil();
  final (rulePart, exdates) = util.parseRruleWithExdates(rrule);
  if (rulePart.isEmpty || exdates.isNotEmpty) return null;

  final RecurrenceRule rule;
  try {
    rule = util.validate(rulePart);
  } on Object catch (_) {
    return null;
  }

  if (rule.frequency != Frequency.weekly ||
      rule.count != null ||
      rule.until != null ||
      (rule.interval ?? 1) != 1) {
    return null;
  }

  if (rule.byWeekDays.isNotEmpty) {
    final days = rule.byWeekDays.map((e) => getDayName(e.day)).toList();
    if (days.length == 1) return 'Weekly on ${days.first}s';
    final lastDay = days.removeLast();
    return 'Weekly on ${days.join(', ')} and $lastDay';
  }
  if (occurrenceDate != null) {
    return 'Weekly on ${getDayName(occurrenceDate.toLocal().weekday)}s';
  }
  return 'Weekly';
}

/// Gets day name from weekday number (1=Monday, 7=Sunday).
String getDayName(int weekday) {
  return switch (weekday) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'Unknown',
  };
}

/// Translates a day abbreviation to full day name.
String? translateDay(String abbr) {
  final cleanAbbr = abbr.replaceAll(RegExp(r'[\-\d]'), '').toUpperCase();

  return switch (cleanAbbr) {
    'MO' => 'Monday',
    'TU' => 'Tuesday',
    'WE' => 'Wednesday',
    'TH' => 'Thursday',
    'FR' => 'Friday',
    'SA' => 'Saturday',
    'SU' => 'Sunday',
    _ => null,
  };
}
