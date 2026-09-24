import '../models/group.dart';
import '../models/join_request.dart';

/// Member-facing groups sub-domain.
///
/// Mirrors the server's `/mygroups/by_id/{username}/...` routes.
/// Authorization: self, admin, or coach. Lets the user discover the
/// groups they belong to (explicit memberships + matching auto groups),
/// the groups they can request to join, and the lifecycle of their own
/// join requests (submit / list / cancel).
abstract interface class MyGroupsSource {
  /// Groups the user belongs to (explicit memberships + matching auto
  /// groups).
  Future<List<Group>> listGroups(String username);

  /// A single group the user is related to, by id.
  ///
  /// Visible when the user is a member of the group (explicit or auto), or
  /// has any join request against it (pending, approved, rejected,
  /// cancelled). Returns `ServerException(GROUP_NOT_FOUND)` (404) when no
  /// such relation exists. Useful for deep-links and cold-start callers
  /// that don't already have the warm `listGroups` cache.
  Future<Group> getGroup(String username, int groupId);

  /// Groups the user can request to join.
  ///
  /// Server excludes auto groups (joinable automatically), groups the
  /// user is already in, and any group with an outstanding pending
  /// request from the same user.
  Future<List<Group>> listEligible(String username);

  /// Submit a join request for a semi-auto [groupId].
  ///
  /// Throws `ServerException(AUTO_GROUP_NOT_JOINABLE)` for auto groups.
  Future<JoinRequest> joinGroup(
    String username,
    int groupId, {
    String? reason,
  });

  /// The user's own join requests, in any status.
  Future<List<JoinRequest>> listMyRequests(String username);

  /// Cancel a still-pending join request submitted by the user.
  /// Returns the updated [JoinRequest] (status `cancelled`).
  Future<JoinRequest> cancelRequest(String username, int requestId);
}
