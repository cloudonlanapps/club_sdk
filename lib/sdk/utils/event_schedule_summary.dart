import '../models/enums.dart';
import '../models/event.dart';
import 'format_utils.dart';
import 'rrule_translator.dart';

/// Human-readable schedule line for an event, suitable for use as the
/// secondary line on a list card (under the time range).
///
/// - One-off: the event's date (e.g. "9 May 2026").
/// - Camp with a COUNT-bound rrule: "{N} day session".
/// - Programme / other recurring: the rrule translated to text
///   (e.g. "Weekly on Mondays").
/// - No rrule and not a one-off: returns null.
String? eventScheduleSummary(Event event) {
  if (event.type == EventType.oneOff) {
    return formatDate(event.startTimeUtc.toLocal());
  }

  if (event.type == EventType.camp && event.rrule != null) {
    final count = rruleCount(event.rrule!);
    if (count != null) return '$count day session';
  }

  return translateRRule(event.rrule);
}

int? rruleCount(String rrule) {
  final match = RegExp(r'COUNT=(\d+)').firstMatch(rrule);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
