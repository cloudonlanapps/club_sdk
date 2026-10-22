import '../models/enums.dart';
import '../models/occurrence.dart';

/// Interface for occurrence management operations (admin/coach only).
///
/// Handles individual occurrences within event series, including
/// reschedules, cancellations, and queries.
///
/// Every change takes the occurrence's `version` (`Occurrence.version`, the
/// value the caller last loaded; club_server#430). An occurrence has its own
/// version, separate from the event's, and changing it does not bump the
/// event's. A version the occurrence has moved past is refused with
/// `StaleVersionException`, carrying who changed it and when; nothing is
/// written.
abstract interface class OccurrenceSource {
  /// Gets a specific occurrence.
  ///
  /// This is the generic view. For a member's own enrollment and attendance
  /// status, use `myEvents` — the per-member occurrence route.
  Future<Occurrence> getOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc,
  );

  /// Lists occurrences for a date range (admin/coach only).
  Future<List<Occurrence>> listOccurrences({
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
    EventType? eventType,
    Visibility? visibility,
    int? limit,
    int? offset,
  });

  /// Reschedules or modifies a specific occurrence.
  ///
  /// A camp day is described by when it starts ([newStartTimeUtc]) and how
  /// long it lasts ([newDurationMinutes], 1–1440); the server derives the new
  /// end from start + duration. At least one of [newStartTimeUtc],
  /// [newDurationMinutes], [newVenueId] must be set, else the server returns
  /// 422 `NOTHING_TO_RESCHEDULE`.
  ///
  /// For camps a supplied [newStartTimeUtc] must be in the future (400
  /// `PAST_RESCHEDULE_TIME`) and the original occurrence must be at least 30
  /// minutes away (400 `RESCHEDULE_LEAD_TIME_VIOLATED`); a super admin
  /// bypasses both. [newVenueId] must reference a live venue (404
  /// `VENUE_NOT_FOUND`), and a cancelled occurrence cannot be rescheduled (422
  /// `CANCELLED_OCCURRENCE`).
  ///
  /// The venue, organizer and coach gates run on the moved occurrence
  /// (club_server#72, #56). A clash throws `ScheduleConflictException`,
  /// whose `report` names every clashing event, and nothing moves; send the
  /// same call with [acceptConflicts] `true` to move it anyway (the server
  /// then notifies the admins).
  Future<void> rescheduleOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    required int version,
    DateTime? newStartTimeUtc,
    int? newDurationMinutes,
    int? newVenueId,
    bool acceptConflicts,
  });

  /// Cancels one occurrence of a **camp** or **programme**
  /// (`POST …/occurrences/{t}/cancel`).
  ///
  /// A one-off is not cancelled per occurrence: it is called off with
  /// `EventSource.drop`, and this call refuses it with 422 `INVALID_STATE`
  /// (`ServerException` with `SdkErrorCode.invalidState`), naming `/drop`
  /// (club_server#48, #28).
  Future<void> cancelOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    required int version,
    required String reason,
  });

  /// Restores a cancelled occurrence of a **camp** or **programme**
  /// (`POST …/occurrences/{t}/undo-cancel`).
  ///
  /// A dropped one-off is brought back with `EventSource.reinstate`, which
  /// applies the one-off's own rules; this call refuses a one-off with 422
  /// `INVALID_STATE`, naming `/reinstate` (club_server#48, #28).
  Future<void> undoCancelOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    required int version,
  });
}
