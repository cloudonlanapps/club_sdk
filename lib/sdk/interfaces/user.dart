import '../models/address.dart';
import '../models/gender.dart';
import '../models/pagination.dart';
import '../models/user.dart';
import '../models/user_counts.dart';

/// Interface for user management operations.
///
/// All user lookups use `username` as the unique identifier.
abstract interface class UserSource {
  // ── List / Detail ──────────────────────────────────────────────────────────

  /// Fetch a paginated list of users with optional filters.
  Future<PaginatedList<UserInfo>> getUsers({
    int offset = 0,
    int limit = 20,
    UserStatus? status,
    String? role,
    int? minAge,
    int? maxAge,
    String? searchTerm,
    String? sortBy,
    bool descending = false,
  });

  /// Get a user's public profile by username.
  Future<UserInfo> getUserInfo(String username);

  /// Get a user's private profile by username.
  Future<UserPrivate> getUserPrivate(String username);

  /// Fetch a paginated list of soft-deleted users.
  Future<PaginatedList<UserInfo>> getDeletedUsers({
    int offset = 0,
    int limit = 20,
  });

  /// Live user counts by status (admin or coach), from `GET /users/count`
  /// (#30). See [UserCounts] for what is and is not counted.
  Future<UserCounts> getUserCounts();

  // ── Create / Update / Delete ───────────────────────────────────────────────

  /// Create a new user with the provided details.
  ///
  /// [isGuest] marks a guest account (club_server#332, #24): the server
  /// writes the staff-listing row as a guest and publishes the profile on
  /// the admin's authority, since a guest never logs in to consent. Not a
  /// field of self-registration.
  Future<UserPrivate> createUser({
    required String username,
    required String email,
    required String passwordHash,
    required String phone,
    required DateTime dateOfBirthUtc,
    required Gender gender,
    String? firstName,
    String? middleName,
    String? lastName,
    String? bio,
    String? achievements,
    String? emergencyContact,
    String? medicalNotes,
    UserStatus status = UserStatus.pending,
    Address? address,
    bool isGuest = false,
  });

  /// Update a user's profile. Uses ValueGetter pattern for nullable fields.
  ///
  /// Staff-listing curation (position, guest, hidden) is not a profile
  /// edit; it lives on `AdminSource` (club_server#332, #26).
  Future<UserPrivate> updateUser(
    String username, {
    String? email,
    String? Function()? firstName,
    String? Function()? middleName,
    String? Function()? lastName,
    String? Function()? phone,
    DateTime? Function()? dateOfBirthUtc,
    String? Function()? bio,
    String? Function()? achievements,
    String? Function()? emergencyContact,
    String? Function()? medicalNotes,
    String? Function()? nickname,
    bool? useNamePublicly,
    Gender? Function()? gender,
    Address? Function()? address,
    bool? isPublicProfile,
  });

  /// Soft delete a user.
  Future<void> deleteUser(String username);

  /// Permanently delete a user and all their data.
  /// Only super admin can perform this operation.
  Future<void> hardDeleteUser(String username);

  /// Restore a soft-deleted user.
  Future<UserPrivate> restoreUser(String username);

  // ── Login Lifecycle ────────────────────────────────────────────────────────

  /// Caller signals they have finished setting up their account and is ready
  /// for admin review. Flips caller status from `registered` to `pending`
  /// and enqueues the deferred `user_approval` admin notification.
  ///
  /// Returns 409 `INVALID_STATE` if the caller is not in `registered` status.
  Future<UserPrivate> submitForReview();

  /// Approve a pending user, setting their status to active.
  ///
  /// When [resolutionReason] is supplied, it is recorded as the closing note
  /// on any active `user_review_requests` row for the target (see #122).
  Future<UserInfo> approveUser(String username, {String? resolutionReason});

  /// Block a user.
  ///
  /// When [resolutionReason] is supplied, it is recorded as the closing note
  /// on any active `user_review_requests` row for the target (see #122).
  Future<UserInfo> blockUser(String username, {String? resolutionReason});

  /// Admin asks a pending user to revisit their registration (#122).
  ///
  /// Flips the target from `pending` back to `registered`, deletes the stale
  /// `user_approval` admin notification, and records [reason] on a new
  /// active `user_review_requests` row (superseding any prior active row).
  /// Returns the updated [UserInfo].
  ///
  /// - 400 `CANNOT_RECONSIDER_SELF` if the admin is the target.
  /// - 404 `USER_NOT_FOUND` if the target is missing or soft-deleted.
  /// - 409 `INVALID_STATE` if the target is not `pending`.
  Future<UserInfo> reconsiderUser(String username, String reason);

  /// Self-only resubmit of registration fields in response to an active
  /// reconsider request (#122). Distinct from admin [updateUser]: only the
  /// listed registration fields are accepted; status stays `registered` (it
  /// does NOT auto-flip to `pending`). Caller must subsequently call
  /// [submitForReview] to re-notify admins. Closes the active review row
  /// as `resubmitted` so `adminReviewNote` returns to `null`.
  ///
  /// - 403 `INSUFFICIENT_PERMISSION` if [username] is not the caller.
  /// - 409 `NO_ACTIVE_REVIEW_REQUEST` if no active review row exists.
  /// - 409 `INVALID_STATE` if caller status is not `registered`.
  Future<UserPrivate> reapply(
    String username, {
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? dateOfBirthUtc,
    Gender? gender,
    String? phone,
    String? email,
  });

  /// Unblock a user.
  Future<UserInfo> unblockUser(String username);

  /// Mark a user as left.
  Future<UserInfo> markLeft(String username);

  /// Reactivate a user who previously left.
  Future<UserInfo> reactivateUser(String username);

  // ── Role Management ────────────────────────────────────────────────────────

  /// Assign a role to the user.
  Future<UserInfo> assignRole(String username, String role);

  /// Remove a role from the user.
  Future<UserInfo> removeRole(String username, String role);

  // ── Super Admin ────────────────────────────────────────────────────────────

  /// Transfer the Super Admin role to another Admin user.
  Future<UserInfo> transferSuperAdmin(String username);

  /// Admin resets a user's password, returning the new temporary password.
  Future<String> adminResetPassword(String username);
}
