import 'package:meta/meta.dart';

@immutable
class EnrollmentEndpoints {
  const EnrollmentEndpoints();

  String invite(int eventId) => '/events/by_id/$eventId/enrollments/invite';
  String assign(int eventId) => '/events/by_id/$eventId/enrollments/assign';
  String assignTrial(int eventId) =>
      '/events/by_id/$eventId/enrollments/assign-trial';
  String approve(int eventId) => '/events/by_id/$eventId/enrollments/approve';
  String reject(int eventId) => '/events/by_id/$eventId/enrollments/reject';
  String remove(int eventId) => '/events/by_id/$eventId/enrollments/remove';
  String approveWithdraw(int eventId) =>
      '/events/by_id/$eventId/enrollments/approve-withdraw';
  String rejectWithdraw(int eventId) =>
      '/events/by_id/$eventId/enrollments/reject-withdraw';
  String list(int eventId) => '/events/by_id/$eventId/enrollments';
}
