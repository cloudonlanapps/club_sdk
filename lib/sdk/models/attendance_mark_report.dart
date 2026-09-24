import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'marked_attendance.dart';
import 'refused_attendance.dart';

/// The answer to a bulk attendance mark (#14).
///
/// Members are settled independently: those who can be recorded are in
/// [marked], those the server declined are in [refused] with a reason.
/// One member's lapsed credit never stops another's attendance being
/// recorded, so a call succeeds even when some members were refused.
/// Where the credit system is off, [refused] is always empty.
@immutable
class AttendanceMarkReport {
  const AttendanceMarkReport({
    this.marked = const [],
    this.refused = const [],
  });

  factory AttendanceMarkReport.fromMap(Map<String, dynamic> map) {
    return AttendanceMarkReport(
      marked: (map['marked'] as List<dynamic>? ?? const [])
          .map((e) => MarkedAttendance.fromMap(e as Map<String, dynamic>))
          .toList(),
      refused: (map['refused'] as List<dynamic>? ?? const [])
          .map((e) => RefusedAttendance.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory AttendanceMarkReport.fromJson(String source) =>
      AttendanceMarkReport.fromMap(json.decode(source) as Map<String, dynamic>);

  final List<MarkedAttendance> marked;
  final List<RefusedAttendance> refused;

  /// Every requested member was recorded.
  bool get allMarked => refused.isEmpty;

  AttendanceMarkReport copyWith({
    List<MarkedAttendance>? marked,
    List<RefusedAttendance>? refused,
  }) {
    return AttendanceMarkReport(
      marked: marked ?? this.marked,
      refused: refused ?? this.refused,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'marked': marked.map((e) => e.toMap()).toList(),
      'refused': refused.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'AttendanceMarkReport(marked: $marked, refused: $refused)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    const eq = ListEquality<Object>();
    return other is AttendanceMarkReport &&
        eq.equals(other.marked, marked) &&
        eq.equals(other.refused, refused);
  }

  @override
  int get hashCode {
    const eq = ListEquality<Object>();
    return Object.hash(eq.hash(marked), eq.hash(refused));
  }
}
