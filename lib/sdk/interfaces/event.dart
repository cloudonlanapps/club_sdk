import '../models/conflict_report.dart';
import '../models/eligible_user.dart';
import '../models/enums.dart';
import '../models/event.dart';
import '../models/event_schedule.dart';
import '../models/event_session.dart';
import '../models/gender.dart';
import '../models/pagination.dart';
import '../models/user_conflict_report.dart';

/// Unified interface for event management operations (admin/coach only).
///
/// Combines functionality from V1's EventsOrganizer and EventsAttendee
/// for complete event lifecycle management.
abstract interface class EventSource {
  // ══════════════════════════════════════════════════════════════════════════
  // CONFLICT DETECTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Probes a schedule of any type for venue / organizer / coach conflicts
  /// WITHOUT creating it (#16). Only a programme-against-programme clash
  /// blocks creation (409); everything else is reported here.
  ///
  /// [excludeEventId] lets an in-place edit exclude its own occurrences.
  /// User-level conflicts are NOT included here — see the dedicated
  /// `POST /events/by_id/{id}/check-user-conflicts` endpoint.
  Future<ConflictReport> checkConflict({
    required EventType type,
    required int venueId,
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
    String? rrule,
    DateTime? untilTimeUtc,
    String? organizerName,
    List<String>? coachNames,
    int? excludeEventId,
  });

