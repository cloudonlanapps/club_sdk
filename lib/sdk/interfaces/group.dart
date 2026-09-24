import '../models/bulk_members_result.dart';
import '../models/eligible_user.dart';
import '../models/gender.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/join_request.dart';
import '../models/pagination.dart';

/// Interface for group management operations.
abstract interface class GroupSource {
  /// Get a paginated list of groups.
  Future<PaginatedList<Group>> getGroups({
    int offset = 0,
    int limit = 20,
  });

  /// Get a group by ID, with its members inline (`Group.members`, #6).
  ///
  /// The only group read that carries the members; every other read leaves
  /// `members` null and sends `memberCount` instead. For a sorted list, use
  /// [getMembers].
  Future<Group> getGroup(int id);

  /// Create a new group.
  ///
  /// When criteria fields are provided and [semiAuto] is true the resulting
  /// group's `kind` is `semiAuto`; with criteria and `semiAuto` false/omitted
  /// it is `auto`. Without criteria the group is `manual` regardless of
  /// [semiAuto].
  ///
  /// [dobOnOrAfterUtc] / [dobOnOrBeforeUtc] are inclusive DOB bounds.
  /// The server floors both values to UTC midnight on write.
  Future<Group> createGroup({
    required String name,
    String? description,
    DateTime? dobOnOrAfterUtc,
    DateTime? dobOnOrBeforeUtc,
    Gender? gender,
    bool? semiAuto,
  });

  /// Update a group. Uses ValueGetter pattern for nullable fields.
  ///
  /// Pass [semiAuto] to flip between `auto` and `semiAuto` when criteria are
  /// present. The server floors DOB bounds to UTC midnight on write.
  Future<Group> updateGroup(
    int id, {
    String? name,
    String? Function()? description,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    Gender? Function()? gender,
    bool? semiAuto,
  });

  /// Get a paginated list of soft-deleted groups.
  Future<PaginatedList<Group>> getDeletedGroups({
    int offset = 0,
    int limit = 20,
  });

  /// Delete a group (soft delete).
  Future<void> deleteGroup(int id);

  /// Restore a soft-deleted group.
  Future<Group> restoreGroup(int id);

  /// Permanently delete a group and all its data.
  /// Only super admin can perform this operation.
  Future<void> hardDeleteGroup(int id);

  /// Add a user to a group.
  Future<void> addMember(int groupId, String username);

  /// Remove a user from a group.
  Future<void> removeMember(int groupId, String username);

  /// Get members of a group.
  Future<List<GroupMember>> getMembers(
    int groupId, {
    String? sortBy,
    bool descending = false,
  });

  /// Get groups that a user is a member of.
  Future<List<Group>> getMyGroups(String username);

  /// Add multiple members to a group in a single operation.
  Future<BulkMembersResult> addMembersBulk(
    int groupId,
    List<String> membernames,
  );

  /// Users who can be added to (or request to join) a semi-auto group.
  ///
  /// Admin/coach only. The server returns a minimal `EligibleUserInfo`
  /// shape (username + optional name parts) so the caller can render a
  /// picker without pulling the full user list.
  Future<List<EligibleUser>> listEligible(int groupId);

  /// Join requests on a group, optionally filtered by status.
  ///
  /// Admin/coach only.
  Future<List<JoinRequest>> listRequests(
    int groupId, {
    JoinRequestStatus? status,
  });

  /// Approve a pending join request, re-checking semi-auto eligibility
  /// at decision time. Returns the updated [JoinRequest]. Admin only.
  ///
  /// Throws `ServerException(NOT_ELIGIBLE)` if the user no longer
  /// satisfies the group's criteria.
  Future<JoinRequest> approveRequest(int groupId, int requestId);

  /// Reject a pending join request with an optional reason. Returns
  /// the updated [JoinRequest]. Admin only.
  Future<JoinRequest> rejectRequest(
    int groupId,
    int requestId, {
    String? reason,
  });
}
