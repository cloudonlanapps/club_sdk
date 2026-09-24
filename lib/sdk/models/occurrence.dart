import 'dart:convert';

import 'package:meta/meta.dart';

import 'enums.dart';

/// Unified Occurrence model merged from auth/Session + events/EventOccurrence.
///
/// Represents a single occurrence of an event series, with actual timing,
/// status, and optional attendee-specific enrollment/attendance status.
@immutable
class Occurrence {
  const Occurrence({
    required this.eventId,
    required this.originalStartTimeUtc,
    required this.actualStartTimeUtc,
    required this.actualEndTimeUtc,
    required this.status,
    required this.venueId,
    this.organizerName,
    this.venueName,
    this.organizerDisplayName,
    this.isRescheduled = false,
    this.enrollmentStatus,
    this.attendanceStatus,
    this.attendanceCount,
    this.cancelReason,
    this.version = 1,
    this.updatedAtUtc,
    this.updatedBy,
  });

  factory Occurrence.fromMap(Map<String, dynamic> map) {
    // Server uses occurrenceTimeUtc/startTimeUtc/endTimeUtc;
    // SDK uses originalStartTimeUtc/actualStartTimeUtc/actualEndTimeUtc.
    final originalMs =
        (map['originalStartTimeUtc'] ?? map['occurrenceTimeUtc']) as int;
    final actualStartMs =
        (map['actualStartTimeUtc'] ??
                map['startTimeUtc'] ??
                map['occurrenceTimeUtc'])
            as int;
    final actualEndMs = (map['actualEndTimeUtc'] ?? map['endTimeUtc']) as int;

    return Occurrence(
      eventId: map['eventId'] as int,
      originalStartTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        originalMs,
        isUtc: true,
      ),
      actualStartTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        actualStartMs,
        isUtc: true,
      ),
      actualEndTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        actualEndMs,
        isUtc: true,
      ),
      status: OccurrenceStatus.values.byName(map['status'] as String),
      venueId: (map['venueId'] as int?) ?? 0,
      organizerName: map['organizerName'] as String?,
      venueName: map['venueName'] as String?,
      organizerDisplayName: map['organizerDisplayName'] as String?,
      isRescheduled: (map['isRescheduled'] as bool?) ?? false,
      enrollmentStatus: map['enrollmentStatus'] != null
          ? EnrollmentStatus.values.byName(map['enrollmentStatus'] as String)
          : null,
      attendanceStatus: map['attendanceStatus'] != null
          ? AttendanceStatus.values.byName(map['attendanceStatus'] as String)
          : null,
      attendanceCount: map['attendanceCount'] as int?,
      cancelReason: map['cancelReason'] as String?,
      version: (map['version'] as int?) ?? 1,
      updatedAtUtc: map['updatedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(
              map['updatedAt'] as int,
              isUtc: true,
            )
          : null,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  factory Occurrence.fromJson(String source) =>
      Occurrence.fromMap(json.decode(source) as Map<String, dynamic>);
  final int eventId;
  final DateTime originalStartTimeUtc;
  final DateTime actualStartTimeUtc;
  final DateTime actualEndTimeUtc;
  final OccurrenceStatus status;
  final int venueId;
  final String? organizerName;

  /// The venue's name, sent with the occurrence so a caller need not look
  /// the venue up (#6). Null when the occurrence has no venue.
  final String? venueName;

  /// The organizer's **public** display name (#6): their real name only
  /// when they have chosen to show it publicly, else their nickname or
  /// "Name not provided" — the same rule as `computePublicDisplayName`,
  /// not the staff view's full name. Null when there is no organizer.
  final String? organizerDisplayName;

  /// Whether this occurrence carries a per-occurrence override that changed its
  /// start/end, venue, or organizer. The server sets this for **any** field
  /// override (so a venue-only or organizer-only change still reports `true`);
  /// combined with a `cancelled` [status] it marks every occurrence the
  /// series-level reschedule guard counts. A plain generated occurrence is
  /// `false`.
  final bool isRescheduled;

  // Attendee-specific fields (populated when querying as an attendee)
  final EnrollmentStatus? enrollmentStatus;
  final AttendanceStatus? attendanceStatus;

  // Statistics (populated in detail views)
  final int? attendanceCount;

  /// Reason supplied when this occurrence was cancelled — either directly via
  /// the occurrence cancel API or implicitly because the parent series was
  /// cancelled. `null` for non-cancelled occurrences.
  final String? cancelReason;

  /// The occurrence's own optimistic-locking version (club_server#430, #1),
  /// separate from the event's. 1 until the occurrence is first changed.
  ///
  /// Every change to the occurrence — reschedule, cancel, undo-cancel, and a
  /// one-off's drop and reinstate — must send the version the caller last
  /// loaded; a mismatch is a 409 surfaced as `StaleVersionException`.
  final int version;

  /// When the occurrence was last changed; null until it first is.
  final DateTime? updatedAtUtc;

  /// Who last changed the occurrence; null until it first is.
  final String? updatedBy;

  Occurrence copyWith({
    int? eventId,
    DateTime? originalStartTimeUtc,
    DateTime? actualStartTimeUtc,
    DateTime? actualEndTimeUtc,
    OccurrenceStatus? status,
    int? venueId,
    String? Function()? organizerName,
    String? Function()? venueName,
    String? Function()? organizerDisplayName,
    bool? isRescheduled,
    EnrollmentStatus? Function()? enrollmentStatus,
    AttendanceStatus? Function()? attendanceStatus,
    int? Function()? attendanceCount,
    String? Function()? cancelReason,
    int? version,
    DateTime? Function()? updatedAtUtc,
    String? Function()? updatedBy,
  }) {
    return Occurrence(
      eventId: eventId ?? this.eventId,
      originalStartTimeUtc: originalStartTimeUtc ?? this.originalStartTimeUtc,
      actualStartTimeUtc: actualStartTimeUtc ?? this.actualStartTimeUtc,
      actualEndTimeUtc: actualEndTimeUtc ?? this.actualEndTimeUtc,
      status: status ?? this.status,
      venueId: venueId ?? this.venueId,
      organizerName: organizerName != null
          ? organizerName()
          : this.organizerName,
      venueName: venueName != null ? venueName() : this.venueName,
      organizerDisplayName: organizerDisplayName != null
          ? organizerDisplayName()
          : this.organizerDisplayName,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      enrollmentStatus: enrollmentStatus != null
          ? enrollmentStatus()
          : this.enrollmentStatus,
      attendanceStatus: attendanceStatus != null
          ? attendanceStatus()
          : this.attendanceStatus,
      attendanceCount: attendanceCount != null
          ? attendanceCount()
          : this.attendanceCount,
      cancelReason: cancelReason != null ? cancelReason() : this.cancelReason,
      version: version ?? this.version,
      updatedAtUtc: updatedAtUtc != null ? updatedAtUtc() : this.updatedAtUtc,
      updatedBy: updatedBy != null ? updatedBy() : this.updatedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'originalStartTimeUtc': originalStartTimeUtc.millisecondsSinceEpoch,
      'actualStartTimeUtc': actualStartTimeUtc.millisecondsSinceEpoch,
      'actualEndTimeUtc': actualEndTimeUtc.millisecondsSinceEpoch,
      'status': status.name,
      'venueId': venueId,
      'organizerName': organizerName,
      'venueName': venueName,
      'organizerDisplayName': organizerDisplayName,
      'isRescheduled': isRescheduled,
      'enrollmentStatus': enrollmentStatus?.name,
      'attendanceStatus': attendanceStatus?.name,
      'attendanceCount': attendanceCount,
      'cancelReason': cancelReason,
      'version': version,
      'updatedAt': updatedAtUtc?.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'Occurrence(eventId: $eventId, status: $status, '
        'actualStartTime: $actualStartTimeUtc, version: $version)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Occurrence &&
        other.eventId == eventId &&
        other.originalStartTimeUtc == originalStartTimeUtc &&
        other.actualStartTimeUtc == actualStartTimeUtc &&
        other.actualEndTimeUtc == actualEndTimeUtc &&
        other.status == status &&
        other.venueId == venueId &&
        other.organizerName == organizerName &&
        other.venueName == venueName &&
        other.organizerDisplayName == organizerDisplayName &&
        other.isRescheduled == isRescheduled &&
        other.enrollmentStatus == enrollmentStatus &&
        other.attendanceStatus == attendanceStatus &&
        other.attendanceCount == attendanceCount &&
        other.cancelReason == cancelReason &&
        other.version == version &&
        other.updatedAtUtc == updatedAtUtc &&
        other.updatedBy == updatedBy;
  }

  @override
  int get hashCode {
    return eventId.hashCode ^
        originalStartTimeUtc.hashCode ^
        actualStartTimeUtc.hashCode ^
        actualEndTimeUtc.hashCode ^
        status.hashCode ^
        venueId.hashCode ^
        organizerName.hashCode ^
        venueName.hashCode ^
        organizerDisplayName.hashCode ^
        isRescheduled.hashCode ^
        enrollmentStatus.hashCode ^
        attendanceStatus.hashCode ^
        attendanceCount.hashCode ^
        cancelReason.hashCode ^
        version.hashCode ^
        updatedAtUtc.hashCode ^
        updatedBy.hashCode;
  }
}
