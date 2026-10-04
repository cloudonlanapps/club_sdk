import '../../sdk/interfaces/my_events.dart';
import '../../sdk/models/attendance.dart';
import '../../sdk/models/enrollment.dart';
import '../../sdk/models/event.dart';
import '../../sdk/models/event_schedule.dart';
import '../../sdk/models/my_attendance_record.dart';
import '../../sdk/models/occurrence.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [MyEventsSource] using HTTP API.
class RemoteMyEventsSource implements MyEventsSource {
  RemoteMyEventsSource(this._store);

  final RemoteStore _store;

  // ═══════════════════════════════════════════════════════════════════════════
  // EVENT QUERIES
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<PaginatedList<Event>> listMyEvents(
    String username, {
    DateTime? fromTimeUtc,
    DateTime? toTimeUtc,
    int? offset,
    int? limit,
  }) async {
    final queryParams = <String, String>{
      if (fromTimeUtc != null)
        'fromTimeUtc': fromTimeUtc.millisecondsSinceEpoch.toString(),
      if (toTimeUtc != null)
        'toTimeUtc': toTimeUtc.millisecondsSinceEpoch.toString(),
      if (offset != null) 'offset': offset.toString(),
      if (limit != null) 'limit': limit.toString(),
    };
    final response = await _store.get(
      endpoints.myEvents.list(username),
      queryParams: queryParams,
    );
    return PaginatedList.fromMap(response, Event.fromMap);
  }

  @override
  Future<Event> getMyEvent(String username, int eventId) async {
    final response = await _store.get(
      endpoints.myEvents.event(username, eventId),
    );
    return Event.fromMap(response);
  }

  @override
  Future<List<EventSchedule>> listMyEventSchedules(
    String username,
    int eventId,
  ) async {
    final response = await _store.getList(
      endpoints.myEvents.schedules(username, eventId),
    );
    return response
        .map((item) => EventSchedule.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ENROLLMENT
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<Enrollment> getMyEnrollment(String username, int eventId) async {
    final response = await _store.get(
      endpoints.myEvents.enrollment(username, eventId),
    );
    return Enrollment.fromMap(response);
  }

  @override
  Future<void> acceptInvite(String username, int eventId) async {
    await _store.postVoid(endpoints.myEvents.acceptInvite(username, eventId));
  }

  @override
  Future<void> declineInvite(String username, int eventId) async {
    await _store.postVoid(endpoints.myEvents.declineInvite(username, eventId));
  }

  @override
  Future<void> requestToJoin(String username, int eventId) async {
    await _store.postVoid(endpoints.myEvents.requestToJoin(username, eventId));
  }

  @override
  Future<void> withdraw(
    String username,
    int eventId, {
    String? reason,
  }) async {
    await _store.postVoid(
      endpoints.myEvents.withdraw(username, eventId),
      body: {
        'reason': ?reason,
      },
    );
  }

  @override
  Future<void> cancelWithdrawRequest(String username, int eventId) async {
    await _store.postVoid(
      endpoints.myEvents.cancelWithdraw(username, eventId),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OCCURRENCE QUERIES
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<List<Occurrence>> listMyOccurrences(
    String username, {
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
  }) async {
    final queryParams = <String, String>{
      'fromTimeUtc': fromTimeUtc.millisecondsSinceEpoch.toString(),
      'toTimeUtc': toTimeUtc.millisecondsSinceEpoch.toString(),
    };
    final response = await _store.getList(
      endpoints.myEvents.occurrences(username),
      queryParams: queryParams,
    );
    return response
        .map((item) => Occurrence.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Occurrence> getMyOccurrence(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    final response = await _store.get(
      endpoints.myEvents.occurrence(username, eventId, timeStr),
    );
    return Occurrence.fromMap(response);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<AttendanceRecord?> getMyOccurrenceAttendance(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    // With no record the server answers 200 `null` (#43).
    final response = await _store.getOrNull(
      endpoints.myEvents.occurrenceAttendance(username, eventId, timeStr),
    );
    if (response == null || response.isEmpty) return null;
    return AttendanceRecord.fromMap(response);
  }

  @override
  Future<List<MyAttendanceRecord>> listMyAttendance(
    String username, {
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
  }) async {
    final queryParams = <String, String>{
      'fromTimeUtc': fromTimeUtc.millisecondsSinceEpoch.toString(),
      'toTimeUtc': toTimeUtc.millisecondsSinceEpoch.toString(),
    };
    final response = await _store.getList(
      endpoints.myEvents.attendance(username),
      queryParams: queryParams,
    );
    return response
        .map((item) => MyAttendanceRecord.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEAVE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> requestLeave(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc, {
    String? reason,
  }) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    await _store.postVoid(
      endpoints.myEvents.requestLeave(username, eventId, timeStr),
      body: {
        'reason': ?reason,
      },
    );
  }

  @override
  Future<void> cancelLeaveRequest(
    String username,
    int eventId,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch.toString();
    await _store.postVoid(
      endpoints.myEvents.cancelLeave(username, eventId, timeStr),
    );
  }
}
