/// Lifecycle state of an application template (club_server#93, R12).
///
/// The moves are draft → saved (checked complete, the layout stored),
/// saved → published (members see it), published → saved (unpublish) and
/// saved → draft (revert, the layout dropped). Any other move is 422
/// `INVALID_TRANSITION`. Only a draft is edited, and only a draft or a
/// saved template is deleted (422 `INVALID_STATE` otherwise).
enum ApplicationStatus {
  draft('draft'),
  saved('saved'),
  published('published');

  const ApplicationStatus(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Parse a wire value; unknown values are treated as [draft].
  static ApplicationStatus fromWire(String wire) {
    for (final v in ApplicationStatus.values) {
      if (v.wireName == wire) return v;
    }
    return ApplicationStatus.draft;
  }
}
