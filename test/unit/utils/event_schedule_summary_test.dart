import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

Event _event(EventType type, {String? rrule}) => Event(
  id: 1,
  title: 't',
  description: '',
  type: type,
  visibility: Visibility.public,
  venueId: 1,
  // Noon UTC is 9 May 2026 in every time zone the summary may run in.
  startTimeUtc: DateTime.utc(2026, 5, 9, 12),
  endTimeUtc: DateTime.utc(2026, 5, 9, 13),
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
  rrule: rrule,
);

void main() {
  group('eventScheduleSummary', () {
    test('Issue 36: a programme on one day reads "Weekly on Mondays"', () {
      expect(
        eventScheduleSummary(
          _event(EventType.programme, rrule: 'FREQ=WEEKLY;BYDAY=MO'),
        ),
        'Weekly on Mondays',
      );
    });

    test('Issue 36: a programme on two days joins them with "and"', () {
      expect(
        eventScheduleSummary(
          _event(EventType.programme, rrule: 'FREQ=WEEKLY;BYDAY=MO,WE'),
        ),
        'Weekly on Monday and Wednesday',
      );
    });

    test('Issue 36: a programme on three days lists them', () {
      expect(
        eventScheduleSummary(
          _event(EventType.programme, rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,SA'),
        ),
        'Weekly on Monday, Wednesday and Saturday',
      );
    });

    test('Issue 36: a camp reads "7 day session"', () {
      expect(
        eventScheduleSummary(
          _event(EventType.camp, rrule: 'FREQ=DAILY;COUNT=7'),
        ),
        '7 day session',
      );
    });

    test('Issue 36: a camp with rest days reads "7 day session"', () {
      expect(
        eventScheduleSummary(
          _event(
            EventType.camp,
            rrule: 'FREQ=DAILY;COUNT=7\nEXDATE:20260511T120000Z',
          ),
        ),
        '7 day session',
      );
    });

    test('Issue 36: a camp rule without COUNT has no summary', () {
      expect(
        eventScheduleSummary(_event(EventType.camp, rrule: 'FREQ=DAILY')),
        isNull,
      );
    });

    test('Issue 36: a one-off reads its date', () {
      expect(eventScheduleSummary(_event(EventType.oneOff)), '9 May 2026');
    });

    test('Issue 36: a programme rule the server refuses has no summary', () {
      expect(
        eventScheduleSummary(
          _event(EventType.programme, rrule: 'FREQ=MONTHLY'),
        ),
        isNull,
      );
    });

    test('Issue 36: a programme without a rule has no summary', () {
      expect(eventScheduleSummary(_event(EventType.programme)), isNull);
    });
  });
}
