import '../../sdk/interfaces/group.dart';
import '../../sdk/models/bulk_members_result.dart';
import '../../sdk/models/eligible_user.dart';
import '../../sdk/models/gender.dart';
import '../../sdk/models/group.dart';
import '../../sdk/models/group_member.dart';
import '../../sdk/models/join_request.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [GroupSource] using HTTP API.
class RemoteGroupSource implements GroupSource {
  RemoteGroupSource(this._store);

  final RemoteStore _store;

  @override
  Future<PaginatedList<Group>> getGroups({
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.groups.list,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(
      response,
      Group.fromMap,
    );
  }

  @override
  Future<Group> getGroup(int id) async {
    final response = await _store.get(endpoints.groups.group(id));
    return Group.fromMap(response);
  }

  @override
  Future<Group> createGroup({
    required String name,
    String? description,
    DateTime? dobOnOrAfterUtc,
    DateTime? dobOnOrBeforeUtc,
    Gender? gender,
    bool? semiAuto,
  }) async {
    final response = await _store.post(
      endpoints.groups.list,
      body: {
        'name': name,
        'description': ?description,
        if (dobOnOrAfterUtc != null)
          'dobOnOrAfterUtc': dobOnOrAfterUtc.millisecondsSinceEpoch,
        if (dobOnOrBeforeUtc != null)
          'dobOnOrBeforeUtc': dobOnOrBeforeUtc.millisecondsSinceEpoch,
        if (gender != null) 'gender': gender.serverValue,
        'semiAuto': ?semiAuto,
      },
    );
    return Group.fromMap(response);
  }

  @override
  Future<Group> updateGroup(
    int id, {
    String? name,
    String? Function()? description,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    Gender? Function()? gender,
    bool? semiAuto,
  }) async {
    final body = <String, dynamic>{
      'name': ?name,
    };

    // Handle ValueGetter pattern for nullable fields
    if (description != null) {
      body['description'] = description();
    }
    if (dobOnOrAfterUtc != null) {
      body['dobOnOrAfterUtc'] = dobOnOrAfterUtc()?.millisecondsSinceEpoch;
    }
    if (dobOnOrBeforeUtc != null) {
      body['dobOnOrBeforeUtc'] = dobOnOrBeforeUtc()?.millisecondsSinceEpoch;
    }
    if (gender != null) {
      body['gender'] = gender()?.serverValue;
    }
    if (semiAuto != null) {
      body['semiAuto'] = semiAuto;
    }

    final response = await _store.patch(endpoints.groups.group(id), body: body);
    return Group.fromMap(response);
  }

  @override
  Future<PaginatedList<Group>> getDeletedGroups({
    int offset = 0,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.groups.deleted,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, Group.fromMap);
  }

  @override
  Future<void> deleteGroup(int id) async {
    await _store.delete(endpoints.groups.group(id));
  }

  @override
  Future<Group> restoreGroup(int id) async {
    final response = await _store.post(endpoints.groups.restore(id));
    return Group.fromMap(response);
  }

  @override
  Future<void> hardDeleteGroup(int id) async {
    await _store.delete(endpoints.groups.hardDelete(id));
  }

  @override
  Future<void> addMember(int groupId, String username) async {
    await _store.postVoid(endpoints.groups.addMember(groupId, username));
  }

  @override
  Future<void> removeMember(int groupId, String username) async {
    await _store.delete(endpoints.groups.removeMember(groupId, username));
  }

  @override
  Future<List<GroupMember>> getMembers(
    int groupId, {
    String? sortBy,
    bool descending = false,
  }) async {
    // The route returns the whole membership and declares only sortBy and
    // descending — no offset/limit, so there is no page to report.
    final response = await _store.getList(
      endpoints.groups.members(groupId),
      queryParams: {
        'sortBy': ?sortBy,
        'descending': descending.toString(),
      },
    );
    return response
        .map((item) => GroupMember.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Group>> getMyGroups(String username) async {
    final response = await _store.getList(endpoints.groups.myGroups(username));
    return response
        .map((item) => Group.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BulkMembersResult> addMembersBulk(
    int groupId,
    List<String> membernames,
  ) async {
    final response = await _store.post(
      endpoints.groups.bulkMembers(groupId),
      body: {
        'membernames': membernames,
      },
    );
    return BulkMembersResult.fromMap(response);
  }

  @override
  Future<List<EligibleUser>> listEligible(int groupId) async {
    final response = await _store.getList(endpoints.groups.eligible(groupId));
    return response
        .map((e) => EligibleUser.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<JoinRequest>> listRequests(
    int groupId, {
    JoinRequestStatus? status,
  }) async {
    final queryParams = <String, String>{
      if (status != null) 'status': status.name,
    };
    final response = await _store.getList(
      endpoints.groups.requests(groupId),
      queryParams: queryParams.isEmpty ? null : queryParams,
    );
    return response
        .map((e) => JoinRequest.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<JoinRequest> approveRequest(int groupId, int requestId) async {
    final response = await _store.post(
      endpoints.groups.approveRequest(groupId, requestId),
    );
    return JoinRequest.fromMap(response);
  }

  @override
  Future<JoinRequest> rejectRequest(
    int groupId,
    int requestId, {
    String? reason,
  }) async {
    final response = await _store.post(
      endpoints.groups.rejectRequest(groupId, requestId),
      body: {
        'reason': ?reason,
      },
    );
    return JoinRequest.fromMap(response);
  }
}
