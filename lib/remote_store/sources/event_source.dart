import '../../sdk/interfaces/event.dart';
import '../../sdk/models/conflict_report.dart';
import '../../sdk/models/eligible_user.dart';
import '../../sdk/models/enums.dart';
import '../../sdk/models/event.dart';
import '../../sdk/models/event_schedule.dart';
import '../../sdk/models/event_session.dart';
import '../../sdk/models/gender.dart';
import '../../sdk/models/pagination.dart';
import '../../sdk/models/user_conflict_report.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [EventSource] using HTTP API.
class RemoteEventSource implements EventSource {
  RemoteEventSource(this._store);

  final RemoteStore _store;

  @override
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
  }) async {
    final response = await _store.post(
      endpoints.events.checkConflict,
      body: {
        'type': type.name,
        'venueId': venueId,
        'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
        'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
        'rrule': ?rrule,
        if (untilTimeUtc != null)
          'untilTimeUtc': untilTimeUtc.millisecondsSinceEpoch,
        'organizerName': ?organizerName,
        'coachNames': ?coachNames,
        'excludeEventId': ?excludeEventId,
      },
    );
    return ConflictReport.fromMap(response);
  }

  @override
  Future<UserConflictReport> checkUserConflicts(
    int eventId, {
    required List<String> usernames,
  }) async {
    final response = await _store.post(
      endpoints.events.checkUserConflicts(eventId),
      body: {'usernames': usernames},
    );
    return UserConflictReport.fromMap(response);
  }

  @override
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
    bool isFeatured = false,
    List<String>? galleryUris,
    String? shortDescription,
    String? stamp,
    List<String>? highlights,
    List<String>? includes,
    List<EventSession>? sessions,
  }) async {
    final response = await _store.post(
      endpoints.events.list,
      body: {
        'title': title,
        'description': description,
        'type': type.name,
        'visibility': visibility.name,
        'venueId': venueId,
        'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
        'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
        'organizerName': ?organizerName,
        'coachNames': ?coachNames,
        'rrule': ?rrule,
        if (gender != null) 'gender': gender.serverValue,
        if (dobOnOrAfterUtc != null)
          'dobOnOrAfterUtc': dobOnOrAfterUtc.millisecondsSinceEpoch,
        if (dobOnOrBeforeUtc != null)
          'dobOnOrBeforeUtc': dobOnOrBeforeUtc.millisecondsSinceEpoch,
        'isFeatured': isFeatured,
        'galleryUris': ?galleryUris,
        'shortDescription': ?shortDescription,
        'stamp': ?stamp,
        'highlights': ?highlights,
        'includes': ?includes,
        if (sessions != null)
          'sessions': sessions.map((s) => s.toMap()).toList(),
      },
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> getEvent(int eventId) async {
    final response = await _store.get(endpoints.events.event(eventId));
    return Event.fromMap(response);
  }

  @override
  Future<PaginatedList<Event>> listEvents({
    DateTime? fromTimeUtc,
    DateTime? toTimeUtc,
    int? venueId,
    EventType? eventType,
    Visibility? visibility,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{
      if (fromTimeUtc != null)
        'fromTimeUtc': fromTimeUtc.millisecondsSinceEpoch.toString(),
      if (toTimeUtc != null)
        'toTimeUtc': toTimeUtc.millisecondsSinceEpoch.toString(),
      if (venueId != null) 'venueId': venueId.toString(),
      if (eventType != null) 'type': eventType.name,
      if (visibility != null) 'visibility': visibility.name,
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    };
    final response = await _store.get(
      endpoints.events.list,
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, Event.fromMap);
  }

  @override
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
  }) async {
    // Metadata-only (#232, #248): the server's EventUpdate is `extra="forbid"`,
    // so schedule/identity fields (startTimeUtc/endTimeUtc/rrule/venueId/type)
    // and `sessions` must never appear here — they go through rescheduleEvent /
    // the /future split. Sending any of them returns 422.
    final body = <String, dynamic>{
      'version': version,
      'title': ?title,
      'description': ?description,
      if (visibility != null) 'visibility': visibility.name,
      'organizerName': ?organizerName,
      if (coachNames != null) 'coachNames': coachNames(),
      if (gender != null) 'gender': gender()?.serverValue,
      if (dobOnOrAfterUtc != null)
        'dobOnOrAfterUtc': dobOnOrAfterUtc()?.millisecondsSinceEpoch,
      if (dobOnOrBeforeUtc != null)
        'dobOnOrBeforeUtc': dobOnOrBeforeUtc()?.millisecondsSinceEpoch,
      'isFeatured': ?isFeatured,
      if (galleryUris != null) 'galleryUris': galleryUris(),
      if (shortDescription != null) 'shortDescription': shortDescription(),
      if (stamp != null) 'stamp': stamp(),
      if (highlights != null) 'highlights': highlights(),
      if (includes != null) 'includes': includes(),
    };
    final response = await _store.patch(
      endpoints.events.event(eventId),
      body: body,
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> rescheduleEvent(
    int eventId, {
    DateTime? startTimeUtc,
    DateTime? endTimeUtc,
    String? rrule,
    int? venueId,
    List<EventSession>? Function()? sessions,
    bool resetOverrides = false,
  }) async {
    // `sessions` is part of the schedule (#248): provide the getter to replace
    // the per-occurrence timetable atomically with the window change — it is
    // validated against the new window. A getter returning `null` sends an
    // explicit `sessions: null`, which clears the timetable; omitting the
    // getter leaves the stored timetable untouched (re-validated against the
    // new window).
    final body = <String, dynamic>{
      if (startTimeUtc != null)
        'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
      if (endTimeUtc != null) 'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
      'rrule': ?rrule,
      'venueId': ?venueId,
      if (sessions != null)
        'sessions': sessions()?.map((s) => s.toMap()).toList(),
      'resetOverrides': resetOverrides,
    };
    final response = await _store.post(
      endpoints.events.reschedule(eventId),
      body: body,
    );
    return Event.fromMap(response);
  }

  @override
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
  }) async {
    final body = <String, dynamic>{
      'version': version,
      'title': ?title,
      'description': ?description,
      if (visibility != null) 'visibility': visibility.name,
      if (gender != null) 'gender': gender()?.serverValue,
      if (dobOnOrAfterUtc != null)
        'dobOnOrAfterUtc': dobOnOrAfterUtc()?.millisecondsSinceEpoch,
      if (dobOnOrBeforeUtc != null)
        'dobOnOrBeforeUtc': dobOnOrBeforeUtc()?.millisecondsSinceEpoch,
      'isFeatured': ?isFeatured,
      if (galleryUris != null) 'galleryUris': galleryUris(),
      if (shortDescription != null) 'shortDescription': shortDescription(),
      if (stamp != null) 'stamp': stamp(),
      if (highlights != null) 'highlights': highlights(),
      if (includes != null) 'includes': includes(),
    };
    final response = await _store.patch(
      endpoints.events.correction(eventId),
      body: body,
    );
    return Event.fromMap(response);
  }

  @override
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
  }) async {
    final body = <String, dynamic>{
      'version': version,
      'effectiveDateTimeUtc': effectiveDateTimeUtc.millisecondsSinceEpoch,
      'venueId': ?venueId,
      'organizerName': ?organizerName,
      if (coachNames != null) 'coachNames': coachNames(),
      if (startTimeUtc != null)
        'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
      if (endTimeUtc != null) 'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
      'rrule': ?rrule,
      if (sessions != null)
        'sessions': sessions()?.map((s) => s.toMap()).toList(),
    };
    final response = await _store.patch(
      endpoints.events.future(eventId),
      body: body,
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> cancelSeries(
    int eventId, {
    required String reason,
    required DateTime effectiveDateTimeUtc,
  }) async {
    final response = await _store.post(
      endpoints.events.cancel(eventId),
      body: {
        'reason': reason,
        'effectiveDateTimeUtc': effectiveDateTimeUtc.millisecondsSinceEpoch,
      },
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> undoCancelSeries(int eventId) async {
    final response = await _store.post(endpoints.events.undoCancel(eventId));
    return Event.fromMap(response);
  }

  @override
  Future<Event> terminate(
    int eventId, {
    required String reason,
    required DateTime cutoffTimeUtc,
  }) async {
    final response = await _store.post(
      endpoints.events.terminate(eventId),
      body: {
        'reason': reason,
        'cutoffTimeUtc': cutoffTimeUtc.millisecondsSinceEpoch,
      },
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> extend(
    int eventId, {
    required DateTime cutoffTimeUtc,
    String? reason,
  }) async {
    final response = await _store.post(
      endpoints.events.extend(eventId),
      body: {
        'cutoffTimeUtc': cutoffTimeUtc.millisecondsSinceEpoch,
        'reason': ?reason,
      },
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> extendIndefinitely(int eventId, {String? reason}) async {
    final response = await _store.post(
      endpoints.events.extendIndefinitely(eventId),
      body: {'reason': ?reason},
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> drop(int eventId, {required String reason}) async {
    final response = await _store.post(
      endpoints.events.drop(eventId),
      body: {'reason': reason},
    );
    return Event.fromMap(response);
  }

  @override
  Future<Event> reinstate(int eventId) async {
    final response = await _store.post(endpoints.events.reinstate(eventId));
    return Event.fromMap(response);
  }

  @override
  Future<List<EventSchedule>> listSchedules(int eventId) async {
    final response = await _store.getList(
      endpoints.events.schedules(eventId),
    );
    return response
        .map((item) => EventSchedule.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Event>> listDeletedEvents({
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    };
    final response = await _store.getList(
      endpoints.events.deleted,
      queryParams: queryParams,
    );
    return response
        .map((item) => Event.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Event> deleteEvent(int eventId) async {
    final response = await _store.delete(endpoints.events.event(eventId));
    return Event.fromMap(response!);
  }

  @override
  Future<Event> restoreEvent(int eventId) async {
    final response = await _store.post(endpoints.events.restore(eventId));
    return Event.fromMap(response);
  }

  @override
  Future<void> hardDeleteEvent(int eventId) async {
    await _store.delete(endpoints.events.hardDelete(eventId));
  }

  @override
  Future<List<EligibleUser>> listEligible(int eventId) async {
    final response = await _store.getList(endpoints.events.eligible(eventId));
    return response
        .map((e) => EligibleUser.fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
