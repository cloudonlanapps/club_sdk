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
  removed,
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

/// Server-derived lifecycle state of an event series.
///
/// Computed by the server from start/end/until times and cancellation state.
///
/// - [comingsoon]: Series has not yet started.
/// - [ongoing]: Series is currently running and has not been cancelled.
/// - [ended]: Series has finished naturally (reached its end).
/// - [cancelled]: Series was cancelled before any occurrences ran.
/// - [partiallyCancelled]: Series was cancelled mid-stream — some occurrences
///   ran before the cancellation took effect.
enum EventLifecycleState {
  comingsoon,
  ongoing,
  ended,
  cancelled,
  partiallyCancelled;

  /// Parses the wire value sent by the server.
  ///
  /// Unknown values fall back to [comingsoon] so that older clients do not
  /// crash on a newly-introduced state.
  static EventLifecycleState fromString(String? value) {
    switch (value) {
      case 'comingsoon':
        return EventLifecycleState.comingsoon;
      case 'ongoing':
        return EventLifecycleState.ongoing;
      case 'ended':
        return EventLifecycleState.ended;
      case 'cancelled':
        return EventLifecycleState.cancelled;
      case 'partiallyCancelled':
        return EventLifecycleState.partiallyCancelled;
      default:
        return EventLifecycleState.comingsoon;
    }
  }

  /// Wire value sent over the JSON API.
  String toJson() {
    switch (this) {
      case EventLifecycleState.comingsoon:
        return 'comingsoon';
      case EventLifecycleState.ongoing:
        return 'ongoing';
      case EventLifecycleState.ended:
        return 'ended';
      case EventLifecycleState.cancelled:
        return 'cancelled';
      case EventLifecycleState.partiallyCancelled:
        return 'partiallyCancelled';
    }
  }
}
