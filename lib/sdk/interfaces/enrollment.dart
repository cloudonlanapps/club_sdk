import '../models/credit_disposition.dart';
import '../models/enrollment.dart';
import '../models/enums.dart';

/// Interface for enrollment management operations (admin/coach only).
///
/// Handles organizer-side enrollment actions: invitations,
/// assignments, requests, and withdrawals.
///
/// For member-facing enrollment operations (accept, decline, request,
/// withdraw, cancel-withdraw), use `MyEventsSource`.
///
/// ## Cancelled event series
///
/// All join-side mutations on this interface (`invite`, `assign`,
/// `assignTrial`, `approveRequest`, plus their bulk variants) are
/// rejected with `ServerException(422, INVALID_STATE)` once the event's
/// cutoff (`untilTimeUtc`) has been reached; until then a terminated or
/// cancelled event still accepts enrollment (#16). Super-admins bypass this
/// check. Exit-side mutations (`rejectRequest`, `removeEnrollment`,
/// `approveWithdraw`, `rejectWithdraw`) remain available so members
/// can leave and admins can clean up cancelled series.
///
/// ## Credit (#14)
///
/// Where the credit system is on, `assign`, `assignTrial` and
/// `approveRequest` (and their bulk forms) refuse a member with no usable
/// credit for the programme with `ServerException(422, INSUFFICIENT_CREDIT)`;
/// nothing is created. Inviting is not gated — the block sits at accept.
/// `removeEnrollment` and `approveWithdraw` take a [CreditDisposition],
/// required when the member holds a balance bound to the programme
/// (422 `CREDIT_DISPOSITION_REQUIRED`, the member stays) and refused where
/// credit is off or the event is not a programme
/// (422 `CREDIT_DISPOSITION_NOT_APPLICABLE`).
abstract interface class EnrollmentSource {
  // ══════════════════════════════════════════════════════════════════════════
  // ORGANIZER ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Invites a user to an event.
  ///
  /// Not credit-gated: an invitation is an offer, so a member with no
  /// credit can be invited. The credit check runs when they accept
  /// (`MyEventsSource.acceptInvite`).
  Future<void> invite(int eventId, String username);

  /// Invites multiple users atomically.
  Future<void> inviteBulk(int eventId, List<String> usernames);

  /// Assigns a user to an event (organizer-initiated enrollment).
  Future<void> assign(int eventId, String username);

  /// Assigns multiple users atomically.
  Future<void> assignBulk(int eventId, List<String> usernames);

  /// Assigns a user to a trial for an event.
  ///
  /// Server restricts this action to events of type `programme`. Calling
  /// on a `camp` or `oneOff` event raises
  /// `ServerException(400, INVALID_EVENT_TYPE)`.
  Future<void> assignTrial(int eventId, String username);

  /// Approves a user's enrollment request.
  Future<void> approveRequest(int eventId, String username);

  /// Approves multiple enrollment requests atomically.
  Future<void> approveRequestsBulk(int eventId, List<String> usernames);

  /// Rejects a user's enrollment request.
  Future<void> rejectRequest(
    int eventId,
    String username, {
    String? reason,
  });

  /// Rejects multiple enrollment requests atomically.
  Future<void> rejectRequestsBulk(
    int eventId,
    List<String> usernames, {
    String? reason,
  });

  /// Removes a user's enrollment.
  ///
  /// [creditDisposition] settles any credit bound to the programme; see the
  /// class note.
  Future<void> removeEnrollment(
    int eventId,
    String username, {
    String? reason,
    CreditDisposition? creditDisposition,
  });

  /// Removes multiple enrollments atomically. One [creditDisposition]
  /// applies to every member named.
  Future<void> removeEnrollmentsBulk(
    int eventId,
    List<String> usernames, {
    String? reason,
    CreditDisposition? creditDisposition,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WITHDRAWAL APPROVAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Approves a withdrawal request.
  ///
  /// [creditDisposition] settles any credit bound to the programme; see the
  /// class note. Rejecting a withdrawal leaves every account untouched.
  Future<void> approveWithdraw(
    int eventId,
    String username, {
    CreditDisposition? creditDisposition,
  });

  /// Approves multiple withdrawal requests atomically. One
  /// [creditDisposition] applies to every member named.
  Future<void> approveWithdrawBulk(
    int eventId,
    List<String> usernames, {
    CreditDisposition? creditDisposition,
  });

  /// Rejects a withdrawal request, restoring previous status.
  Future<void> rejectWithdraw(
    int eventId,
    String username, {
    String? reason,
  });

  /// Rejects multiple withdrawal requests atomically.
  Future<void> rejectWithdrawBulk(
    int eventId,
    List<String> usernames, {
    String? reason,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Gets a user's enrollment status for an event.
  Future<EnrollmentStatus?> getEnrollmentStatus(int eventId, String username);

  /// Gets the full enrollment record for a user in an event.
  ///
  /// Throws `ServerException` with `ENROLLMENT_NOT_FOUND` if not found.
  Future<Enrollment> getEnrollment(int eventId, String username);

  /// Lists enrollments for an event.
  Future<Map<String, EnrollmentStatus>> listEnrollments(
    int eventId, {
    EnrollmentStatus? status,
  });

  /// Lists enrollments for an event as full [Enrollment] records, keyed by
  /// membername.
  ///
  /// Unlike [listEnrollments] (statuses only), each value carries the
  /// timestamps (`enrolledAtUtc` / `withdrawnAtUtc`) needed to compute
  /// per-occurrence eligibility client-side via `enrollmentCoversOccurrence`.
  Future<Map<String, Enrollment>> listEnrollmentsDetailed(
    int eventId, {
    EnrollmentStatus? status,
  });
}
