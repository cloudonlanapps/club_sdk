import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 16: there is no whole-event "cancelled". An occurrence is
/// cancelled when it carries a cancelled override or its slot is at or
/// after the event's cutoff.
Event event({DateTime? untilTimeUtc}) => Event(
  id: 1,
  title: 't',
  description: '',
  type: EventType.programme,
  visibility: Visibility.public,
  venueId: 1,
  startTimeUtc: DateTime.utc(2026, 1, 5, 10),
  endTimeUtc: DateTime.utc(2026, 1, 5, 11),
  createdAtUtc: DateTime.utc(2025),
  updatedAtUtc: DateTime.utc(2025),
  rrule: 'FREQ=WEEKLY;BYDAY=MO',
  untilTimeUtc: untilTimeUtc,
);

void main() {
  group('Issue 16: isOccurrenceCancelled', () {
    final cutoff = DateTime.utc(2026, 3, 2, 10);

    test('Issue 16: open-ended event has no cancelled slots', () {
      expect(isOccurrenceCancelled(event(), DateTime.utc(2030)), isFalse);
    });

    test('Issue 16: a slot before the cutoff still runs', () {
      expect(
        isOccurrenceCancelled(
          event(untilTimeUtc: cutoff),
          DateTime.utc(2026, 2, 23, 10),
        ),
        isFalse,
      );
    });

    test('Issue 16: a slot at or after the cutoff is cancelled', () {
      final e = event(untilTimeUtc: cutoff);
      expect(isOccurrenceCancelled(e, cutoff), isTrue);
      expect(isOccurrenceCancelled(e, DateTime.utc(2026, 3, 9, 10)), isTrue);
    });

    test('Issue 16: a cancelled override cancels the slot on its own', () {
      expect(
        isOccurrenceCancelled(
          event(),
          DateTime.utc(2026, 2, 2, 10),
          overrideStatus: OccurrenceStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        isOccurrenceCancelled(
          event(),
          DateTime.utc(2026, 2, 2, 10),
          overrideStatus: OccurrenceStatus.rescheduled,
        ),
        isFalse,
      );
    });
  });

  group('Issue 16: Event.status', () {
    test(
      'Issue 16: bounded events read as cancelled, open-ended as active',
      () {
        expect(event().status, EventStatus.active);
        expect(event().isBounded, isFalse);
        expect(
          event(untilTimeUtc: DateTime.utc(2030)).status,
          EventStatus.cancelled,
        );
        expect(event(untilTimeUtc: DateTime.utc(2030)).isBounded, isTrue);
      },
    );
  });
}
