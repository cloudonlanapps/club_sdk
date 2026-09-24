/// Utility for translating RRule strings to human-readable text.
///
/// Supports common patterns used in the events system:
/// - FREQ=WEEKLY;BYDAY=MO -> "Weekly on Mondays"
/// - FREQ=WEEKLY;COUNT=8 -> "Weekly (8 sessions)"
/// - FREQ=DAILY;COUNT=10 -> "Daily (10 sessions)"
library;

/// Translates an RRule string to human-readable format.
/// [occurrenceDate] is used to derive the day of week when BYDAY is not
/// specified.
/// Returns null if the rrule is null or cannot be parsed.
String? translateRRule(String? rrule, {DateTime? occurrenceDate}) {
  if (rrule == null || rrule.isEmpty) return null;

  final parts = <String, String>{};
  for (final part in rrule.split(';')) {
    final keyValue = part.split(':').last.split('=');
    if (keyValue.length == 2) {
      parts[keyValue[0].toUpperCase()] = keyValue[1];
    }
  }

  final freq = parts['FREQ'];
  if (freq == null) return null;

  final buffer = StringBuffer();

  switch (freq) {
    case 'DAILY':
      buffer.write('Daily');
    case 'WEEKLY':
      buffer.write('Weekly');
    case 'MONTHLY':
      buffer.write('Monthly');
    case 'YEARLY':
      buffer.write('Yearly');
    default:
      return null;
  }

  final byDay = parts['BYDAY'];
  if (freq == 'WEEKLY') {
    if (byDay != null) {
      final days = byDay
          .split(',')
          .map(translateDay)
          .whereType<String>()
          .toList();
      if (days.isNotEmpty) {
        if (days.length == 1) {
          buffer.write(' on ${days.first}s');
        } else if (days.length == 2) {
          buffer.write(' on ${days.join(' and ')}');
        } else {
          final lastDay = days.removeLast();
          buffer.write(' on ${days.join(', ')} and $lastDay');
        }
      }
    } else if (occurrenceDate != null) {
      final dayName = getDayName(occurrenceDate.toLocal().weekday);
      buffer.write(' on ${dayName}s');
    }
  }

  final count = parts['COUNT'];
  if (count != null) {
    final countInt = int.tryParse(count);
    if (countInt != null) {
      buffer.write(' ($countInt sessions)');
    }
  }

  final until = parts['UNTIL'];
  if (until != null && until.length >= 8) {
    final year = until.substring(0, 4);
    final month = until.substring(4, 6);
    final day = until.substring(6, 8);
    buffer.write(' until $day/$month/$year');
  }

  return buffer.toString();
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
