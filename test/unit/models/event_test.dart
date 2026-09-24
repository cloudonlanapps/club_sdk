import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Event Model Unit Tests.
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('EventType', () {
    test('values contains all expected types', () {
      expect(
        EventType.values,
        containsAll([
          EventType.oneOff,
          EventType.programme,
          EventType.camp,
        ]),
      );
    });
  });

  group('Visibility', () {
    test('values contains all expected visibilities', () {
      expect(
        Visibility.values,
        containsAll([
          Visibility.public,
          Visibility.private,
        ]),
      );
    });
  });

  group('EventStatus', () {
    test('values contains all expected statuses', () {
      expect(
        EventStatus.values,
        containsAll([
          EventStatus.active,
          EventStatus.cancelled,
        ]),
      );
    });
  });

  group('Event', () {
    final now = DateTime.utc(2026, 2, 26, 11, 35);
    final event = Event(
      id: 1,
      title: 'Training Session',
      description: 'Morning cricket training',
      type: EventType.oneOff,
      visibility: Visibility.public,
      venueId: 1,
      organizerName: 'coach-1',
      startTimeUtc: now,
      endTimeUtc: now.add(const Duration(hours: 2)),
      createdAtUtc: now,
      updatedAtUtc: now,
    );

    test('two instances with same values are equal', () {
      final sameEvent = Event(
        id: 1,
        title: 'Training Session',
        description: 'Morning cricket training',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: 1,
        organizerName: 'coach-1',
        startTimeUtc: now,
        endTimeUtc: now.add(const Duration(hours: 2)),
        createdAtUtc: now,
        updatedAtUtc: now,
      );

      expect(event, sameEvent);
    });

    test('two instances with different values are not equal', () {
      final differentEvent = Event(
        id: 2,
        title: 'Different Session',
        description: 'Morning cricket training',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: 1,
        startTimeUtc: now,
        endTimeUtc: now.add(const Duration(hours: 2)),
        createdAtUtc: now,
        updatedAtUtc: now,
      );

      expect(event, isNot(differentEvent));
    });

    test('equal instances have same hashCode', () {
      final sameEvent = Event(
        id: 1,
        title: 'Training Session',
        description: 'Morning cricket training',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: 1,
        organizerName: 'coach-1',
        startTimeUtc: now,
        endTimeUtc: now.add(const Duration(hours: 2)),
        createdAtUtc: now,
        updatedAtUtc: now,
      );

      expect(event.hashCode, sameEvent.hashCode);
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final updated = event.copyWith(title: 'Updated Title');
      expect(updated.id, event.id);
      expect(updated.title, 'Updated Title');
      expect(updated.description, event.description);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = event.copyWith(title: 'New Title');
      expect(updated.id, 1);
      expect(updated.type, EventType.oneOff);
      expect(updated.visibility, Visibility.public);
      expect(updated.venueId, 1);
      expect(updated.organizerName, 'coach-1');
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final updated = event.copyWith(
        rrule: () => 'FREQ=WEEKLY',
        organizerName: () => 'coach-2',
      );
      expect(updated.rrule, 'FREQ=WEEKLY');
      expect(updated.organizerName, 'coach-2');
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final eventWithRRule = event.copyWith(
        rrule: () => 'FREQ=WEEKLY',
      );
      expect(eventWithRRule.rrule, 'FREQ=WEEKLY');

      final eventWithoutRRule = eventWithRRule.copyWith(
        rrule: () => null,
        organizerName: () => null,
      );
      expect(eventWithoutRRule.rrule, isNull);
      expect(eventWithoutRRule.organizerName, isNull);
    });

    test('toMap produces correct map structure', () {
      final map = event.toMap();
      expect(map['id'], 1);
      expect(map['title'], 'Training Session');
      expect(map['type'], 'oneOff');
      expect(map['visibility'], 'public');
      expect(map['venueId'], 1);
      expect(map['startTimeUtc'], isA<int>());
    });

    test('fromMap restores equivalent instance', () {
      final map = event.toMap();
      final fromMap = Event.fromMap(map);
      expect(fromMap, event);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final eventWithAllFields = Event(
        id: 1,
        title: 'Full Event',
        description: 'Description',
        type: EventType.programme,
        visibility: Visibility.private,
        venueId: 1,
        organizerName: 'coach-1',
        rrule: 'FREQ=WEEKLY;COUNT=10',
        startTimeUtc: now,
        endTimeUtc: now.add(const Duration(hours: 2)),
        createdAtUtc: now,
        updatedAtUtc: now,
        untilTimeUtc: now.add(const Duration(days: 30)),
      );

      final restored = Event.fromMap(eventWithAllFields.toMap());
      expect(restored, eventWithAllFields);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = event.toJson();
      final fromJson = Event.fromJson(json);
      expect(fromJson, event);
    });

    test('status returns active when untilTimeUtc is null', () {
      expect(event.status, EventStatus.active);
    });

    test('status returns cancelled when untilTimeUtc set but no successor', () {
      final cancelledEvent = event.copyWith(
        untilTimeUtc: () => now.add(const Duration(days: 1)),
      );
      expect(cancelledEvent.status, EventStatus.cancelled);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 1,
        'title': 'Test',
        'description': 'Desc',
        'type': 'oneOff',
        'visibility': 'public',
        'venueId': 1,
        'startTimeUtc': now.millisecondsSinceEpoch,
        'endTimeUtc': now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'createdAtUtc': now.millisecondsSinceEpoch,
        'updatedAtUtc': now.millisecondsSinceEpoch,
      };
      final event = Event.fromMap(map);
      expect(event.organizerName, isNull);
      expect(event.rrule, isNull);
      expect(event.untilTimeUtc, isNull);
      expect(event.deletedAtUtc, isNull);
    });

    group('RELEASE_3_0 deletedAtUtc', () {
      // ignore: but explicit deletedAtUtc makes intent clearer
      final deletedAt = DateTime.utc(2024, 7, 1);

      test('construction with deletedAtUtc', () {
        final deleted = event.copyWith(deletedAtUtc: () => deletedAt);
        expect(deleted.deletedAtUtc, deletedAt);
      });

      test('toMap/fromMap roundtrip preserves deletedAtUtc', () {
        final deleted = event.copyWith(deletedAtUtc: () => deletedAt);
        final restored = Event.fromMap(deleted.toMap());
        expect(restored.deletedAtUtc, deletedAt);
        expect(restored, deleted);
      });

      test('copyWith can set deletedAtUtc', () {
        final updated = event.copyWith(deletedAtUtc: () => deletedAt);
        expect(updated.deletedAtUtc, deletedAt);
      });

      test('copyWith can clear deletedAtUtc to null', () {
        final deleted = event.copyWith(deletedAtUtc: () => deletedAt);
        final cleared = deleted.copyWith(deletedAtUtc: () => null);
        expect(cleared.deletedAtUtc, isNull);
      });

      test('equality includes deletedAtUtc', () {
        final a = event.copyWith(deletedAtUtc: () => deletedAt);
        final b = event.copyWith(deletedAtUtc: () => deletedAt);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different deletedAtUtc makes events unequal', () {
        final a = event.copyWith(deletedAtUtc: () => deletedAt);
        final b = event.copyWith(
          // ignore: but explicit deletedAtUtc makes intent clearer
          deletedAtUtc: () => DateTime.utc(2024, 8, 1),
        );
        expect(a, isNot(b));
      });
    });
  });
}
