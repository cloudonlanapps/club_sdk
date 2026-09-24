import 'dart:convert';

import 'package:meta/meta.dart';

import 'enums.dart';
import 'my_attendance_record.dart';

/// Aggregated attendance statistics for a member across all enrolled events.
///
/// Computed client-side from raw [MyAttendanceRecord] list returned by
/// `GET /myevents/{username}/attendance`.
@immutable
class MyAttendanceStats {
  const MyAttendanceStats({
    required this.totalOccurrences,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
    required this.attendancePercentage,
  });

  /// Computes aggregate stats from a list of raw attendance records.
  factory MyAttendanceStats.fromRecords(List<MyAttendanceRecord> records) {
    var present = 0;
    var absent = 0;
    var late = 0;
    var leave = 0;

    for (final r in records) {
      switch (r.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.onLeave:
          leave++;
        case AttendanceStatus.onLeaveRequested:
          // Pending leave requests are not counted as confirmed leave
          break;
      }
    }

    final total = present + absent + late + leave;
    final percentage = total > 0 ? (present + late) / total * 100 : 0.0;

    return MyAttendanceStats(
      totalOccurrences: total,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      leaveCount: leave,
      attendancePercentage: percentage,
    );
  }

  factory MyAttendanceStats.fromMap(Map<String, dynamic> map) {
    return MyAttendanceStats(
      totalOccurrences: map['totalOccurrences'] as int? ?? 0,
      presentCount: map['presentCount'] as int? ?? 0,
      absentCount: map['absentCount'] as int? ?? 0,
      lateCount: map['lateCount'] as int? ?? 0,
      leaveCount: map['leaveCount'] as int? ?? 0,
      attendancePercentage:
          (map['attendancePercentage'] as num?)?.toDouble() ?? 0,
    );
  }

  factory MyAttendanceStats.fromJson(String source) =>
      MyAttendanceStats.fromMap(json.decode(source) as Map<String, dynamic>);

  final int totalOccurrences;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;
  final double attendancePercentage;

  MyAttendanceStats copyWith({
    int? totalOccurrences,
    int? presentCount,
    int? absentCount,
    int? lateCount,
    int? leaveCount,
    double? attendancePercentage,
  }) {
    return MyAttendanceStats(
      totalOccurrences: totalOccurrences ?? this.totalOccurrences,
      presentCount: presentCount ?? this.presentCount,
      absentCount: absentCount ?? this.absentCount,
      lateCount: lateCount ?? this.lateCount,
      leaveCount: leaveCount ?? this.leaveCount,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalOccurrences': totalOccurrences,
      'presentCount': presentCount,
      'absentCount': absentCount,
      'lateCount': lateCount,
      'leaveCount': leaveCount,
      'attendancePercentage': attendancePercentage,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'MyAttendanceStats(totalOccurrences: $totalOccurrences, '
        'present: $presentCount, absent: $absentCount, '
        'late: $lateCount, leave: $leaveCount, '
        'percentage: $attendancePercentage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MyAttendanceStats &&
        other.totalOccurrences == totalOccurrences &&
        other.presentCount == presentCount &&
        other.absentCount == absentCount &&
        other.lateCount == lateCount &&
        other.leaveCount == leaveCount &&
        other.attendancePercentage == attendancePercentage;
  }

  @override
  int get hashCode {
    return totalOccurrences.hashCode ^
        presentCount.hashCode ^
        absentCount.hashCode ^
        lateCount.hashCode ^
        leaveCount.hashCode ^
        attendancePercentage.hashCode;
  }
}
