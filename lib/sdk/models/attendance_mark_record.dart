import 'dart:convert';

import 'package:meta/meta.dart';

import 'enums.dart';

/// A single attendance record for batch marking via the attendance endpoint.
///
/// Used with `AttendanceSource.markAttendance` which accepts a list of records.
@immutable
class AttendanceMarkRecord {
  const AttendanceMarkRecord({
    required this.membername,
    required this.status,
    this.notes,
  });

  factory AttendanceMarkRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceMarkRecord(
      membername: map['membername'] as String,
      status: AttendanceStatus.values.byName(map['status'] as String),
      notes: map['notes'] as String?,
    );
  }

  factory AttendanceMarkRecord.fromJson(String source) =>
      AttendanceMarkRecord.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  final String membername;
  final AttendanceStatus status;
  final String? notes;

  AttendanceMarkRecord copyWith({
    String? membername,
    AttendanceStatus? status,
    String? Function()? notes,
  }) {
    return AttendanceMarkRecord(
      membername: membername ?? this.membername,
      status: status ?? this.status,
      notes: notes != null ? notes() : this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'membername': membername,
      'status': status.name,
      if (notes != null) 'notes': notes,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'AttendanceMarkRecord(membername: $membername, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AttendanceMarkRecord &&
        other.membername == membername &&
        other.status == status &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return membername.hashCode ^ status.hashCode ^ notes.hashCode;
  }
}
