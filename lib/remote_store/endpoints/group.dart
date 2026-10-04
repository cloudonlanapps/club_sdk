import 'package:meta/meta.dart';

@immutable
class GroupEndpoints {
  const GroupEndpoints();

  String get list => '/groups';
  String get deleted => '/groups/deleted';
  String group(int id) => '/groups/by_id/$id';
  String restore(int id) => '/groups/by_id/$id/restore';
  String hardDelete(int id) => '/groups/by_id/$id/hard';
  String addMember(int groupId, String username) =>
      '/groups/by_id/$groupId/members/byname/$username';
  String removeMember(int groupId, String username) =>
      '/groups/by_id/$groupId/members/$username';
  String members(int groupId) => '/groups/by_id/$groupId/members';
  String myGroups(String username) => '/users/by_id/$username/groups';
  String bulkMembers(int groupId) => '/groups/by_id/$groupId/members/bulk';
  String eligible(int groupId) => '/groups/by_id/$groupId/eligible';
  String requests(int groupId) => '/groups/by_id/$groupId/requests';
  String approveRequest(int groupId, int requestId) =>
      '/groups/by_id/$groupId/requests/$requestId/approve';
  String rejectRequest(int groupId, int requestId) =>
      '/groups/by_id/$groupId/requests/$requestId/reject';
}
