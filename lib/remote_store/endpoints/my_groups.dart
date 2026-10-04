import 'package:meta/meta.dart';

@immutable
class MyGroupsEndpoints {
  const MyGroupsEndpoints();

  String list(String username) => '/mygroups/by_id/$username';
  String group(String username, int groupId) =>
      '/mygroups/by_id/$username/group/$groupId';
  String eligible(String username) => '/mygroups/by_id/$username/eligible';
  String join(String username, int groupId) =>
      '/mygroups/by_id/$username/join/$groupId';
  String requests(String username) => '/mygroups/by_id/$username/requests';
  String request(String username, int requestId) =>
      '/mygroups/by_id/$username/requests/$requestId';
}
