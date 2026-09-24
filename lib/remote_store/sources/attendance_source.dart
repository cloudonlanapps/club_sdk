import '../../sdk/interfaces/attendance.dart';
import '../../sdk/models/attendance.dart';
import '../../sdk/models/attendance_mark_record.dart';
import '../../sdk/models/attendance_mark_report.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [AttendanceSource] using HTTP API.
class RemoteAttendanceSource implements AttendanceSource {
  RemoteAttendanceSource(this._store);

  final RemoteStore _store;

  // ═══════════════════════════════════════════════════════════════════════════
  // ATTENDANCE MARKING
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<AttendanceMarkReport> markAttendance(
    int eventId,
    DateTime occurrenceTimeUtc,
    List<AttendanceMarkRecord> records,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch;
    final response = await _store.post(
      endpoints.attendance.attendance(eventId, timeStr),
      body: {
        'records': records.map((r) => r.toMap()).toList(),
      },
    );
    return AttendanceMarkReport.fromMap(response);
  }

  @override
  Future<void> clearAttendance(
    int eventId,
    String username,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch;
    await _store.delete(
      endpoints.attendance.clearAttendance(eventId, timeStr, username),
    );
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceForOccurrence(
    int eventId,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch;
    final response = await _store.getList(
      endpoints.attendance.attendance(eventId, timeStr),
    );
    return response
        .map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEAVE APPROVAL (ORGANIZER)
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> approveLeave(
    int eventId,
    String username,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch;
    await _store.postVoid(
      endpoints.attendance.approveLeave(eventId, timeStr),
      body: {
        'membernames': [username],
      },
    );
  }

  @override
  Future<void> approveLeaveBulk(
    int eventId,
    List<String> usernames,
    DateTime occurrenceTimeUtc,
  ) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch;
    await _store.postVoid(
      endpoints.attendance.approveLeave(eventId, timeStr),
      body: {
        'membernames': usernames,
      },
    );
  }

  @override
  Future<void> rejectLeave(
    int eventId,
    String username,
    DateTime occurrenceTimeUtc, {
    String? reason,
  }) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch;
    await _store.postVoid(
      endpoints.attendance.rejectLeave(eventId, timeStr),
      body: {
        'membernames': [username],
        'reason': ?reason,
      },
    );
  }

  @override
  Future<void> rejectLeaveBulk(
    int eventId,
    List<String> usernames,
    DateTime occurrenceTimeUtc, {
    String? reason,
  }) async {
    final timeStr = occurrenceTimeUtc.millisecondsSinceEpoch;
    await _store.postVoid(
      endpoints.attendance.rejectLeave(eventId, timeStr),
      body: {
        'membernames': usernames,
        'reason': ?reason,
      },
    );
  }

  @override
  Future<List<AttendanceRecord>> listAttendanceInRange({
    required DateTime fromTimeUtc,
    required DateTime toTimeUtc,
  }) async {
    final response = await _store.getList(
      endpoints.attendance.occurrencesReport,
      queryParams: {
        'fromTimeUtc': fromTimeUtc.millisecondsSinceEpoch.toString(),
        'toTimeUtc': toTimeUtc.millisecondsSinceEpoch.toString(),
      },
    );
    return response
        .map((item) => AttendanceRecord.fromMap(item as Map<String, dynamic>))
        .toList();
  }
}
