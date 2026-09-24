import '../models/enums.dart';
import '../models/occurrence.dart';

/// Interface for occurrence management operations (admin/coach only).
///
/// Handles individual occurrences within event series, including
/// reschedules, cancellations, and queries.
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
  Future<void> rescheduleOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    DateTime? newStartTimeUtc,
    int? newDurationMinutes,
    int? newVenueId,
  });

  /// Cancels a specific occurrence.
  Future<void> cancelOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc, {
    required String reason,
  });

  /// Restores a cancelled occurrence (undo cancel).
  Future<void> undoCancelOccurrence(int eventId, DateTime occurrenceTimeUtc);
}
