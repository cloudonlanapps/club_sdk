import 'package:club_sdk_2/club_sdk_2.dart';

/// The effective end time of an event's last occurrence.
///
/// For a one-off event (`event.rrule` is null/empty) this is simply
/// `event.endTimeUtc` — the single occurrence's end.
///
/// For a recurring series (`event.rrule` set, e.g. `FREQ=DAILY;COUNT=5`
/// on a camp) this expands the rrule, takes the last occurrence's start,
/// and adds the per-occurrence session duration
/// (`endTimeUtc - startTimeUtc`). The series is considered ended only
/// when that last-occurrence end has passed.
///
/// When `untilTimeUtc` is set (a cancelled-mid-series event — see
/// [isEventSeriesCancelled]) it is used as the UPPER BOUND of the rrule
/// expansion, so the last occurrence is the cancellation-truncated one
/// rather than the natural series end. This is distinct from using
/// `untilTimeUtc` as a series-end *fallback* when `endTimeUtc` is
/// missing, which would be wrong: the rrule remains the only source of
/// truth for an uncancelled series' end (hence the 5-year ceiling when
/// `untilTimeUtc` is null). See #688.
///
/// Defensive: if the rrule fails to parse, falls back to
/// `event.endTimeUtc` so a malformed rrule degrades to the
/// pre-fix behaviour rather than crashing.
DateTime lastOccurrenceEndUtc(Event event) {
  final sessionDuration = event.endTimeUtc.difference(event.startTimeUtc);
  final rrule = event.rrule;
  if (rrule == null || rrule.isEmpty) return event.endTimeUtc;

  try {
    final util = RruleUtil();
    final (parsed, exdates) = util.parseRruleWithExdates(rrule);
    if (parsed.isEmpty) return event.endTimeUtc;

    // Expand over a generous window so COUNT-bounded rules (most camps)
    // hit their natural last occurrence, and UNTIL-bounded rules (some
    // programmes) terminate at the rule's own until clause. For a
    // cancelled-mid-series event, `untilTimeUtc` caps the expansion at
    // the cancellation point. The 5-year ceiling is a safety bound for
    // unbounded, uncancelled rules — club event series are all
    // short-lived and won't approach it.
    final result = util.expand(
      rrule: parsed,
      dtStart: event.startTimeUtc,
      fromUtc: event.startTimeUtc,
      toUtc:
          event.untilTimeUtc ??
          event.startTimeUtc.add(const Duration(days: 365 * 5)),
      excludeDates: exdates.isNotEmpty ? exdates : null,
    );
    if (result.occurrences.isEmpty) return event.endTimeUtc;

    return result.occurrences.last.add(sessionDuration);
  } on Object catch (_) {
    return event.endTimeUtc;
  }
}

/// Whether the event's last occurrence has ended.
///
/// For a recurring series this is "the last occurrence's end is in
/// the past", computed by expanding the rrule. See
/// [lastOccurrenceEndUtc]. The previous implementation used
/// `event.endTimeUtc` (which is only the *first* occurrence's end on
/// a series) and so reported camps as past after day 1 — see #686.
bool isPastEvent(Event event, {DateTime? now}) =>
    lastOccurrenceEndUtc(event).isBefore((now ?? DateTime.now()).toUtc());

/// Whether the event has stopped: a cutoff (`untilTimeUtc`) is set and has
/// been reached (#16).
///
/// A terminated programme, a cancelled camp or a dropped one-off keeps
/// running and accepting enrollment until its cutoff, so a cutoff in the
/// future does not make the event cancelled yet. See
/// [isOccurrenceCancelled] for the per-occurrence rule.
bool isEventSeriesCancelled(Event event, {DateTime? now}) {
  final cutoff = event.untilTimeUtc;
  if (cutoff == null) return false;
  return !(now ?? DateTime.now()).toUtc().isBefore(cutoff);
}

/// Whether the occurrence at [occurrenceTimeUtc] is cancelled (#16): it
/// carries a cancelled override ([overrideStatus]), or its slot is at or
/// after the event's cutoff. There is no whole-event "cancelled".
bool isOccurrenceCancelled(
  Event event,
  DateTime occurrenceTimeUtc, {
  OccurrenceStatus? overrideStatus,
}) {
  if (overrideStatus == OccurrenceStatus.cancelled) return true;
  final cutoff = event.untilTimeUtc;
  if (cutoff == null) return false;
  return !occurrenceTimeUtc.toUtc().isBefore(cutoff);
}

/// Whether [actingUser] can perform a join-side enrollment action (invite,
/// assign, assign-trial, approve-request, accept, request) on [event].
///
/// Super-admins always pass. Otherwise rejects past events and cancelled
/// series, mirroring the server's join-side guards.
bool canEnrollOnEvent(Event event, UserPrivate actingUser, {DateTime? now}) {
  if (actingUser.isSuperAdmin) return true;
  if (isPastEvent(event, now: now)) return false;
  if (isEventSeriesCancelled(event, now: now)) return false;
  return true;
}

/// Whether [actingUser] can open the Assign Trial flow for [event].
///
/// In addition to the join-side gate, trial assignment is restricted to
/// programme events server-side (`INVALID_EVENT_TYPE` on camp/one-off).
bool canAssignTrial(Event event, UserPrivate actingUser, {DateTime? now}) =>
    event.type == EventType.programme &&
    canEnrollOnEvent(event, actingUser, now: now);

/// Whether [actingUser] may mark or clear attendance and decide leave on
/// [event]: an admin, the organizer, or a coach assigned to the event
/// (`event.coachNames`). Mirrors the server's coach tier (club_server#247,
/// #29).
bool canManageAttendance(Event event, UserPrivate actingUser) =>
    actingUser.isAdmin ||
    actingUser.username == event.organizerName ||
    (event.coachNames?.contains(actingUser.username) ?? false);

