import 'package:meta/meta.dart';

@immutable
class AttendanceEndpoints {
  const AttendanceEndpoints();

  String attendance(int eventId, Object timeStr) =>
      '/events/by_id/$eventId/occurrences/$timeStr/attendance';
  String clearAttendance(int eventId, Object timeStr, String membername) =>
      '/events/by_id/$eventId/occurrences/$timeStr/attendance/$membername';
  /// Cross-event attendance over a time window.
  String get occurrencesReport => '/events/occurrences/attendance';
  String approveLeave(int eventId, Object timeStr) =>
      '/events/by_id/$eventId/occurrences/$timeStr/leave/approve';
  String rejectLeave(int eventId, Object timeStr) =>
      '/events/by_id/$eventId/occurrences/$timeStr/leave/reject';
}
