import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Occurrence Override Model Unit Tests.
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('OccurrenceOverride', () {
    final occurrenceTime = DateTime.utc(2024, 6, 15, 10);
    final newStartTime = DateTime.utc(2024, 6, 15, 11);
    final newEndTime = DateTime.utc(2024, 6, 15, 12);

    final override = OccurrenceOverride(
      eventId: 1,
      occurrenceTimeUtc: occurrenceTime,
      status: OccurrenceStatus.rescheduled,
      newStartTimeUtc: newStartTime,
      newEndTimeUtc: newEndTime,
      newVenueId: 2,
      newOrganizerName: 'New Coach',
    );

    test('effectiveStartTimeUtc returns newStartTimeUtc when present', () {
      expect(override.effectiveStartTimeUtc, newStartTime);
    });

    test('effectiveStartTimeUtc falls back to occurrenceTimeUtc when '
        'newStartTimeUtc is null', () {
      final noStartOverride = OccurrenceOverride(
        eventId: 1,
        occurrenceTimeUtc: occurrenceTime,
        status: OccurrenceStatus.cancelled,
      );
      expect(noStartOverride.effectiveStartTimeUtc, occurrenceTime);
    });

    test('two instances with same values are equal', () {
      final sameOverride = OccurrenceOverride(
        eventId: 1,
        occurrenceTimeUtc: occurrenceTime,
        status: OccurrenceStatus.rescheduled,
        newStartTimeUtc: newStartTime,
        newEndTimeUtc: newEndTime,
        newVenueId: 2,
        newOrganizerName: 'New Coach',
      );

      expect(override, sameOverride);
    });

    test('two instances with different values are not equal', () {
      final differentOverride = OccurrenceOverride(
        eventId: 2,
        occurrenceTimeUtc: occurrenceTime,
        status: OccurrenceStatus.cancelled,
      );

      expect(override, isNot(differentOverride));
    });

    test('equal instances have same hashCode', () {
      final sameOverride = OccurrenceOverride(
        eventId: 1,
        occurrenceTimeUtc: occurrenceTime,
        status: OccurrenceStatus.rescheduled,
        newStartTimeUtc: newStartTime,
        newEndTimeUtc: newEndTime,
        newVenueId: 2,
        newOrganizerName: 'New Coach',
      );

      expect(override.hashCode, sameOverride.hashCode);
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final updated = override.copyWith(
        status: OccurrenceStatus.cancelled,
      );
      expect(updated.eventId, override.eventId);
      expect(updated.status, OccurrenceStatus.cancelled);
      expect(updated.newVenueId, override.newVenueId);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = override.copyWith(status: OccurrenceStatus.cancelled);
      expect(updated.eventId, 1);
      expect(updated.occurrenceTimeUtc, occurrenceTime);
      expect(updated.newStartTimeUtc, newStartTime);
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final basic = OccurrenceOverride(
        eventId: 1,
        occurrenceTimeUtc: occurrenceTime,
        status: OccurrenceStatus.scheduled,
      );

      final updated = basic.copyWith(
        newVenueId: () => 3,
        newOrganizerName: () => 'Coach Smith',
      );
      expect(updated.newVenueId, 3);
      expect(updated.newOrganizerName, 'Coach Smith');
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final cleared = override.copyWith(
        newStartTimeUtc: () => null,
        newEndTimeUtc: () => null,
        newVenueId: () => null,
        newOrganizerName: () => null,
      );
      expect(cleared.newStartTimeUtc, isNull);
      expect(cleared.newEndTimeUtc, isNull);
      expect(cleared.newVenueId, isNull);
      expect(cleared.newOrganizerName, isNull);
    });

    test('toMap produces correct map structure', () {
      final map = override.toMap();
      expect(map['eventId'], 1);
      expect(map['occurrenceTimeUtc'], isA<int>());
      expect(map['status'], 'rescheduled');
      expect(map['newStartTimeUtc'], isA<int>());
      expect(map['newEndTimeUtc'], isA<int>());
      expect(map['newVenueId'], 2);
      expect(map['newOrganizerName'], 'New Coach');
    });

    test('fromMap restores equivalent instance', () {
      final map = override.toMap();
      final fromMap = OccurrenceOverride.fromMap(map);
      expect(fromMap, override);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = OccurrenceOverride.fromMap(override.toMap());
      expect(restored, override);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = override.toJson();
      final fromJson = OccurrenceOverride.fromJson(json);
      expect(fromJson, override);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'eventId': 1,
        'occurrenceTimeUtc': occurrenceTime.millisecondsSinceEpoch,
        'status': 'scheduled',
      };
      final o = OccurrenceOverride.fromMap(map);
      expect(o.newStartTimeUtc, isNull);
      expect(o.newEndTimeUtc, isNull);
      expect(o.newVenueId, isNull);
      expect(o.newOrganizerName, isNull);
    });

    test('cancelled override has correct status', () {
      final cancelled = OccurrenceOverride(
        eventId: 1,
        occurrenceTimeUtc: occurrenceTime,
        status: OccurrenceStatus.cancelled,
      );
      expect(cancelled.status, OccurrenceStatus.cancelled);
    });
  });
}
