import 'package:meta/meta.dart';

import 'enums.dart';

/// Configuration for RRULE validation per event type.
///
/// Defines constraints on recurrence rules based on the type of event
/// (Programme, Camp, OneOff). Used by [`RruleUtil`] to validate RRULE strings.
///
/// Default configurations:
/// - **Programme**: FREQ=WEEKLY with BYDAY required
/// - **Camp**: FREQ=DAILY with COUNT required, EXDATE allowed
/// - **OneOff**: No RRULE allowed
@immutable
class RruleConfig {
  const RruleConfig({
    required this.eventType,
    this.allowRrule = true,
    this.requiredFrequency,
    this.requireByDay = false,
    this.requireCount = false,
    this.allowExDate = false,
    this.maxOccurrencesPerExpansion = 365,
    this.maxLookAheadDays = 730,
  });

  /// Get default configuration for an event type.
  factory RruleConfig.forEventType(EventType type) {
    return defaults[type] ?? RruleConfig(eventType: type);
  }

  /// The event type this configuration applies to.
  final EventType eventType;

  /// Whether RRULE is allowed for this event type.
  final bool allowRrule;

  /// Required frequency value (e.g., 'WEEKLY', 'DAILY').
  /// If null, any frequency is allowed.
  final String? requiredFrequency;

  /// Whether BYDAY must be specified in the RRULE.
  /// True for Programme events (must specify which days).
  final bool requireByDay;

  /// Whether COUNT must be specified in the RRULE.
  /// True for Camp events (must specify number of days).
  final bool requireCount;

  /// Whether EXDATE is allowed for excluding dates.
  /// True for Camp events (can exclude holidays).
  final bool allowExDate;

  /// Maximum number of occurrences to generate in a single expansion.
  final int maxOccurrencesPerExpansion;

  /// Maximum days to look ahead when expanding RRULE.
  final int maxLookAheadDays;

  /// Default configurations for each event type.
  static const Map<EventType, RruleConfig> defaults = {
    EventType.programme: RruleConfig(
      eventType: EventType.programme,
      requiredFrequency: 'WEEKLY',
      requireByDay: true,
      maxLookAheadDays: 365,
    ),
    EventType.camp: RruleConfig(
      eventType: EventType.camp,
      requiredFrequency: 'DAILY',
      requireCount: true,
      allowExDate: true,
      maxOccurrencesPerExpansion: 30,
      maxLookAheadDays: 90,
    ),
    EventType.oneOff: RruleConfig(
      eventType: EventType.oneOff,
      allowRrule: false,
    ),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RruleConfig &&
        other.eventType == eventType &&
        other.allowRrule == allowRrule &&
        other.requiredFrequency == requiredFrequency &&
        other.requireByDay == requireByDay &&
        other.requireCount == requireCount &&
        other.allowExDate == allowExDate &&
        other.maxOccurrencesPerExpansion == maxOccurrencesPerExpansion &&
        other.maxLookAheadDays == maxLookAheadDays;
  }

  @override
  int get hashCode {
    return Object.hash(
      eventType,
      allowRrule,
      requiredFrequency,
      requireByDay,
      requireCount,
      allowExDate,
      maxOccurrencesPerExpansion,
      maxLookAheadDays,
    );
  }

  @override
  String toString() {
    return 'RruleConfig('
        'eventType: $eventType, '
        'allowRrule: $allowRrule, '
        'requiredFrequency: $requiredFrequency, '
        'requireByDay: $requireByDay, '
        'requireCount: $requireCount, '
        'allowExDate: $allowExDate)';
  }
}