  /// Probes per-user enrollment conflicts against a stored event of any
  /// type (admin / coach only, #16). The server resolves the event's
  /// schedule from [eventId] and reports any overlapping occurrences each
  /// listed user is enrolled in.
  Future<UserConflictReport> checkUserConflicts(
    int eventId, {
    required List<String> usernames,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // EVENT CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a new event (one-off, programme, or camp).
  ///
  /// [shortDescription], [stamp], [highlights] and [includes] are the basic
  /// marketing block (club_server#409, #22), each optional.
  Future<Event> createEvent({
    required String title,
    required String description,
    required EventType type,
    required Visibility visibility,
    required int venueId,
    required DateTime startTimeUtc,
    required DateTime endTimeUtc,
    String? organizerName,
    List<String>? coachNames,
    String? rrule,
    Gender? gender,
    DateTime? dobOnOrAfterUtc,
    DateTime? dobOnOrBeforeUtc,
    bool isFeatured,
    List<String>? galleryUris,
    String? shortDescription,
    String? stamp,
    List<String>? highlights,
    List<String>? includes,
    List<EventSession>? sessions,
  });

  /// Gets a single event by ID.
  Future<Event> getEvent(int eventId);

  /// Lists events (admin/coach only).
  ///
  /// Use [fromTimeUtc] and [toTimeUtc] for time range filtering.
  /// Use [venueId] to filter by venue.
  Future<PaginatedList<Event>> listEvents({
    DateTime? fromTimeUtc,
    DateTime? toTimeUtc,
    int? venueId,
    EventType? eventType,
    Visibility? visibility,
    int? limit,
    int? offset,
  });

  /// Updates an event's **metadata** via PATCH /events/{eventId}.
  ///
  /// [version] is the event version the caller last loaded (#25); the
  /// server answers 409 `StaleVersionException` when it is no longer
  /// current, and 422 when it is missing.
  ///
  /// Applies to every event type. Schedule and identity fields
  /// (`startTimeUtc`, `endTimeUtc`, `rrule`, `venueId`, `type`) are not
  /// accepted here — the server rejects them (and any unknown field) with
  /// 422. Move the schedule via [rescheduleEvent] (camp / one-off) or
  /// [updateEventForAllFuture] (programme), and set the type via
  /// [createEvent].
  ///
  /// [sessions] **corrects** a camp's or one-off's timetable in place, at any
  /// time — including after it has started — since a correction moves
  /// nothing (club_server#423, #3). The periods must sum to the occurrence
  /// length (422 `INVALID_SESSIONS_TOTAL`). A getter returning `null` clears
  /// the timetable; an omitted getter leaves it alone. To *change* the
  /// timetable along with the window, use [rescheduleEvent] before the event
  /// starts. A programme's timetable is corrected through
  /// [correctionOnEvent].
  ///
  /// The basic marketing block ([shortDescription], [stamp], [highlights],
  /// [includes]) takes getters: one returning `null` clears the field, an
  /// omitted getter leaves it alone (club_server#409, #22).
  ///
  /// [coachNames] takes a getter: one returning `null` (or an empty list)
  /// clears the coaches, an omitted getter leaves them alone (#48).
  /// [organizerName] cannot be cleared, since every event has an organizer:
  /// `null` leaves it unchanged.
  Future<Event> updateEvent(
    int eventId, {
    required int version,
    String? title,
    String? description,
    Visibility? visibility,
    String? organizerName,
    List<String>? Function()? coachNames,
    Gender? Function()? gender,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    bool? isFeatured,
    List<String>? Function()? galleryUris,
    String? Function()? shortDescription,
    String? Function()? stamp,
    List<String>? Function()? highlights,
    List<String>? Function()? includes,
    List<EventSession>? Function()? sessions,
  });

  /// Moves a camp or one-off event's schedule in place via
  /// POST /events/{eventId}/reschedule.
  ///
  /// At least one of [startTimeUtc], [endTimeUtc], [rrule], [venueId],
  /// [sessions] must be supplied, else the server returns 422
  /// `NOTHING_TO_RESCHEDULE`. Moving only [startTimeUtc] preserves each
  /// session's duration. [rrule] is rejected for one-off events with 422
  /// `INVALID_STATE`; programmes are rejected with 400
  /// `EVENT_TYPE_NOT_SUPPORTED` (use [updateEventForAllFuture]).
  ///
  /// [sessions] is part of the schedule (#248): pass the getter to replace the
  /// per-occurrence timetable atomically with the rest of the change — it is
  /// validated against the new window (422 `INVALID_SESSIONS_TOTAL` when the
  /// supplied split doesn't sum to it). A getter returning `null` clears the
  /// timetable; omitting the getter leaves it untouched (re-validated against
  /// the new window).
  ///
  /// Allowed only before the event starts — returns 422 `EVENT_ALREADY_STARTED`
  /// once the first occurrence is past or any attendance exists. Returns 409
  /// `OCCURRENCE_OVERRIDES_PRESENT` (with the offending `occurrenceTimeUtcs` in
  /// `ServerException.details`) when occurrence overrides exist, unless
  /// [resetOverrides] is `true` to clear them.
  ///
  /// [version] is the event version the caller last loaded
  /// (club_server#434, #5), as for [updateEvent], [correctionOnEvent] and
  /// [updateEventForAllFuture]: a reschedule rewrites the timetable those
  /// edits read. A stale one is refused with `StaleVersionException` and
  /// nothing moves; a successful reschedule bumps the version.
  Future<Event> rescheduleEvent(
    int eventId, {
    required int version,
    DateTime? startTimeUtc,
    DateTime? endTimeUtc,
    String? rrule,
    int? venueId,
    List<EventSession>? Function()? sessions,
    bool resetOverrides,
  });

  /// Corrects a programme's identity, eligibility and presentation for its
  /// whole life (`PATCH …/correction`, #16): title, description,
  /// visibility, the gender / DOB eligibility window, the featured flag,
  /// gallery and the basic marketing block (getters, `null` clears; #22).
  /// Staffing (`coachNames`, `organizerName`) lives on the schedule and
  /// moves through [updateEventForAllFuture].
  ///
  /// [sessions] **corrects** one schedule's timetable in place, at any time,
  /// with no split and no cutoff (club_server#423, #3): the schedule
  /// [scheduleId] names (from [listSchedules]), or the latest one when it is
  /// omitted. The periods must sum to that schedule's occurrence length (422
  /// `INVALID_SESSIONS_TOTAL`); a getter returning `null` clears the
  /// timetable; an omitted getter leaves it alone. A [scheduleId] that is
  /// not one of this event's schedules is 404 `SCHEDULE_NOT_FOUND`, and
  /// [scheduleId] without [sessions] is 422. To *change* the timetable from
  /// a date onward, split with [updateEventForAllFuture].
  ///
  /// [version] is the event version the caller last loaded (#25); a stale
  /// one is refused with `StaleVersionException`.
  ///
  /// Throws `ServerException` with `INVALID_EVENT_TYPE` if the event
  /// is a camp or one-off (use [updateEvent]).
  Future<Event> correctionOnEvent(
    int eventId, {
    required int version,
    String? title,
    String? description,
    Visibility? visibility,
    Gender? Function()? gender,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    bool? isFeatured,
    List<String>? Function()? galleryUris,
    String? Function()? shortDescription,
    String? Function()? stamp,
    List<String>? Function()? highlights,
    List<String>? Function()? includes,
    List<EventSession>? Function()? sessions,
    int? scheduleId,
  });

  /// Splits a programme's timetable at [effectiveDateTimeUtc]
  /// (`PATCH …/future`, #16): the current schedule closes there and a new
  /// one opens carrying the supplied scheduling and staffing changes. The
  /// response is the **same event** (same id) with its new current
  /// schedule; read the history with [listSchedules].
  ///
  /// [effectiveDateTimeUtc] must be an occurrence start of the current
  /// schedule (400 `EFFECTIVE_TIME_NOT_SESSION_BOUNDARY`) at least 30
  /// minutes ahead (422 `CUTOFF_TOO_SOON`). A programme clash on the new
  /// schedule is 409. Title, description and visibility are not accepted
  /// here; they go through [correctionOnEvent].
  ///
  /// [version] is the event version the caller last loaded (#25); a stale
  /// one is refused with `StaleVersionException`.
  ///
  /// Throws `ServerException` with `INVALID_EVENT_TYPE` if the event
  /// is a camp or one-off (use [rescheduleEvent]).
  ///
  /// [coachNames] takes a getter: one returning `null` (or an empty list)
  /// clears the coaches, an omitted getter leaves them alone (#48).
  /// [organizerName] cannot be cleared, since every event has an organizer:
  /// `null` leaves it unchanged.
  Future<Event> updateEventForAllFuture(
    int eventId, {
    required int version,
    required DateTime effectiveDateTimeUtc,
    int? venueId,
    String? organizerName,
    List<String>? Function()? coachNames,
    DateTime? startTimeUtc,
    DateTime? endTimeUtc,
    String? rrule,
    List<EventSession>? Function()? sessions,
  });

  /// Cancels a **camp** from [effectiveDateTimeUtc] onward
  /// (`POST …/cancel`), setting its cutoff. The camp keeps running until
  /// then (#16).
  ///
  /// [effectiveDateTimeUtc] must equal a real occurrence start (400
  /// `EFFECTIVE_TIME_NOT_SESSION_BOUNDARY`), be in the future (400
  /// `EFFECTIVE_TIME_IN_PAST`), and be at least 30 minutes away (400
  /// `CANCELLATION_LEAD_TIME_VIOLATED`); a super admin bypasses the past /
  /// lead-time rules. A programme answers 400 `INVALID_EVENT_TYPE` (use
  /// [terminate]); a one-off answers 422 `INVALID_STATE` (use [drop]).
  /// Enrollment rows are left unchanged — derive availability from the
  /// event's `untilTimeUtc` / occurrence status, not enrollment state.
  Future<Event> cancelSeries(
    int eventId, {
    required String reason,
    required DateTime effectiveDateTimeUtc,
  });

  /// Reverses a camp cancellation via POST /events/{eventId}/undo-cancel,
  /// clearing the event's `untilTimeUtc`.
  ///
  /// Returns 400 `EVENT_NOT_CANCELLED` when the event is not currently
  /// cancelled.
  Future<Event> undoCancelSeries(int eventId);

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE VERBS BY TYPE (#16)
  // ══════════════════════════════════════════════════════════════════════════

  /// Terminates a **programme** at [cutoffTimeUtc] (`POST …/terminate`):
  /// occurrences at or after the cutoff are cancelled, the programme runs
  /// until then, and any credit bound to it is released once the cutoff
  /// has passed. 422 `CUTOFF_TOO_SOON` when less than 30 minutes ahead;
  /// 400 `INVALID_EVENT_TYPE` for a camp or one-off.
  Future<Event> terminate(
    int eventId, {
    required String reason,
    required DateTime cutoffTimeUtc,
  });

  /// Moves a terminated **programme**'s cutoff to [cutoffTimeUtc]
  /// (`POST …/extend`), later or earlier. 400 `INVALID_EVENT_TYPE` for a
  /// camp or one-off.
  Future<Event> extend(
    int eventId, {
    required DateTime cutoffTimeUtc,
    String? reason,
  });

  /// Clears a terminated **programme**'s cutoff
  /// (`POST …/extend-indefinitely`), so it runs open-ended again.
  Future<Event> extendIndefinitely(int eventId, {String? reason});

  /// Drops a **one-off** (`POST …/drop`): its single occurrence gets a
  /// cancelled override (read it back through `OccurrenceSource`; the
  /// event's `untilTimeUtc` stays null), subject to the 30-minute lead
  /// (400 `CANCELLATION_LEAD_TIME_VIOLATED`). 400 `INVALID_EVENT_TYPE` for
  /// a programme or camp; 422 `CANCELLED_OCCURRENCE` when already dropped.
  ///
  /// [version] is the version of the one-off's single **occurrence**
  /// (`OccurrenceSource.getOccurrence`), not the event's, since the drop
  /// changes the occurrence (club_server#430). A stale one is refused with
  /// `StaleVersionException`.
  Future<Event> drop(
    int eventId, {
    required int version,
    required String reason,
  });

  /// Reinstates a dropped **one-off** (`POST …/reinstate`), restoring its
  /// occurrence. 422 `INVALID_STATE` once the occasion has started.
  ///
  /// [version] is the occurrence's version, as for [drop].
  Future<Event> reinstate(int eventId, {required int version});

  /// The event's timetable as a sequence of schedules, oldest first (#16).
  /// A camp or one-off has exactly one; a programme one per split.
  Future<List<EventSchedule>> listSchedules(int eventId);

  /// Lists soft-deleted events, one page at a time, with the total (#51).
  Future<PaginatedList<Event>> listDeletedEvents({
    int offset = 0,
    int limit = 20,
  });

  /// Soft deletes an event.
  /// Only admin can delete events. Cancelled events cannot be deleted.
  ///
  /// Returns the soft-deleted event (with `deletedAtUtc` populated) as
  /// echoed by the server, so callers can update local state from the
  /// response without a follow-up fetch.
  Future<Event> deleteEvent(int eventId);

  /// Restores a soft-deleted event.
  Future<Event> restoreEvent(int eventId);

  /// Permanently deletes an event and all its data.
  /// Only super admin can perform this operation.
  Future<void> hardDeleteEvent(int eventId);

  /// Users who can be assigned to or invited to this event.
  ///
  /// Admin/coach only. Filters by the event's structured eligibility
  /// (gender + DOB window) and excludes users already enrolled.
  Future<List<EligibleUser>> listEligible(int eventId);
}
