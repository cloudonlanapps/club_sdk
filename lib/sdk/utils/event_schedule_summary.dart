import '../models/enums.dart';
import '../models/event.dart';
import 'format_utils.dart';
import 'rrule_translator.dart';
import 'rrule_util.dart';

/// Human-readable schedule line for an event, suitable for use as the
/// secondary line on a list card (under the time range).
///
/// - One-off: the event's date (e.g. "9 May 2026").
/// - Camp with a COUNT-bound rrule: "{N} day session".
/// - Programme: its weekly rrule translated to text (e.g. "Weekly on
///   Mondays"); see [translateRRule].
/// - Anything else (no rrule, or a rule the server would refuse): null.
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

/// The COUNT of [rrule]'s rule part (an `EXDATE:` line is allowed), or
/// null when it has none or does not parse.
int? rruleCount(String rrule) {
  final util = RruleUtil();
  final (rulePart, _) = util.parseRruleWithExdates(rrule);
  if (rulePart.isEmpty) return null;
  try {
    return util.validate(rulePart).count;
  } on Object catch (_) {
    return null;
  }
}
