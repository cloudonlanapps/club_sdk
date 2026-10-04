import 'package:meta/meta.dart';

@immutable
class MyEventsEndpoints {
  const MyEventsEndpoints();

  String list(String username) => '/myevents/by_id/$username';
  String event(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId';
  String schedules(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId/schedules';
  String enrollment(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId/enrollments';
  String acceptInvite(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId/enrollments/accept';
  String declineInvite(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId/enrollments/decline';
  String requestToJoin(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId/enrollments/request';
  String withdraw(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId/enrollments/withdraw';
  String cancelWithdraw(String username, int eventId) =>
      '/myevents/by_id/$username/$eventId/enrollments/cancel-withdraw';
  String occurrences(String username) =>
      '/myevents/by_id/$username/occurrences';
  String occurrence(String username, int eventId, Object timeStr) =>
      '/myevents/by_id/$username/$eventId/occurrences/$timeStr';
  String occurrenceAttendance(
    String username,
    int eventId,
    Object timeStr,
  ) => '/myevents/by_id/$username/$eventId/occurrences/$timeStr/attendance';
  String attendance(String username) => '/myevents/by_id/$username/attendance';
  String requestLeave(String username, int eventId, Object timeStr) =>
      '/myevents/by_id/$username/$eventId/occurrences/$timeStr/leave/request';
  String cancelLeave(String username, int eventId, Object timeStr) =>
      '/myevents/by_id/$username/$eventId/occurrences/$timeStr/leave/cancel';
}
