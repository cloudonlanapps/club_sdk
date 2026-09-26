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
/// A member whose mark spent the last of their trial credit is also in
/// [trialEnded]: their trial is over and they have left the programme.
/// Where the credit system is off, [refused] and [trialEnded] are always
/// empty.
@immutable
class AttendanceMarkReport {
  const AttendanceMarkReport({
    this.marked = const [],
    this.refused = const [],
    this.trialEnded = const [],
  });

  factory AttendanceMarkReport.fromMap(Map<String, dynamic> map) {
    return AttendanceMarkReport(
      marked: (map['marked'] as List<dynamic>? ?? const [])
          .map((e) => MarkedAttendance.fromMap(e as Map<String, dynamic>))
          .toList(),
      refused: (map['refused'] as List<dynamic>? ?? const [])
          .map((e) => RefusedAttendance.fromMap(e as Map<String, dynamic>))
          .toList(),
      trialEnded: (map['trialEnded'] as List<dynamic>? ?? const [])
          .map((e) => (e as Map<String, dynamic>)['membername'] as String)
          .toList(),
    );
  }

  factory AttendanceMarkReport.fromJson(String source) =>
      AttendanceMarkReport.fromMap(json.decode(source) as Map<String, dynamic>);

  final List<MarkedAttendance> marked;
  final List<RefusedAttendance> refused;

  /// Membernames whose trial this mark ended (trial credit used up, so
  /// the server removed them from the programme). Each is also in
  /// [marked]. Empty from a server that predates it.
  final List<String> trialEnded;

  /// Every requested member was recorded.
  bool get allMarked => refused.isEmpty;

  AttendanceMarkReport copyWith({
    List<MarkedAttendance>? marked,
    List<RefusedAttendance>? refused,
    List<String>? trialEnded,
  }) {
    return AttendanceMarkReport(
      marked: marked ?? this.marked,
      refused: refused ?? this.refused,
      trialEnded: trialEnded ?? this.trialEnded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'marked': marked.map((e) => e.toMap()).toList(),
      'refused': refused.map((e) => e.toMap()).toList(),
      'trialEnded': trialEnded.map((e) => {'membername': e}).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'AttendanceMarkReport(marked: $marked, refused: $refused, '
      'trialEnded: $trialEnded)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    const eq = ListEquality<Object>();
    return other is AttendanceMarkReport &&
        eq.equals(other.marked, marked) &&
        eq.equals(other.refused, refused) &&
        eq.equals(other.trialEnded, trialEnded);
  }

  @override
  int get hashCode {
    const eq = ListEquality<Object>();
    return Object.hash(eq.hash(marked), eq.hash(refused), eq.hash(trialEnded));
  }
}
