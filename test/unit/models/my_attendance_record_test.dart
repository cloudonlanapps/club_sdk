import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('MyAttendanceRecord', () {
    final sampleMap = {
      'eventId': 42,
      'occurrenceTimeUtc': DateTime.utc(2027, 3, 10, 10).millisecondsSinceEpoch,
      'membername': 'alice',
      'status': 'present',
      'notes': 'On time',
      'previousStatus': 'absent',
      'leaveReason': null,
      'recordedAtUtc': DateTime.utc(2027, 3, 10, 11).millisecondsSinceEpoch,
    };

    final record = MyAttendanceRecord(
      eventId: 42,
      occurrenceTimeUtc: DateTime.utc(2027, 3, 10, 10),
      membername: 'alice',
      status: AttendanceStatus.present,
      notes: 'On time',
      previousStatus: AttendanceStatus.absent,
      recordedAtUtc: DateTime.utc(2027, 3, 10, 11),
    );

    test('fromMap creates correct instance', () {
      final result = MyAttendanceRecord.fromMap(sampleMap);

      expect(result.eventId, 42);
      expect(result.occurrenceTimeUtc, DateTime.utc(2027, 3, 10, 10));
      expect(result.membername, 'alice');
      expect(result.status, AttendanceStatus.present);
      expect(result.notes, 'On time');
      expect(result.previousStatus, AttendanceStatus.absent);
      expect(result.leaveReason, isNull);
      expect(result.recordedAtUtc, DateTime.utc(2027, 3, 10, 11));
    });

    test('fromMap handles nullable fields as null', () {
      final minimal = {
        'eventId': 1,
        'occurrenceTimeUtc': DateTime.utc(2027).millisecondsSinceEpoch,
        'membername': 'bob',
        'status': 'late',
        'notes': null,
        'previousStatus': null,
        'leaveReason': null,
        'recordedAtUtc': DateTime.utc(2027, 1, 1, 1).millisecondsSinceEpoch,
      };
      final result = MyAttendanceRecord.fromMap(minimal);

      expect(result.notes, isNull);
      expect(result.previousStatus, isNull);
      expect(result.leaveReason, isNull);
    });

    test('toMap produces correct map', () {
      final map = record.toMap();

      expect(map['eventId'], 42);
      expect(map['membername'], 'alice');
      expect(map['status'], 'present');
      expect(map['notes'], 'On time');
      expect(map['previousStatus'], 'absent');
      expect(map['leaveReason'], isNull);
    });

    test('toJson and fromJson roundtrip', () {
      final jsonStr = record.toJson();
      final restored = MyAttendanceRecord.fromJson(jsonStr);

      expect(restored, record);
    });

    test('fromMap and toMap roundtrip', () {
      final restored = MyAttendanceRecord.fromMap(record.toMap());

      expect(restored, record);
    });

    test('copyWith updates fields', () {
      final updated = record.copyWith(
        status: AttendanceStatus.late,
        notes: () => null,
      );

      expect(updated.status, AttendanceStatus.late);
      expect(updated.notes, isNull);
      expect(updated.eventId, 42);
    });

    test('copyWith with no args returns equal instance', () {
      final copy = record.copyWith();

      expect(copy, record);
    });

    test('equality', () {
      final other = MyAttendanceRecord.fromMap(record.toMap());

      expect(other, record);
      expect(other.hashCode, record.hashCode);
    });

    test('inequality on different status', () {
      final other = record.copyWith(status: AttendanceStatus.absent);

      expect(other, isNot(record));
    });

    test('toString contains key info', () {
      final str = record.toString();

      expect(str, contains('eventId: 42'));
      expect(str, contains('membername: alice'));
      expect(str, contains('present'));
    });
  });

  group('MyAttendanceStats.fromRecords', () {
    test('computes correct counts from records', () {
      final records = [
        MyAttendanceRecord(
          eventId: 1,
          occurrenceTimeUtc: DateTime.utc(2027),
          membername: 'alice',
          status: AttendanceStatus.present,
          recordedAtUtc: DateTime.utc(2027, 1, 1, 1),
        ),
        MyAttendanceRecord(
          eventId: 1,
          occurrenceTimeUtc: DateTime.utc(2027, 1, 8),
          membername: 'alice',
          status: AttendanceStatus.present,
          recordedAtUtc: DateTime.utc(2027, 1, 8, 1),
        ),
        MyAttendanceRecord(
          eventId: 1,
          occurrenceTimeUtc: DateTime.utc(2027, 1, 15),
          membername: 'alice',
          status: AttendanceStatus.absent,
          recordedAtUtc: DateTime.utc(2027, 1, 15, 1),
        ),
        MyAttendanceRecord(
          eventId: 1,
          occurrenceTimeUtc: DateTime.utc(2027, 1, 22),
          membername: 'alice',
          status: AttendanceStatus.late,
          recordedAtUtc: DateTime.utc(2027, 1, 22, 1),
        ),
        MyAttendanceRecord(
          eventId: 1,
          occurrenceTimeUtc: DateTime.utc(2027, 1, 29),
          membername: 'alice',
          status: AttendanceStatus.onLeave,
          leaveReason: 'Medical',
          recordedAtUtc: DateTime.utc(2027, 1, 29, 1),
        ),
      ];

      final stats = MyAttendanceStats.fromRecords(records);

      expect(stats.presentCount, 2);
      expect(stats.absentCount, 1);
      expect(stats.lateCount, 1);
      expect(stats.leaveCount, 1);
      expect(stats.totalOccurrences, 5);
      // (present + late) / total * 100 = 3/5 * 100 = 60
      expect(stats.attendancePercentage, 60.0);
    });

    test('excludes onLeaveRequested from counts', () {
      final records = [
        MyAttendanceRecord(
          eventId: 1,
          occurrenceTimeUtc: DateTime.utc(2027),
          membername: 'alice',
          status: AttendanceStatus.present,
          recordedAtUtc: DateTime.utc(2027, 1, 1, 1),
        ),
        MyAttendanceRecord(
          eventId: 1,
          occurrenceTimeUtc: DateTime.utc(2027, 1, 8),
          membername: 'alice',
          status: AttendanceStatus.onLeaveRequested,
          recordedAtUtc: DateTime.utc(2027, 1, 8, 1),
        ),
      ];

      final stats = MyAttendanceStats.fromRecords(records);

      expect(stats.totalOccurrences, 1);
      expect(stats.presentCount, 1);
      expect(stats.attendancePercentage, 100.0);
    });

    test('empty records produce zero stats', () {
      final stats = MyAttendanceStats.fromRecords(const []);

      expect(stats.totalOccurrences, 0);
      expect(stats.presentCount, 0);
      expect(stats.absentCount, 0);
      expect(stats.lateCount, 0);
      expect(stats.leaveCount, 0);
      expect(stats.attendancePercentage, 0.0);
    });
  });
}
