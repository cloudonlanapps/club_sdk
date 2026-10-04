import 'dart:convert';

import 'package:meta/meta.dart';

import 'enums.dart';

/// One member a bulk attendance mark recorded (#14).
@immutable
class MarkedAttendance {
  const MarkedAttendance({required this.membername, required this.status});

  factory MarkedAttendance.fromMap(Map<String, dynamic> map) {
    return MarkedAttendance(
      membername: map['membername'] as String,
      status: AttendanceStatus.values.byName(map['status'] as String),
    );
  }

  factory MarkedAttendance.fromJson(String source) =>
      MarkedAttendance.fromMap(json.decode(source) as Map<String, dynamic>);

  final String membername;
  final AttendanceStatus status;

  MarkedAttendance copyWith({String? membername, AttendanceStatus? status}) {
    return MarkedAttendance(
      membername: membername ?? this.membername,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {'membername': membername, 'status': status.name};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'MarkedAttendance(membername: $membername, status: $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarkedAttendance &&
        other.membername == membername &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(membername, status);
}
