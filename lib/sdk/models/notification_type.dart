/// The notification `type` strings the server emits.
///
/// `AppNotification.type` stays a plain string so an unknown type still
/// passes through; these constants let an app switch on the known ones
/// without retyping wire names. The set gained the types added since the
/// server's 0.5 release (#31): programme termination and extension,
/// conflict reports, credit release, the evaluation lifecycle and public
/// inquiries.
abstract final class NotificationType {
  // ── Account and users ───────────────────────────────────────────────────
  static const accountPasswordChangedByAdmin =
      'account.password_changed_by_admin';
  static const accountPasswordChangedSelf = 'account.password_changed_self';
  static const accountRegistrationApproved = 'account.registration_approved';
  static const profileChangedByAdmin = 'profile.changed_by_admin';
  static const userBlocked = 'user.blocked';
  static const userDeleted = 'user.deleted';
  static const userRegistrationPending = 'user.registration_pending';
  static const userRestored = 'user.restored';
  static const userRoleChanged = 'user.role_changed';
  static const userUnblocked = 'user.unblocked';

  // ── Attendance ──────────────────────────────────────────────────────────
  static const attendanceAbsenceStreakWarning =
      'attendance.absence_streak_warning';
  static const attendanceCorrectionRequested =
      'attendance.correction_requested';
  static const attendanceCorrectionResponse = 'attendance.correction_response';
  static const attendanceMarked = 'attendance.marked';
  static const attendancePendingMarkReminder =
      'attendance.pending_mark_reminder';

  // ── Broadcasts ──────────────────────────────────────────────────────────
  static const broadcastMessage = 'broadcast.message';

  // ── Credits (#374) ──────────────────────────────────────────────────────
  /// A terminated programme's bound credit was released to a general
  /// account. Payload: the account and the programme it came from.
  static const creditReleased = 'credit.released';

  // ── Enrollment ──────────────────────────────────────────────────────────
  static const enrollmentAdminEnrolled = 'enrollment.admin_enrolled';
  static const enrollmentCancelledAdmin = 'enrollment.cancelled_admin';
  static const enrollmentCancelledSelf = 'enrollment.cancelled_self';
  static const enrollmentClosed = 'enrollment.closed';
  static const enrollmentOpened = 'enrollment.opened';
  static const enrollmentRsvp = 'enrollment.rsvp';

  // ── Evaluations (#302) ──────────────────────────────────────────────────
  static const evaluationPublished = 'evaluation.published';
  static const evaluationTransferred = 'evaluation.transferred';
  static const evaluationWithdrawn = 'evaluation.withdrawn';

  // ── Events ──────────────────────────────────────────────────────────────
  static const eventCancelled = 'event.cancelled';
  static const eventCoachChanged = 'event.coach_changed';

  /// A non-blocking overlap was reported to admins (#382).
  static const eventConflictDetected = 'event.conflict_detected';
  static const eventDeleted = 'event.deleted';

  /// A programme's cutoff was moved earlier (#306, #374).
  static const eventExtended = 'event.extended';
  static const eventRescheduled = 'event.rescheduled';
  static const eventRestored = 'event.restored';
  static const eventSplit = 'event.split';

  /// A programme was terminated; payload carries `reason` and
  /// `cutoffTimeUtc` (#306).
  static const eventTerminated = 'event.terminated';
  static const eventUpcomingReminder = 'event.upcoming_reminder';
  static const eventVenueChanged = 'event.venue_changed';

  // ── Groups ──────────────────────────────────────────────────────────────
  static const groupArchived = 'group.archived';
  static const groupJoinRequest = 'group.join_request';
  static const groupJoinResponse = 'group.join_response';
  static const groupMemberAdded = 'group.member_added';
  static const groupMemberRemoved = 'group.member_removed';
  static const groupSettingsChanged = 'group.settings_changed';

  // ── Inquiries (#407) ────────────────────────────────────────────────────
  /// A public inquiry was stored; one notification per admin.
  static const inquiryReceived = 'inquiry.received';

  // ── Occurrences ─────────────────────────────────────────────────────────
  static const occurrenceCancelled = 'occurrence.cancelled';
  static const occurrenceRescheduled = 'occurrence.rescheduled';
  static const occurrenceRestored = 'occurrence.restored';

  // ── Venues ──────────────────────────────────────────────────────────────
  static const venueRenamed = 'venue.renamed';

  /// Every type the SDK knows. A type absent from this set is still a
  /// valid `AppNotification.type`; it just has no constant yet.
  static const Set<String> all = {
    accountPasswordChangedByAdmin,
    accountPasswordChangedSelf,
    accountRegistrationApproved,
    profileChangedByAdmin,
    userBlocked,
    userDeleted,
    userRegistrationPending,
    userRestored,
    userRoleChanged,
    userUnblocked,
    attendanceAbsenceStreakWarning,
    attendanceCorrectionRequested,
    attendanceCorrectionResponse,
    attendanceMarked,
    attendancePendingMarkReminder,
    broadcastMessage,
    creditReleased,
    enrollmentAdminEnrolled,
    enrollmentCancelledAdmin,
    enrollmentCancelledSelf,
    enrollmentClosed,
    enrollmentOpened,
    enrollmentRsvp,
    evaluationPublished,
    evaluationTransferred,
    evaluationWithdrawn,
    eventCancelled,
    eventCoachChanged,
    eventConflictDetected,
    eventDeleted,
    eventExtended,
    eventRescheduled,
    eventRestored,
    eventSplit,
    eventTerminated,
    eventUpcomingReminder,
    eventVenueChanged,
    groupArchived,
    groupJoinRequest,
    groupJoinResponse,
    groupMemberAdded,
    groupMemberRemoved,
    groupSettingsChanged,
    inquiryReceived,
    occurrenceCancelled,
    occurrenceRescheduled,
    occurrenceRestored,
    venueRenamed,
  };

  /// Whether [type] is one the SDK has a constant for.
  static bool isKnown(String type) => all.contains(type);

  /// The types added since the server's 0.5 release (#31).
  static const Set<String> addedSinceRelease05 = {
    eventTerminated,
    eventExtended,
    eventConflictDetected,
    creditReleased,
    evaluationPublished,
    evaluationWithdrawn,
    evaluationTransferred,
    inquiryReceived,
  };
}
