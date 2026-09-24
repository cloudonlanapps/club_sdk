import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'event_session.dart';

/// One entry in an event's timetable (club_server#384, #16).
///
/// An event keeps one id for life and carries a sequence of schedules. A
/// split closes the current schedule at the effective time and opens the
/// next; termination and extension move the current schedule's cutoff.
/// Camps and one-offs have exactly one schedule, a programme one or more.
/// [effectiveUntilUtc] is exclusive and `null` while the schedule is still
/// running; the event's `untilTimeUtc` is the current schedule's cutoff.
@immutable
class EventSchedule {
  const EventSchedule({
    required this.id,
    required this.eventId,
    required this.effectiveFromUtc,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.venueId,
    this.effectiveUntilUtc,
    this.rrule,
    this.organizerName,
    this.coachNames,
    this.sessions,
  });

  factory EventSchedule.fromMap(Map<String, dynamic> map) {
    DateTime? optional(String key) => map[key] != null
        ? DateTime.fromMillisecondsSinceEpoch(map[key] as int, isUtc: true)
        : null;
    return EventSchedule(
      id: map['id'] as int,
      eventId: map['eventId'] as int,
      effectiveFromUtc: DateTime.fromMillisecondsSinceEpoch(
        map['effectiveFromUtc'] as int,
        isUtc: true,
      ),
      effectiveUntilUtc: optional('effectiveUntilUtc'),
      startTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['startTimeUtc'] as int,
        isUtc: true,
      ),
      endTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['endTimeUtc'] as int,
        isUtc: true,
      ),
      rrule: map['rrule'] as String?,
      venueId: map['venueId'] as int,
      organizerName: map['organizerName'] as String?,
      coachNames: map['coachNames'] != null
          ? List<String>.from(map['coachNames'] as List)
          : null,
      sessions: map['sessions'] != null
          ? (map['sessions'] as List)
                .map((s) => EventSession.fromMap(s as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  factory EventSchedule.fromJson(String source) =>
      EventSchedule.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final int eventId;

  /// When this schedule takes effect (inclusive).
  final DateTime effectiveFromUtc;

  /// When this schedule stops applying (exclusive); `null` while running.
  final DateTime? effectiveUntilUtc;

  /// First occurrence window under this schedule; also fixes the time of day.
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;

  /// Programme: weekly with `BYDAY`; camp: daily with `COUNT`; one-off: null.
  final String? rrule;
  final int venueId;
  final String? organizerName;
  final List<String>? coachNames;
  final List<EventSession>? sessions;

  /// Whether this schedule is the one in force (no exclusive end yet).
  bool get isCurrent => effectiveUntilUtc == null;

  EventSchedule copyWith({
    int? id,
    int? eventId,
    DateTime? effectiveFromUtc,
    DateTime? Function()? effectiveUntilUtc,
    DateTime? startTimeUtc,
    DateTime? endTimeUtc,
    String? Function()? rrule,
    int? venueId,
    String? Function()? organizerName,
    List<String>? Function()? coachNames,
    List<EventSession>? Function()? sessions,
  }) {
    return EventSchedule(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      effectiveFromUtc: effectiveFromUtc ?? this.effectiveFromUtc,
      effectiveUntilUtc: effectiveUntilUtc != null
          ? effectiveUntilUtc()
          : this.effectiveUntilUtc,
      startTimeUtc: startTimeUtc ?? this.startTimeUtc,
      endTimeUtc: endTimeUtc ?? this.endTimeUtc,
      rrule: rrule != null ? rrule() : this.rrule,
      venueId: venueId ?? this.venueId,
      organizerName: organizerName != null
          ? organizerName()
          : this.organizerName,
      coachNames: coachNames != null ? coachNames() : this.coachNames,
      sessions: sessions != null ? sessions() : this.sessions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'effectiveFromUtc': effectiveFromUtc.millisecondsSinceEpoch,
      'effectiveUntilUtc': effectiveUntilUtc?.millisecondsSinceEpoch,
      'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
      'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
      'rrule': rrule,
      'venueId': venueId,
      'organizerName': organizerName,
      'coachNames': coachNames,
      'sessions': sessions?.map((s) => s.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EventSchedule(id: $id, eventId: $eventId, '
      'effectiveFromUtc: $effectiveFromUtc, '
      'effectiveUntilUtc: $effectiveUntilUtc, rrule: $rrule)';

  static const _stringListEquality = ListEquality<String>();
  static const _sessionListEquality = ListEquality<EventSession>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventSchedule &&
        other.id == id &&
        other.eventId == eventId &&
        other.effectiveFromUtc == effectiveFromUtc &&
        other.effectiveUntilUtc == effectiveUntilUtc &&
        other.startTimeUtc == startTimeUtc &&
        other.endTimeUtc == endTimeUtc &&
        other.rrule == rrule &&
        other.venueId == venueId &&
        other.organizerName == organizerName &&
        _stringListEquality.equals(other.coachNames, coachNames) &&
        _sessionListEquality.equals(other.sessions, sessions);
  }

  @override
  int get hashCode =>
      id.hashCode ^
      eventId.hashCode ^
      effectiveFromUtc.hashCode ^
      effectiveUntilUtc.hashCode ^
      startTimeUtc.hashCode ^
      endTimeUtc.hashCode ^
      rrule.hashCode ^
      venueId.hashCode ^
      organizerName.hashCode ^
      _stringListEquality.hash(coachNames) ^
      _sessionListEquality.hash(sessions);
}
