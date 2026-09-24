import '../../sdk/interfaces/my_groups.dart';
import '../../sdk/models/group.dart';
import '../../sdk/models/join_request.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [MyGroupsSource] using HTTP API.
class RemoteMyGroupsSource implements MyGroupsSource {
  RemoteMyGroupsSource(this._store);

  final RemoteStore _store;

  @override
  Future<List<Group>> listGroups(String username) async {
    final response = await _store.getList(endpoints.myGroups.list(username));
    return response
        .map((e) => Group.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Group> getGroup(String username, int groupId) async {
    final response = await _store.get(
      endpoints.myGroups.group(username, groupId),
    );
    return Group.fromMap(response);
  }

  @override
  Future<List<Group>> listEligible(String username) async {
    final response = await _store.getList(
      endpoints.myGroups.eligible(username),
    );
    return response
        .map((e) => Group.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<JoinRequest> joinGroup(
    String username,
    int groupId, {
    String? reason,
  }) async {
    final response = await _store.post(
      endpoints.myGroups.join(username, groupId),
      body: {
        'reason': ?reason,
      },
    );
    return JoinRequest.fromMap(response);
  }

  @override
  Future<List<JoinRequest>> listMyRequests(String username) async {
    final response = await _store.getList(
      endpoints.myGroups.requests(username),
    );
    return response
        .map((e) => JoinRequest.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<JoinRequest> cancelRequest(String username, int requestId) async {
    final response = await _store.delete(
      endpoints.myGroups.request(username, requestId),
    );
    if (response == null) {
      throw StateError(
        'cancelRequest expected a JoinRequest body but server returned no '
        'content.',
      );
    }
    return JoinRequest.fromMap(response);
  }
}
