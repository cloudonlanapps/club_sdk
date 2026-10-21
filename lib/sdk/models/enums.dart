/// Type of event.
enum EventType { oneOff, programme, camp }

/// Visibility of event.
enum Visibility {
  public,
  private;

  /// Human-readable label for the visibility value.
  String get label => this == Visibility.public ? 'Public' : 'Private';
}

/// Status of an event, derived from `untilTimeUtc` alone (#16).
///
/// - [active]: open-ended (`untilTimeUtc == null`)
/// - [cancelled]: a cutoff is set (terminated programme, cancelled camp,
///   dropped one-off). The event keeps running until the cutoff.
enum EventStatus { active, cancelled }

/// Enrollment status for a user in an event.
enum EnrollmentStatus {
  invited,
  requested,
  accepted,
  rejected,
  declined,
  assigned,
  assignedTrial,
  withdrawn,
  withdrawRequested,
  removed;

  /// Parses the server's wire name. The one parser for every enrollment
  /// status the SDK reads, so an unknown status behaves the same
  /// everywhere: it is an [ArgumentError], never read as another status
  /// (#31).
  factory EnrollmentStatus.fromName(String name) =>
      EnrollmentStatus.values.byName(name);
}

/// Attendance status for a user in an occurrence.
enum AttendanceStatus {
  present,
  absent,
  late,
  onLeave,
  onLeaveRequested,
}

/// Status of an occurrence.
enum OccurrenceStatus { scheduled, cancelled, rescheduled, completed }
