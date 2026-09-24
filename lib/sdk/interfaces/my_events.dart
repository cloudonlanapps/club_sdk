import '../models/attendance.dart';
import '../models/enrollment.dart';
import '../models/event.dart';
import '../models/event_schedule.dart';
import '../models/my_attendance_record.dart';
import '../models/occurrence.dart';
import '../models/pagination.dart';

/// Interface for member-facing event operations via `/myevents` endpoints.
///
/// Provides access to a user's enrolled events, occurrences, enrollments,
/// attendance, and leave management. Authorization: self, admin, or coach.
abstract interface class MyEventsSource {
  // ══════════════════════════════════════════════════════════════════════════
  // EVENT QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Lists events the user is enrolled in.
  Future<PaginatedList<Event>> listMyEvents(
    String username, {
    DateTime? fromTimeUtc,
    DateTime? toTimeUtc,
    int? offset,
    int? limit,
  });

  /// Gets a single event for the user.
  Future<Event> getMyEvent(String username, int eventId);

  /// The event's timetable as a sequence of schedules (#16), for a user
  /// enrolled in it.
  Future<List<EventSchedule>> listMyEventSchedules(
    String username,
    int eventId,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // ENROLLMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Gets the user's enrollment details for an event.
  Future<Enrollment> getMyEnrollment(String username, int eventId);

  /// Accepts an invitation to an event.
  Future<void> acceptInvite(String username, int eventId);

  /// Declines an invitation to an event.
  Future<void> declineInvite(String username, int eventId);

  /// Requests to join a public event.
  Future<void> requestToJoin(String username, int eventId);

  /// Requests withdrawal from an event.
  Future<void> withdraw(
    String username,
    int eventId, {
    String? reason,
  });

  /// Cancels a pending withdrawal request.
  Future<void> cancelWithdrawRequest(String username, int eventId);

  // ══════════════════════════════════════════════════════════════════════════
  // OCCURRENCE QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Lists the user's occurrence schedule within a date range.
  Future<List<Occurrence>> listMyOccurrences(
    String username, {
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
  });

  /// Gets a specific occurrence for the user.
  Future<Occurrence> getMyOccurrence(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE
  // ══════════════════════════════════════════════════════════════════════════

  /// Gets the user's attendance record for a specific occurrence.
  ///
  /// Returns `null` if no attendance has been recorded.
  Future<AttendanceRecord?> getMyOccurrenceAttendance(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc,
  );

  /// Lists the user's attendance records within a date range.
  ///
  /// The server enforces a maximum range of 365 days.
  Future<List<MyAttendanceRecord>> listMyAttendance(
    String username, {
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // LEAVE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Requests leave for a specific occurrence.
  Future<void> requestLeave(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc, {
    String? reason,
  });

  /// Cancels a pending leave request.
  Future<void> cancelLeaveRequest(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc,
  );
}
