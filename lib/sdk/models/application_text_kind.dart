/// The three shapes of a printed text on an application template
/// (club_server#93, R6).
enum ApplicationTextKind {
  /// Written for this template: `{language: text}`.
  custom,

  /// A library clause, its gaps naming facts: `{"clause": id, "args"?}`.
  clause,

  /// One of the template's facts, printed on its own: `{"fact": name}`.
  fact,
}
