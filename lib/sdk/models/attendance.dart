import 'dart:convert';

import 'package:meta/meta.dart';

import 'enums.dart';

/// Record of a member's attendance for a specific occurrence.
///
/// Uses `membername` as FK to `users.username`. User details should be
/// queried via JOIN with the users table when needed.
@immutable
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.occurrenceId,
    required this.membername,
    required this.status,
    required this.recordedAtUtc,
    this.notes,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: (map['id'] as int?) ?? 0,
      // Server returns occurrenceTimeUtc, not occurrenceId
      occurrenceId: (map['occurrenceId'] ?? map['occurrenceTimeUtc']) as int,
      membername: map['membername'] as String,
      status: AttendanceStatus.values.byName(map['status'] as String),
      notes: map['notes'] as String?,
      recordedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['recordedAtUtc'] as int,
        isUtc: true,
      ),
    );
  }

  factory AttendanceRecord.fromJson(String source) =>
      AttendanceRecord.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final int occurrenceId;

  /// FK to users.username - the member's username.
  final String membername;
  final AttendanceStatus status;
  final String? notes;
  final DateTime recordedAtUtc;

  AttendanceRecord copyWith({
    int? id,
    int? occurrenceId,
    String? membername,
    AttendanceStatus? status,
    String? Function()? notes,
    DateTime? recordedAtUtc,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      membername: membername ?? this.membername,
      status: status ?? this.status,
      notes: notes != null ? notes() : this.notes,
      recordedAtUtc: recordedAtUtc ?? this.recordedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'occurrenceId': occurrenceId,
      'membername': membername,
      'status': status.name,
      'notes': notes,
      'recordedAtUtc': recordedAtUtc.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'AttendanceRecord(id: $id, occurrenceId: $occurrenceId, '
        'membername: $membername, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AttendanceRecord &&
        other.id == id &&
        other.occurrenceId == occurrenceId &&
        other.membername == membername &&
        other.status == status &&
        other.notes == notes &&
        other.recordedAtUtc == recordedAtUtc;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        occurrenceId.hashCode ^
        membername.hashCode ^
        status.hashCode ^
        notes.hashCode ^
        recordedAtUtc.hashCode;
  }
}

/// Aggregated attendance statistics for a member across an event series.
///
/// Uses `membername` as FK to `users.username`.
@immutable
class AttendanceStats {
  const AttendanceStats({
    required this.membername,
    required this.eventId,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.onLeaveCount,
  });

  factory AttendanceStats.fromMap(Map<String, dynamic> map) {
    return AttendanceStats(
      membername: map['membername'] as String,
      eventId: map['eventId'] as int,
      presentCount: map['presentCount'] as int? ?? 0,
      absentCount: map['absentCount'] as int? ?? 0,
      lateCount: map['lateCount'] as int? ?? 0,
      onLeaveCount: map['onLeaveCount'] as int? ?? 0,
    );
  }

  factory AttendanceStats.fromJson(String source) =>
      AttendanceStats.fromMap(json.decode(source) as Map<String, dynamic>);

  /// FK to users.username - the member's username.
  final String membername;
  final int eventId;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int onLeaveCount;

  /// Total number of occurrences with recorded attendance.
  int get totalRecorded =>
      presentCount + absentCount + lateCount + onLeaveCount;

  /// Attendance rate as a percentage (0-100).
  double get attendanceRate {
    if (totalRecorded == 0) return 0;
    return (presentCount + lateCount) / totalRecorded * 100;
  }

  AttendanceStats copyWith({
    String? membername,
    int? eventId,
    int? presentCount,
    int? absentCount,
    int? lateCount,
    int? onLeaveCount,
  }) {
    return AttendanceStats(
      membername: membername ?? this.membername,
      eventId: eventId ?? this.eventId,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      lateCount: lateCount ?? this.lateCount,
      onLeaveCount: onLeaveCount ?? this.onLeaveCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'membername': membername,
      'eventId': eventId,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'lateCount': lateCount,
      'onLeaveCount': onLeaveCount,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'AttendanceStats(membername: $membername, eventId: $eventId, '
        'present: $presentCount, absent: $absentCount, '
        'late: $lateCount, onLeave: $onLeaveCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AttendanceStats &&
        other.membername == membername &&
        other.eventId == eventId &&
        other.presentCount == presentCount &&
        other.absentCount == absentCount &&
        other.lateCount == lateCount &&
        other.onLeaveCount == onLeaveCount;
  }

  @override
  int get hashCode {
    return membername.hashCode ^
        eventId.hashCode ^
        presentCount.hashCode ^
        absentCount.hashCode ^
        lateCount.hashCode ^
        onLeaveCount.hashCode;
  }
}
