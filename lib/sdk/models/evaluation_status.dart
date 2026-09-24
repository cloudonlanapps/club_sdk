/// Lifecycle state of an evaluation (club_server#302, R14–R19).
///
/// The only moves are draft → saved → published, published → saved
/// (withdraw) and saved → draft (revert). A draft cannot be published
/// directly; the server answers 422 `INVALID_TRANSITION`.
enum EvaluationStatus {
  draft('draft'),
  saved('saved'),
  published('published');

  const EvaluationStatus(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Parse a wire value; unknown values are treated as [draft].
  static EvaluationStatus fromWire(String wire) {
    for (final v in EvaluationStatus.values) {
      if (v.wireName == wire) return v;
    }
    return EvaluationStatus.draft;
  }
}
