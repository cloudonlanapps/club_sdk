import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 16: `EventSchedule`, one entry of an event's timetable
/// (`GET /events/by_id/{id}/schedules`).
void main() {
  group('Issue 16: EventSchedule', () {
    final wire = <String, dynamic>{
      'id': 3,
      'eventId': 7,
      'effectiveFromUtc': DateTime.utc(2026, 9, 1).millisecondsSinceEpoch,
      'effectiveUntilUtc': DateTime.utc(2026, 10, 1).millisecondsSinceEpoch,
      'startTimeUtc': DateTime.utc(2026, 9, 1, 10).millisecondsSinceEpoch,
      'endTimeUtc': DateTime.utc(2026, 9, 1, 11).millisecondsSinceEpoch,
      'rrule': 'FREQ=WEEKLY;BYDAY=TU',
      'venueId': 2,
      'organizerName': 'org',
      'coachNames': ['c1', 'c2'],
      'sessions': [
        {'name': 'Warm-up', 'periodMinutes': 15},
        {'name': 'Drills', 'periodMinutes': 45},
      ],
    };

    test('Issue 16: fromMap reads every field', () {
      final s = EventSchedule.fromMap(wire);
      expect(s.id, 3);
      expect(s.eventId, 7);
      expect(s.effectiveFromUtc, DateTime.utc(2026, 9, 1));
      expect(s.effectiveUntilUtc, DateTime.utc(2026, 10, 1));
      expect(s.startTimeUtc, DateTime.utc(2026, 9, 1, 10));
      expect(s.rrule, 'FREQ=WEEKLY;BYDAY=TU');
      expect(s.venueId, 2);
      expect(s.organizerName, 'org');
      expect(s.coachNames, ['c1', 'c2']);
      expect(s.sessions?.length, 2);
      expect(s.isCurrent, isFalse);
    });

    test('Issue 16: a running schedule has no effectiveUntilUtc', () {
      final s = EventSchedule.fromMap({...wire, 'effectiveUntilUtc': null});
      expect(s.effectiveUntilUtc, isNull);
      expect(s.isCurrent, isTrue);
    });

    test('Issue 16: toMap/fromMap and toJson/fromJson round-trip', () {
      final s = EventSchedule.fromMap(wire);
      expect(EventSchedule.fromMap(s.toMap()), s);
      expect(EventSchedule.fromJson(s.toJson()), s);
      expect(s.toMap(), wire);
    });

    test('Issue 16: copyWith clears nullable fields via getters', () {
      final s = EventSchedule.fromMap(wire);
      final open = s.copyWith(
        effectiveUntilUtc: () => null,
        coachNames: () => null,
      );
      expect(open.effectiveUntilUtc, isNull);
      expect(open.coachNames, isNull);
      expect(open, isNot(s));
      expect(s.copyWith(), s);
      expect(s.hashCode, EventSchedule.fromMap(wire).hashCode);
    });
  });
}
