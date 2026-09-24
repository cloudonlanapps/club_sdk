import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Occurrence Model Unit Tests (OccurrenceStatus, Occurrence).
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('OccurrenceStatus', () {
    test('values contains all expected statuses', () {
      expect(
        OccurrenceStatus.values,
        containsAll([
          OccurrenceStatus.scheduled,
          OccurrenceStatus.completed,
          OccurrenceStatus.cancelled,
          OccurrenceStatus.rescheduled,
        ]),
      );
    });
  });

  group('Occurrence', () {
    final now = DateTime.utc(2026, 2, 26, 11, 35);
    final occurrence = Occurrence(
      eventId: 1,
      originalStartTimeUtc: now,
      actualStartTimeUtc: now,
      actualEndTimeUtc: now.add(const Duration(hours: 2)),
      status: OccurrenceStatus.scheduled,
      venueId: 1,
      organizerName: 'coach-occ-1',
      enrollmentStatus: EnrollmentStatus.assigned,
      attendanceStatus: AttendanceStatus.present,
    );

    test('two instances with same values are equal', () {
      final sameOcc = Occurrence(
        eventId: 1,
        originalStartTimeUtc: now,
        actualStartTimeUtc: now,
        actualEndTimeUtc: now.add(const Duration(hours: 2)),
        status: OccurrenceStatus.scheduled,
        venueId: 1,
        organizerName: 'coach-occ-1',
        enrollmentStatus: EnrollmentStatus.assigned,
        attendanceStatus: AttendanceStatus.present,
      );

      expect(occurrence, sameOcc);
    });

    test('two instances with different values are not equal', () {
      final differentOcc = Occurrence(
        eventId: 2,
        originalStartTimeUtc: now,
        actualStartTimeUtc: now,
        actualEndTimeUtc: now.add(const Duration(hours: 2)),
        status: OccurrenceStatus.scheduled,
        venueId: 1,
      );

      expect(occurrence, isNot(differentOcc));
    });

    test('equal instances have same hashCode', () {
      final sameOcc = Occurrence(
        eventId: 1,
        originalStartTimeUtc: now,
        actualStartTimeUtc: now,
        actualEndTimeUtc: now.add(const Duration(hours: 2)),
        status: OccurrenceStatus.scheduled,
        venueId: 1,
        organizerName: 'coach-occ-1',
        enrollmentStatus: EnrollmentStatus.assigned,
        attendanceStatus: AttendanceStatus.present,
      );

      expect(occurrence.hashCode, sameOcc.hashCode);
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final updated = occurrence.copyWith(status: OccurrenceStatus.completed);
      expect(updated.status, OccurrenceStatus.completed);
      expect(updated.venueId, occurrence.venueId);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = occurrence.copyWith(status: OccurrenceStatus.cancelled);
      expect(updated.eventId, 1);
      expect(updated.organizerName, 'coach-occ-1');
      expect(updated.enrollmentStatus, EnrollmentStatus.assigned);
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final noStatus = Occurrence(
        eventId: 1,
        originalStartTimeUtc: now,
        actualStartTimeUtc: now,
        actualEndTimeUtc: now.add(const Duration(hours: 2)),
        status: OccurrenceStatus.scheduled,
        venueId: 1,
      );

      final updated = noStatus.copyWith(
        organizerName: () => 'coach-new',
        enrollmentStatus: () => EnrollmentStatus.assigned,
        attendanceStatus: () => AttendanceStatus.absent,
      );
      expect(updated.organizerName, 'coach-new');
      expect(updated.enrollmentStatus, EnrollmentStatus.assigned);
      expect(updated.attendanceStatus, AttendanceStatus.absent);
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final cleared = occurrence.copyWith(
        organizerName: () => null,
        enrollmentStatus: () => null,
        attendanceStatus: () => null,
      );
      expect(cleared.organizerName, isNull);
      expect(cleared.enrollmentStatus, isNull);
      expect(cleared.attendanceStatus, isNull);
    });

    test('toMap produces correct map structure', () {
      final map = occurrence.toMap();
      expect(map['eventId'], 1);
      expect(map['status'], 'scheduled');
      expect(map['venueId'], 1);
      expect(map['enrollmentStatus'], 'assigned');
      expect(map['attendanceStatus'], 'present');
      expect(map['originalStartTimeUtc'], isA<int>());
    });

    test('fromMap restores equivalent instance', () {
      final map = occurrence.toMap();
      final fromMap = Occurrence.fromMap(map);
      expect(fromMap, occurrence);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final occWithCount = occurrence.copyWith(attendanceCount: () => 25);
      final restored = Occurrence.fromMap(occWithCount.toMap());
      expect(restored, occWithCount);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = occurrence.toJson();
      final fromJson = Occurrence.fromJson(json);
      expect(fromJson, occurrence);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'eventId': 1,
        'originalStartTimeUtc': now.millisecondsSinceEpoch,
        'actualStartTimeUtc': now.millisecondsSinceEpoch,
        'actualEndTimeUtc': now
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        'status': 'scheduled',
        'venueId': 1,
      };
      final occ = Occurrence.fromMap(map);
      expect(occ.organizerName, isNull);
      expect(occ.enrollmentStatus, isNull);
      expect(occ.attendanceStatus, isNull);
      expect(occ.attendanceCount, isNull);
      expect(occ.isRescheduled, isFalse);
    });

    test('Issue 705: fromMap parses isRescheduled, defaulting to false', () {
      final base = {
        'eventId': 1,
        'originalStartTimeUtc': now.millisecondsSinceEpoch,
        'actualStartTimeUtc': now.millisecondsSinceEpoch,
        'actualEndTimeUtc': now
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        'status': 'scheduled',
        'venueId': 1,
      };
      expect(Occurrence.fromMap(base).isRescheduled, isFalse);
      expect(
        Occurrence.fromMap({...base, 'isRescheduled': true}).isRescheduled,
        isTrue,
      );
    });

    test('Issue 705: isRescheduled round-trips through toMap', () {
      final overridden = occurrence.copyWith(isRescheduled: true);
      expect(Occurrence.fromMap(overridden.toMap()).isRescheduled, isTrue);
    });
  });
}
