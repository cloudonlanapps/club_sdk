import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 7: an event form carries the age band (club_server#16), not the
/// two dates of birth the server now works out and no longer accepts.
void main() {
  group('Issue 7: EventInput age band', () {
    final start = DateTime.utc(2027, 1, 1, 10);
    final input = EventInput(
      title: 'test_U12 camp',
      description: 'D',
      type: EventType.camp,
      visibility: Visibility.public,
      venueId: 1,
      startTimeUtc: start,
      endTimeUtc: start.add(const Duration(hours: 1)),
      minAge: const Age(years: 8),
      maxAge: const Age(years: 12, months: 6),
      strictAge: true,
    );

    test('strictAge is false and the bounds unset by default', () {
      final plain = EventInput(
        title: 'T',
        description: 'D',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: 1,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
      expect(plain.minAge, isNull);
      expect(plain.maxAge, isNull);
      expect(plain.strictAge, isFalse);
    });

    test('toMap writes the band and no date-of-birth bound', () {
      final map = input.toMap();
      expect(map['minAge'], {'years': 8, 'months': 0, 'days': 0});
      expect(map['maxAge'], {'years': 12, 'months': 6, 'days': 0});
      expect(map['strictAge'], isTrue);
      expect(map.containsKey('dobOnOrAfterUtc'), isFalse);
      expect(map.containsKey('dobOnOrBeforeUtc'), isFalse);
    });

    test('toMap/fromMap and toJson/fromJson round-trip the band', () {
      expect(EventInput.fromMap(input.toMap()), input);
      expect(EventInput.fromJson(input.toJson()), input);
    });

    test('the band takes part in equality', () {
      expect(input, isNot(input.copyWith(minAge: () => const Age(years: 9))));
      expect(input, isNot(input.copyWith(maxAge: () => const Age(years: 13))));
      expect(input, isNot(input.copyWith(strictAge: false)));
      expect(input.hashCode, input.copyWith().hashCode);
    });

    test('copyWith clears a bound through its getter', () {
      final open = input.copyWith(maxAge: () => null);
      expect(open.maxAge, isNull);
      expect(open.minAge, const Age(years: 8));
      expect(open.strictAge, isTrue);
    });

    test('fromEvent takes the band of the event being edited', () {
      final event = input.toEvent(id: 7, now: DateTime.utc(2026, 10, 6));
      expect(event.minAge, const Age(years: 8));
      expect(event.maxAge, const Age(years: 12, months: 6));
      expect(event.strictAge, isTrue);

      final edit = EventInput.fromEvent(event);
      expect(edit.eventId, 7);
      expect(edit.minAge, const Age(years: 8));
      expect(edit.maxAge, const Age(years: 12, months: 6));
      expect(edit.strictAge, isTrue);
    });
  });
}
