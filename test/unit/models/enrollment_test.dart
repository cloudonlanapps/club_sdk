import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Enrollment Model Unit Tests (EnrollmentStatus, Enrollment).
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('EnrollmentStatus', () {
    test('values contains all expected statuses', () {
      expect(
        EnrollmentStatus.values,
        containsAll([
          EnrollmentStatus.invited,
          EnrollmentStatus.requested,
          EnrollmentStatus.accepted,
          EnrollmentStatus.rejected,
          EnrollmentStatus.assigned,
          EnrollmentStatus.assignedTrial,
          EnrollmentStatus.withdrawn,
          EnrollmentStatus.withdrawRequested,
        ]),
      );
    });
  });

  group('Enrollment', () {
    final now = DateTime.utc(2024, 6, 15, 10);
    final enrollment = Enrollment(
      id: 1,
      membername: 'member-1',
      eventId: 1,
      status: EnrollmentStatus.assigned,
      createdAtUtc: now,
    );

    test('two instances with same values are equal', () {
      final sameEnrollment = Enrollment(
        id: 1,
        membername: 'member-1',
        eventId: 1,
        status: EnrollmentStatus.assigned,
        createdAtUtc: now,
      );

      expect(enrollment, sameEnrollment);
    });

    test('two instances with different values are not equal', () {
      final differentEnrollment = Enrollment(
        id: 2,
        membername: 'member-2',
        eventId: 1,
        status: EnrollmentStatus.assigned,
        createdAtUtc: now,
      );

      expect(enrollment, isNot(differentEnrollment));
    });

    test('equal instances have same hashCode', () {
      final sameEnrollment = Enrollment(
        id: 1,
        membername: 'member-1',
        eventId: 1,
        status: EnrollmentStatus.assigned,
        createdAtUtc: now,
      );

      expect(enrollment.hashCode, sameEnrollment.hashCode);
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final updated = enrollment.copyWith(status: EnrollmentStatus.withdrawn);
      expect(updated.id, enrollment.id);
      expect(updated.status, EnrollmentStatus.withdrawn);
      expect(updated.membername, enrollment.membername);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = enrollment.copyWith(status: EnrollmentStatus.rejected);
      expect(updated.id, 1);
      expect(updated.membername, 'member-1');
      expect(updated.eventId, 1);
      expect(updated.status, EnrollmentStatus.rejected);
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final basic = Enrollment(
        id: 1,
        membername: 'member-1',
        eventId: 1,
        status: EnrollmentStatus.invited,
        createdAtUtc: now,
      );

      final updated = basic.copyWith(
        membername: 'Jane Doe',
      );
      expect(updated.membername, 'Jane Doe');
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final cleared = enrollment.copyWith(updatedAtUtc: () => null);

      expect(cleared.updatedAtUtc, isNull);
    });

    test('toMap produces correct map structure', () {
      final map = enrollment.toMap();
      expect(map['id'], 1);
      expect(map['membername'], 'member-1');
      expect(map['eventId'], 1);
      expect(map['status'], 'assigned');
      expect(map['isTrial'], false);
      expect(map['createdAtUtc'], isA<int>());
    });

    test('fromMap restores equivalent instance', () {
      final map = enrollment.toMap();
      final fromMap = Enrollment.fromMap(map);
      expect(fromMap, enrollment);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final enrollWithAll = Enrollment(
        id: 1,
        membername: 'member-1',
        eventId: 1,
        status: EnrollmentStatus.assigned,
        createdAtUtc: now,
        isTrial: true,
        updatedAtUtc: now.add(const Duration(days: 1)),
      );

      final restored = Enrollment.fromMap(enrollWithAll.toMap());
      expect(restored, enrollWithAll);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = enrollment.toJson();
      final fromJson = Enrollment.fromJson(json);
      expect(fromJson, enrollment);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 1,
        'membername': 'member-1',
        'eventId': 1,
        'status': 'invited',
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final enroll = Enrollment.fromMap(map);
      expect(enroll.isTrial, false);
      expect(enroll.updatedAtUtc, isNull);
    });

    test('isTrial defaults to false when not provided', () {
      final map = {
        'id': 1,
        'membername': 'member-1',
        'eventId': 1,
        'status': 'invited',
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final enroll = Enrollment.fromMap(map);
      expect(enroll.isTrial, false);
    });
  });

  group('Issue 9: Enrollment.eligible', () {
    // EnrollmentResponse (club_server#19): `eligible` is false while the
    // member is enrolled and no longer meets the event's gender or window.
    Map<String, dynamic> payload({bool? eligible}) => {
      'id': 11,
      'membername': 'amy',
      'eventId': 42,
      'status': 'assigned',
      'isTrial': false,
      'previousStatus': null,
      'withdrawalReason': null,
      'enrolledAtUtc': DateTime.utc(2026, 9).millisecondsSinceEpoch,
      'withdrawnAtUtc': null,
      'createdAtUtc': DateTime.utc(2026, 9).millisecondsSinceEpoch,
      'updatedAtUtc': null,
      'eligible': ?eligible,
    };

    test('fromMap reads eligible false', () {
      expect(Enrollment.fromMap(payload(eligible: false)).eligible, isFalse);
    });

    test('fromMap reads eligible true', () {
      expect(Enrollment.fromMap(payload(eligible: true)).eligible, isTrue);
    });

    test('eligible is true when the server omits it', () {
      final old = payload();
      expect(old.containsKey('eligible'), isFalse);
      expect(Enrollment.fromMap(old).eligible, isTrue);
    });

    test('eligible round-trips through toMap and toJson', () {
      final flagged = Enrollment.fromMap(payload(eligible: false));
      expect(flagged.toMap()['eligible'], isFalse);
      expect(Enrollment.fromMap(flagged.toMap()), flagged);
      expect(Enrollment.fromJson(flagged.toJson()), flagged);
    });

    test('eligible takes part in equality and is set through copyWith', () {
      final flagged = Enrollment.fromMap(payload(eligible: false));
      final fine = Enrollment.fromMap(payload(eligible: true));
      expect(flagged, isNot(fine));
      expect(flagged.copyWith(eligible: true), fine);
      expect(flagged.copyWith(eligible: true).hashCode, fine.hashCode);
      expect(flagged.copyWith(isTrial: true).eligible, isFalse);
    });
  });
}
