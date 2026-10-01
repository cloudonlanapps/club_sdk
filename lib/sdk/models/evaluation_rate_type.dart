/// How a rating with a range is shown (club_server#535): as [stars].
/// Absent, the range is shown as plain numbers. Labelled levels take no
/// rate type.
enum EvaluationRateType {
  stars('stars');

  const EvaluationRateType(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Parse a wire value.
  static EvaluationRateType fromWire(String wire) {
    for (final v in EvaluationRateType.values) {
      if (v.wireName == wire) return v;
    }
    throw ArgumentError('Unknown evaluation rate type: $wire');
  }
}
