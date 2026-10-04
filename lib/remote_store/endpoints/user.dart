import 'package:meta/meta.dart';

@immutable
class UserEndpoints {
  const UserEndpoints();

  String get list => '/users';
  String get deleted => '/users/deleted';
  String get count => '/users/count';
  String get submitForReview => '/users/me/submit-for-review';
  String user(String username) => '/users/by_id/$username';
  String userPrivate(String username) => '/users/by_id/$username/private';
  String restore(String username) => '/users/by_id/$username/restore';
  String approve(String username) => '/users/by_id/$username/approve';
  String block(String username) => '/users/by_id/$username/block';
  String reconsider(String username) => '/users/by_id/$username/reconsider';
  String reapply(String username) => '/users/by_id/$username/reapply';
  String unblock(String username) => '/users/by_id/$username/unblock';
  String markLeft(String username) => '/users/by_id/$username/mark-left';
  String reactivate(String username) => '/users/by_id/$username/reactivate';
  String roles(String username) => '/users/by_id/$username/roles';
  String removeRole(String username, String role) =>
      '/users/by_id/$username/roles/$role';
  String transferSuperAdmin(String username) =>
      '/users/by_id/$username/transfer-superadmin';
  String hardDelete(String username) => '/users/by_id/$username/hard';
  String adminResetPassword(String username) =>
      '/admin/reset-password/$username';
}
