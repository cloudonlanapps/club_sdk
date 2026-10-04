import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Attendance Model Unit Tests (AttendanceStatus, AttendanceRecord).
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('AttendanceStatus', () {
    test('values contains all expected statuses', () {
      expect(
        AttendanceStatus.values,
        containsAll([
          AttendanceStatus.present,
          AttendanceStatus.absent,
          AttendanceStatus.late,
          AttendanceStatus.onLeave,
          AttendanceStatus.onLeaveRequested,
        ]),
      );
    });
  });

  group('AttendanceRecord', () {
    final now = DateTime.utc(2024, 6, 15, 10);
    final record = AttendanceRecord(
      id: 1,
      occurrenceId: 101,
      membername: 'member-1',
      status: AttendanceStatus.present,
      recordedAtUtc: now,
      notes: 'On time',
    );

    test('two instances with same values are equal', () {
      final sameRecord = AttendanceRecord(
        id: 1,
        occurrenceId: 101,
        membername: 'member-1',
        status: AttendanceStatus.present,
        recordedAtUtc: now,
        notes: 'On time',
      );

      expect(record, sameRecord);
    });

    test('two instances with different values are not equal', () {
      final differentRecord = AttendanceRecord(
        id: 2,
        occurrenceId: 102,
        membername: 'member-2',
        status: AttendanceStatus.absent,
        recordedAtUtc: now,
      );

      expect(record, isNot(differentRecord));
    });

    test('equal instances have same hashCode', () {
      final sameRecord = AttendanceRecord(
        id: 1,
        occurrenceId: 101,
        membername: 'member-1',
        status: AttendanceStatus.present,
        recordedAtUtc: now,
        notes: 'On time',
      );

      expect(record.hashCode, sameRecord.hashCode);
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final updated = record.copyWith(status: AttendanceStatus.late);
      expect(updated.id, record.id);
      expect(updated.status, AttendanceStatus.late);
      expect(updated.membername, record.membername);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = record.copyWith(status: AttendanceStatus.absent);
      expect(updated.id, 1);
      expect(updated.occurrenceId, 101);
      expect(updated.membername, 'member-1');
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final basic = AttendanceRecord(
        id: 1,
        occurrenceId: 101,
        membername: 'member-1',
        status: AttendanceStatus.present,
        recordedAtUtc: now,
      );

      final updated = basic.copyWith(
        notes: () => 'Late due to traffic',
        membername: 'Jane Doe',
      );
      expect(updated.notes, 'Late due to traffic');
      expect(updated.membername, 'Jane Doe');
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final cleared = record.copyWith(notes: () => null);
      expect(cleared.notes, isNull);
    });

    test('toMap produces correct map structure', () {
      final map = record.toMap();
      expect(map['id'], 1);
      expect(map['occurrenceId'], 101);
      expect(map['membername'], 'member-1');
      expect(map['status'], 'present');
      expect(map['notes'], 'On time');
      expect(map['recordedAtUtc'], isA<int>());
    });

    test('fromMap restores equivalent instance', () {
      final map = record.toMap();
      final fromMap = AttendanceRecord.fromMap(map);
      expect(fromMap, record);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = AttendanceRecord.fromMap(record.toMap());
      expect(restored, record);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = record.toJson();
      final fromJson = AttendanceRecord.fromJson(json);
      expect(fromJson, record);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 1,
        'occurrenceId': 101,
        'membername': 'member-1',
        'status': 'absent',
        'recordedAtUtc': now.millisecondsSinceEpoch,
      };
      final r = AttendanceRecord.fromMap(map);
      expect(r.notes, isNull);
      expect(r.membername, 'member-1');
    });
  });

  group('AttendanceStats', () {
    const stats = AttendanceStats(
      membername: 'member-1',
      eventId: 1,
      presentCount: 10,
      absentCount: 2,
      lateCount: 3,
      onLeaveCount: 1,
    );

    test('two instances with same values are equal', () {
      const sameStats = AttendanceStats(
        membername: 'member-1',
        eventId: 1,
        presentCount: 10,
        absentCount: 2,
        lateCount: 3,
        onLeaveCount: 1,
      );

      expect(stats, sameStats);
    });

    test('two instances with different values are not equal', () {
      const differentStats = AttendanceStats(
        membername: 'member-2',
        eventId: 2,
        presentCount: 5,
        absentCount: 0,
        lateCount: 0,
        onLeaveCount: 0,
      );

      expect(stats, isNot(differentStats));
    });

    test('equal instances have same hashCode', () {
      const sameStats = AttendanceStats(
        membername: 'member-1',
        eventId: 1,
        presentCount: 10,
        absentCount: 2,
        lateCount: 3,
        onLeaveCount: 1,
      );

      expect(stats.hashCode, sameStats.hashCode);
    });

    test('totalRecorded sums all counts', () {
      expect(stats.totalRecorded, 16); // 10 + 2 + 3 + 1
    });

    test('attendanceRate calculates percentage correctly', () {
      // (present + late) / total * 100 = (10 + 3) / 16 * 100 = 81.25
      expect(stats.attendanceRate, closeTo(81.25, 0.01));
    });

    test('attendanceRate returns 0 when totalRecorded is 0', () {
      const emptyStats = AttendanceStats(
        membername: 'member-1',
        eventId: 1,
        presentCount: 0,
        absentCount: 0,
        lateCount: 0,
        onLeaveCount: 0,
      );
      expect(emptyStats.attendanceRate, 0);
    });

    test('copyWith creates new instance with changed field', () {
      final updated = stats.copyWith(presentCount: 15);
      expect(updated.membername, stats.membername);
      expect(updated.presentCount, 15);
      expect(updated.absentCount, stats.absentCount);
    });

    test('toMap produces correct map structure', () {
      final map = stats.toMap();
      expect(map['membername'], 'member-1');
      expect(map['eventId'], 1);
      expect(map['presentCount'], 10);
      expect(map['absentCount'], 2);
      expect(map['lateCount'], 3);
      expect(map['onLeaveCount'], 1);
    });

    test('fromMap restores equivalent instance', () {
      final map = stats.toMap();
      final fromMap = AttendanceStats.fromMap(map);
      expect(fromMap, stats);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = AttendanceStats.fromMap(stats.toMap());
      expect(restored, stats);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = stats.toJson();
      final fromJson = AttendanceStats.fromJson(json);
      expect(fromJson, stats);
    });

    test('fromMap handles missing counts as 0', () {
      final map = {'membername': 'member-1', 'eventId': 1};
      final s = AttendanceStats.fromMap(map);
      expect(s.presentCount, 0);
      expect(s.absentCount, 0);
      expect(s.lateCount, 0);
      expect(s.onLeaveCount, 0);
    });
  });
}