/// Minimum lead time before an occurrence's effective start at which
/// attendance marking opens. Mirrors the server's `ATTENDANCE_NOT_YET_OPEN`
/// rule.
const attendanceOpenLeadIn = Duration(minutes: 30);

/// How long after an occurrence's effective start admin can still edit
/// attendance. Mirrors the server's `EDIT_WINDOW_CLOSED` rule. Server is
/// the source of truth; this constant is a client-side gate for UI
/// affordance visibility — a server-rejected mutation still surfaces as
/// a toast.
const attendanceEditWindow = Duration(days: 15);

/// How far ahead of an occurrence's effective start a member can still
/// apply for leave. Mirrors the server's `LEAVE_WINDOW_CLOSED` rule.
const leaveCutoff = Duration(hours: 2);

/// Whether attendance can be marked **right now** for an occurrence with
/// the given [effectiveStartTimeUtc] / [effectiveEndTimeUtc]. The window
/// opens [attendanceOpenLeadIn] before the effective start and closes
/// [attendanceEditWindow] after the effective end.
///
/// Super-admins bypass only the *upper* bound — they may correct the audit
/// trail after the edit window closes, but they cannot mark attendance
/// before the session has effectively started (no fabricating future
/// attendance).
///
/// Server contract:
///   * before `start - 30min`        → `ATTENDANCE_NOT_YET_OPEN`
///   * after  `end   + 15d`          → `EDIT_WINDOW_CLOSED`
bool canMarkAttendanceNow({
  required UserPrivate actingUser,
  required DateTime effectiveStartTimeUtc,
  required DateTime effectiveEndTimeUtc,
}) {
  final now = DateTime.now().toUtc();
  final opens = effectiveStartTimeUtc.subtract(attendanceOpenLeadIn);
  if (now.isBefore(opens)) return false;
  if (actingUser.isSuperAdmin) return true;
  final closes = effectiveEndTimeUtc.add(attendanceEditWindow);
  return !now.isAfter(closes);
}

/// Whether the occurrence is still in its "future, schedulable" window —
/// admin can cancel / reschedule. Closes 30 minutes before the effective
/// start, when the attendance window opens.
bool isInScheduleManagementWindow(DateTime effectiveStartTimeUtc) {
  return DateTime.now().toUtc().isBefore(
    effectiveStartTimeUtc.subtract(attendanceOpenLeadIn),
  );
}

/// Whether a member can still apply for leave — opens immediately on
/// enrollment, closes [leaveCutoff] before the effective start.
bool isInLeaveApplicationWindow(DateTime effectiveStartTimeUtc) {
  return DateTime.now().toUtc().isBefore(
    effectiveStartTimeUtc.subtract(leaveCutoff),
  );
}

/// Enrollment statuses that count as "actively enrolled" when deciding
/// whether a member covers a *future or current* occurrence. Mirrors the
/// server's `ACTIVE_ENROLLMENT_STATUSES` (`services/eligibility.py`).
const Set<EnrollmentStatus> _activeEnrollmentStatuses = {
  EnrollmentStatus.invited,
  EnrollmentStatus.requested,
  EnrollmentStatus.accepted,
  EnrollmentStatus.assigned,
  EnrollmentStatus.assignedTrial,
  EnrollmentStatus.withdrawRequested,
};

/// Whether [enrollment] makes the member eligible for the occurrence at
/// [occurrenceTimeUtc]. Pure client-side mirror of the server's
/// `enrollment_covers_occurrence` — the server stays the source of truth;
/// this lets admin UIs gate the attendance roster before submitting a bulk
/// mark (so members who were not enrolled at a past occurrence are not
/// included and the whole batch does not fail).
///
///   * Future / current occurrence (`occ >= now`): requires an active
///     (non-terminal) status.
///   * Past occurrence (`occ < now`): requires a temporal participation
///     window — `enrolledAtUtc <= occ` and (`withdrawnAtUtc` is null or
///     `withdrawnAtUtc >= occ`).
bool enrollmentCoversOccurrence(
  Enrollment enrollment,
  DateTime occurrenceTimeUtc, {
  DateTime? now,
}) {
  final nowUtc = (now ?? DateTime.now()).toUtc();
  final occ = occurrenceTimeUtc.toUtc();
  if (!occ.isBefore(nowUtc)) {
    return _activeEnrollmentStatuses.contains(enrollment.status);
  }
  final enrolledAt = enrollment.enrolledAtUtc;
  if (enrolledAt == null) return false;
  if (enrolledAt.isAfter(occ)) return false;
  final withdrawnAt = enrollment.withdrawnAtUtc;
  if (withdrawnAt != null && withdrawnAt.isBefore(occ)) return false;
  return true;
}

String mapEnrollmentMutationError(ServerException e) => switch (e.code) {
  SdkErrorCode.invalidState => 'This event is no longer open for enrollment.',
  SdkErrorCode.invalidEventType =>
    'Trial assignment is only available for programme events.',
  SdkErrorCode.insufficientPermission =>
    'You do not have permission to do this.',
  SdkErrorCode.userNotEligibleForEvent =>
    'This member is not eligible for this event.',
  _ => e.message,
};

String mapAttendanceMutationError(ServerException e) => switch (e.code) {
  SdkErrorCode.invalidState =>
    'This member was not enrolled at the time of this session.',
  SdkErrorCode.insufficientPermission =>
    'Only the event organizer, an assigned coach or an admin can manage '
        'attendance.',
  SdkErrorCode.attendanceNotYetOpen =>
    'Attendance marking opens 30 minutes before the session starts.',
  SdkErrorCode.editWindowClosed =>
    'The attendance edit window for this session has closed.',
  _ => e.message,
};
