import 'dart:convert';

import 'package:meta/meta.dart';

import 'enums.dart';

/// Override for a specific occurrence within an event series.
///
/// Used to reschedule, cancel, or modify individual occurrences
/// without affecting the entire series.
@immutable
class OccurrenceOverride {
  const OccurrenceOverride({
    required this.eventId,
    required this.occurrenceTimeUtc,
    required this.status,
    this.newStartTimeUtc,
    this.newEndTimeUtc,
    this.newVenueId,
    this.newOrganizerName,
  });

  factory OccurrenceOverride.fromMap(Map<String, dynamic> map) {
    return OccurrenceOverride(
      eventId: map['eventId'] as int,
      occurrenceTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['occurrenceTimeUtc'] as int,
        isUtc: true,
      ),
      status: OccurrenceStatus.values.byName(map['status'] as String),
      newStartTimeUtc: map['newStartTimeUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['newStartTimeUtc'] as int,
              isUtc: true,
            )
          : null,
      newEndTimeUtc: map['newEndTimeUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['newEndTimeUtc'] as int,
              isUtc: true,
            )
          : null,
      newVenueId: map['newVenueId'] as int?,
      newOrganizerName: map['newOrganizerName'] as String?,
    );
  }

  factory OccurrenceOverride.fromJson(String source) =>
      OccurrenceOverride.fromMap(json.decode(source) as Map<String, dynamic>);
  final int eventId;
  final DateTime occurrenceTimeUtc;
  final OccurrenceStatus status;
  final DateTime? newStartTimeUtc;
  final DateTime? newEndTimeUtc;
  final int? newVenueId;
  final String? newOrganizerName;

  /// The effective start time for this occurrence: the rescheduled
  /// [newStartTimeUtc] when present, otherwise the original slot key
  /// [occurrenceTimeUtc]. Use this for window math (attendance edit window,
  /// leave declaration deadline, pre-occurrence gates).
  DateTime get effectiveStartTimeUtc => newStartTimeUtc ?? occurrenceTimeUtc;

  OccurrenceOverride copyWith({
    int? eventId,
    DateTime? occurrenceTimeUtc,
    OccurrenceStatus? status,
    DateTime? Function()? newStartTimeUtc,
    DateTime? Function()? newEndTimeUtc,
    int? Function()? newVenueId,
    String? Function()? newOrganizerName,
  }) {
    return OccurrenceOverride(
      eventId: eventId ?? this.eventId,
      occurrenceTimeUtc: occurrenceTimeUtc ?? this.occurrenceTimeUtc,
      status: status ?? this.status,
      newStartTimeUtc: newStartTimeUtc != null
          ? newStartTimeUtc()
          : this.newStartTimeUtc,
      newEndTimeUtc: newEndTimeUtc != null
          ? newEndTimeUtc()
          : this.newEndTimeUtc,
      newVenueId: newVenueId != null ? newVenueId() : this.newVenueId,
      newOrganizerName: newOrganizerName != null
          ? newOrganizerName()
          : this.newOrganizerName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'occurrenceTimeUtc': occurrenceTimeUtc.millisecondsSinceEpoch,
      'status': status.name,
      'newStartTimeUtc': newStartTimeUtc?.millisecondsSinceEpoch,
      'newEndTimeUtc': newEndTimeUtc?.millisecondsSinceEpoch,
      'newVenueId': newVenueId,
      'newOrganizerName': newOrganizerName,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'OccurrenceOverride(eventId: $eventId, '
        'occurrenceTime: $occurrenceTimeUtc, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OccurrenceOverride &&
        other.eventId == eventId &&
        other.occurrenceTimeUtc == occurrenceTimeUtc &&
        other.status == status &&
        other.newStartTimeUtc == newStartTimeUtc &&
        other.newEndTimeUtc == newEndTimeUtc &&
        other.newVenueId == newVenueId &&
        other.newOrganizerName == newOrganizerName;
  }

  @override
  int get hashCode {
    return eventId.hashCode ^
        occurrenceTimeUtc.hashCode ^
        status.hashCode ^
        newStartTimeUtc.hashCode ^
        newEndTimeUtc.hashCode ^
        newVenueId.hashCode ^
        newOrganizerName.hashCode;
  }
}
