import 'dart:convert';

import 'package:meta/meta.dart';

/// One entry in an event's per-occurrence timetable.
///
/// `periodMinutes` is the duration of this slot. The ordered list of
/// sessions describes the timetable inside each occurrence's
/// `startTime`–`endTime` window; the sum of all periods must equal that
/// window in minutes. Server enforces this and rejects mismatches with
/// `INVALID_SESSIONS_TOTAL`; an empty list is rejected with
/// `INVALID_SESSIONS_EMPTY`.
@immutable
class EventSession {
  const EventSession({required this.name, required this.periodMinutes});

  factory EventSession.fromMap(Map<String, dynamic> map) {
    return EventSession(
      name: map['name'] as String,
      periodMinutes: map['periodMinutes'] as int,
    );
  }

  factory EventSession.fromJson(String source) =>
      EventSession.fromMap(json.decode(source) as Map<String, dynamic>);

  final String name;
  final int periodMinutes;

  EventSession copyWith({String? name, int? periodMinutes}) {
    return EventSession(
      name: name ?? this.name,
      periodMinutes: periodMinutes ?? this.periodMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'periodMinutes': periodMinutes};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EventSession(name: $name, periodMinutes: $periodMinutes)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventSession &&
        other.name == name &&
        other.periodMinutes == periodMinutes;
  }

  @override
  int get hashCode => name.hashCode ^ periodMinutes.hashCode;
}
