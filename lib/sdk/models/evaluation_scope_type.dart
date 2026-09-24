/// What an evaluation is about (club_server#302, R1–R3).
///
/// [general] is an assessment of the member overall, tied to no event.
/// [event] names one event, optionally narrowed to a period within it.
enum EvaluationScopeType {
  general('general'),
  event('event');

  const EvaluationScopeType(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Parse a wire value.
  static EvaluationScopeType fromWire(String wire) {
    for (final v in EvaluationScopeType.values) {
      if (v.wireName == wire) return v;
    }
    throw ArgumentError('Unknown evaluation scope type: $wire');
  }
}
