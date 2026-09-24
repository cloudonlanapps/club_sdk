import 'dart:convert';

import 'package:meta/meta.dart';

import 'attendance.dart' show AttendanceRecord;
import 'enums.dart';

/// A member's attendance record returned by `/myevents/{username}/attendance`.
///
/// Unlike [AttendanceRecord], this includes `eventId` and `occurrenceTimeUtc`
/// (as DateTime) rather than internal `id`/`occurrenceId`, plus `previousStatus`
/// and `leaveReason` fields.
@immutable
class MyAttendanceRecord {
  const MyAttendanceRecord({
    required this.eventId,
    required this.occurrenceTimeUtc,
    required this.membername,
    required this.status,
    required this.recordedAtUtc,
    this.notes,
    this.previousStatus,
    this.leaveReason,
  });

  factory MyAttendanceRecord.fromMap(Map<String, dynamic> map) {
    return MyAttendanceRecord(
      eventId: map['eventId'] as int,
      occurrenceTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['occurrenceTimeUtc'] as int,
        isUtc: true,
      ),
      membername: map['membername'] as String,
      status: AttendanceStatus.values.byName(map['status'] as String),
      notes: map['notes'] as String?,
      previousStatus: map['previousStatus'] != null
          ? AttendanceStatus.values.byName(map['previousStatus'] as String)
          : null,
      leaveReason: map['leaveReason'] as String?,
      recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['recordedAtUtc'] as int,
        isUtc: true,
      ),
    );
  }

  factory MyAttendanceRecord.fromJson(String source) =>
      MyAttendanceRecord.fromMap(json.decode(source) as Map<String, dynamic>);

  final int eventId;
  final DateTime occurrenceTimeUtc;
  final String membername;
  final AttendanceStatus status;
  final String? notes;
  final AttendanceStatus? previousStatus;
  final String? leaveReason;
  final DateTime recordedAtUtc;

  MyAttendanceRecord copyWith({
    int? eventId,
    DateTime? occurrenceTimeUtc,
    String? membername,
    AttendanceStatus? status,
    String? Function()? notes,
    AttendanceStatus? Function()? previousStatus,
    String? Function()? leaveReason,
    DateTime? recordedAtUtc,
  }) {
    return MyAttendanceRecord(
      eventId: eventId ?? this.eventId,
      occurrenceTimeUtc: occurrenceTimeUtc ?? this.occurrenceTimeUtc,
      membername: membername ?? this.membername,
      status: status ?? this.status,
      notes: notes != null ? notes() : this.notes,
      previousStatus: previousStatus != null
          ? previousStatus()
          : this.previousStatus,
      leaveReason: leaveReason != null ? leaveReason() : this.leaveReason,
      recordedAtUtc: recordedAtUtc ?? this.recordedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'occurrenceTimeUtc': occurrenceTimeUtc.millisecondsSinceEpoch,
      'membername': membername,
      'status': status.name,
      'notes': notes,
      'previousStatus': previousStatus?.name,
      'leaveReason': leaveReason,
      'recordedAtUtc': recordedAtUtc.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'MyAttendanceRecord(eventId: $eventId, '
        'occurrenceTimeUtc: $occurrenceTimeUtc, '
        'membername: $membername, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MyAttendanceRecord &&
        other.eventId == eventId &&
        other.occurrenceTimeUtc == occurrenceTimeUtc &&
        other.membername == membername &&
        other.status == status &&
        other.notes == notes &&
        other.previousStatus == previousStatus &&
        other.leaveReason == leaveReason &&
        other.recordedAtUtc == recordedAtUtc;
  }

  @override
  int get hashCode {
    return eventId.hashCode ^
        occurrenceTimeUtc.hashCode ^
        membername.hashCode ^
        status.hashCode ^
        notes.hashCode ^
        previousStatus.hashCode ^
        leaveReason.hashCode ^
        recordedAtUtc.hashCode;
  }
}
