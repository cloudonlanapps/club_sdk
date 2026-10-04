import '../models/attendance.dart';
import '../models/attendance_mark_record.dart';
import '../models/attendance_mark_report.dart';

/// Interface for attendance management operations (admin/coach only).
///
/// Handles attendance marking and leave approval/rejection.
///
/// For member-facing attendance operations (declare leave, cancel leave,
/// get stats, get my attendance), use `MyEventsSource`.
abstract interface class AttendanceSource {
  // ══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE MARKING
  // ══════════════════════════════════════════════════════════════════════════

  /// Records or corrects attendance for one or more participants.
  ///
  /// Pre-occurrence gate: marking opens 30 minutes before the occurrence's
  /// effective start time. Earlier calls throw `ServerException` with
  /// `ATTENDANCE_NOT_YET_OPEN`. Super-admins bypass this gate.
  ///
  /// Attendance can only be edited within the edit window (15 days after the
  /// occurrence's effective start). After the window closes, edits will throw
  /// `ServerException` with `EDIT_WINDOW_CLOSED`
  /// is true.
  ///
  /// The effective start is `OccurrenceOverride.newStartTimeUtc` when an
  /// override exists for the slot, otherwise the original [occurrenceTimeUtc]
  /// (the RRULE-derived slot key). All windowing math on the server uses this
  /// effective start; clients should mirror it.
  ///
  /// Only a super-admin bypasses the edit window; the server grants no
  /// per-request override.
  ///
  /// Members are settled independently (#14): the report says who was
  /// recorded and who was refused, and why. On a programme with the credit
  /// system on, a member holding no usable credit is refused with
  /// `INSUFFICIENT_CREDIT` while everyone else is still marked; the call
  /// does not throw for that. Where credit is off, `refused` is always
  /// empty. Marking `present`, `absent` or `late` charges one occurrence;
  /// moving between those three costs nothing more, and clearing refunds.
  ///
  /// A mark that spends the last of a trial member's credit ends their
  /// trial: the server removes them from the programme and names them in
  /// `trialEnded` (as well as `marked`). When it is non-empty, refresh the
  /// event's enrollments.
  Future<AttendanceMarkReport> markAttendance(
    int eventId,
    DateTime occurrenceTimeUtc,
    List<AttendanceMarkRecord> records,
  );

  /// Clears a member's attendance mark for an occurrence, returning them to
  /// the "not recorded" state.
  ///
  /// Only real marks (present/absent/late) are cleared; leave records
  /// (`onLeave` / `onLeaveRequested`) are managed via the leave flow and
  /// clearing one throws `ServerException` with `INVALID_STATE`. Throws
  /// `ServerException` with `ATTENDANCE_NOT_FOUND` when no record exists.
  ///
  /// Same window gates as marking: super-admins bypass the edit window but
  /// not the open window. Enrollment eligibility is not checked, so a
  /// wrongly-added record can always be cleared.
  Future<void> clearAttendance(
    int eventId,
    String username,
    DateTime occurrenceTimeUtc,
  );

  /// Gets attendance records for an occurrence.
  Future<List<AttendanceRecord>> getAttendanceForOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // LEAVE APPROVAL (ORGANIZER)
  // ══════════════════════════════════════════════════════════════════════════

  /// Approves a leave request.
  Future<void> approveLeave(
    int eventId,
    String username,
    DateTime occurrenceTimeUtc,
  );

  /// Approves multiple leave requests atomically.
  Future<void> approveLeaveBulk(
    int eventId,
    List<String> usernames,
    DateTime occurrenceTimeUtc,
  );

  /// Rejects a leave request.
  Future<void> rejectLeave(
    int eventId,
    String username,
    DateTime occurrenceTimeUtc, {
    String? reason,
  });

  /// Lists attendance across every event in a time window.
  ///
  /// Both bounds are required by the server.
  Future<List<AttendanceRecord>> listAttendanceInRange({
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
  });

  /// Rejects multiple leave requests atomically.
  Future<void> rejectLeaveBulk(
    int eventId,
    List<String> usernames,
    DateTime occurrenceTimeUtc, {
    String? reason,
  });
}
