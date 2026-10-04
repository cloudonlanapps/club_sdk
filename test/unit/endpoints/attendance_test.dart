import 'package:club_sdk_2/remote_store/endpoints/attendance.dart';
import 'package:test/test.dart';

void main() {
  const ep = AttendanceEndpoints();

  group('AttendanceEndpoints', () {
    test('attendance with int timeStr', () {
      expect(
        ep.attendance(1, 1700000000000),
        '/events/by_id/1/occurrences/1700000000000/attendance',
      );
    });
    test('attendance with String timeStr', () {
      expect(
        ep.attendance(1, '1700000000000'),
        '/events/by_id/1/occurrences/1700000000000/attendance',
      );
    });
    test('clearAttendance', () {
      expect(
        ep.clearAttendance(1, 1700000000000, 'alice'),
        '/events/by_id/1/occurrences/1700000000000/attendance/alice',
      );
    });
    test('approveLeave', () {
      expect(
        ep.approveLeave(1, 1700000000000),
        '/events/by_id/1/occurrences/1700000000000/leave/approve',
      );
    });
    test('rejectLeave', () {
      expect(
        ep.rejectLeave(1, 1700000000000),
        '/events/by_id/1/occurrences/1700000000000/leave/reject',
      );
    });
  });
}
