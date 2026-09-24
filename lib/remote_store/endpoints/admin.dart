import 'package:meta/meta.dart';

@immutable
class AdminEndpoints {
  const AdminEndpoints();

  String get preferences => '/admin/preferences';
  String preference(String key) => '/admin/preferences/$key';
  String resetPassword(String username) => '/admin/reset-password/$username';
  String get staffListing => '/admin/staff-listing';
  String staffListingRow(String username) => '/admin/staff-listing/$username';
}
