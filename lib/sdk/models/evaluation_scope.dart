import 'dart:convert';

import 'package:meta/meta.dart';

import 'evaluation_scope_type.dart';

/// The scope of an evaluation: what it assesses (club_server#302, R1–R6).
///
/// The same shape is sent on creation and read back on every view. Scope
/// is fixed at creation and cannot be edited (R23). For [type] `event`
/// the [eventId] is required and an optional [periodStartUtc] /
/// [periodEndUtc] narrows the assessment to a window within the event;
/// the occurrences it covers are derived by the server from the window.
@immutable
class EvaluationScope {
  const EvaluationScope({
    required this.type,
    this.eventId,
    this.periodStartUtc,
    this.periodEndUtc,
  });

  /// A general-scope assessment, tied to no event.
  const EvaluationScope.general()
    : type = EvaluationScopeType.general,
      eventId = null,
      periodStartUtc = null,
      periodEndUtc = null;

  /// An event-scoped assessment of [eventId], optionally narrowed to
  /// a period.
  const EvaluationScope.event(
    int this.eventId, {
    this.periodStartUtc,
    this.periodEndUtc,
  }) : type = EvaluationScopeType.event;

  factory EvaluationScope.fromMap(Map<String, dynamic> map) {
    return EvaluationScope(
      type: EvaluationScopeType.fromWire(map['type'] as String),
      eventId: map['eventId'] as int?,
      periodStartUtc: map['periodStartUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['periodStartUtc'] as int,
              isUtc: true,
            )
          : null,
      periodEndUtc: map['periodEndUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['periodEndUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory EvaluationScope.fromJson(String source) =>
      EvaluationScope.fromMap(json.decode(source) as Map<String, dynamic>);

  final EvaluationScopeType type;

  /// The event assessed; null for general scope.
  final int? eventId;

  /// Start of the assessed period within the event, if narrowed.
  final DateTime? periodStartUtc;

  /// End of the assessed period within the event, if narrowed.
  final DateTime? periodEndUtc;

  EvaluationScope copyWith({
    EvaluationScopeType? type,
    int? Function()? eventId,
    DateTime? Function()? periodStartUtc,
    DateTime? Function()? periodEndUtc,
  }) {
    return EvaluationScope(
      type: type ?? this.type,
      eventId: eventId != null ? eventId() : this.eventId,
      periodStartUtc: periodStartUtc != null
          ? periodStartUtc()
          : this.periodStartUtc,
      periodEndUtc: periodEndUtc != null ? periodEndUtc() : this.periodEndUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.wireName,
      'eventId': eventId,
      'periodStartUtc': periodStartUtc?.millisecondsSinceEpoch,
      'periodEndUtc': periodEndUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationScope(type: $type, eventId: $eventId, '
      'periodStartUtc: $periodStartUtc, periodEndUtc: $periodEndUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationScope &&
        other.type == type &&
        other.eventId == eventId &&
        other.periodStartUtc == periodStartUtc &&
        other.periodEndUtc == periodEndUtc;
  }

  @override
  int get hashCode =>
      type.hashCode ^
      eventId.hashCode ^
      periodStartUtc.hashCode ^
      periodEndUtc.hashCode;
}
