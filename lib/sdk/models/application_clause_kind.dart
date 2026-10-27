/// Where an application text is used on the form (club_server#93, R7;
/// #126): the kind of a club library text, seeded built-in clauses
/// included (#133).
enum ApplicationClauseKind {
  /// A line under the title.
  header('header'),

  /// A selection the member ticks.
  selection('selection'),

  /// The declaration the member signs.
  declaration('declaration'),

  /// A term, with a heading.
  rule('rule'),

  /// A note under the terms.
  note('note');

  const ApplicationClauseKind(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Parse a wire value. The server knows no other kind, so an unknown one
  /// is a [FormatException].
  static ApplicationClauseKind fromWire(String wire) {
    for (final v in ApplicationClauseKind.values) {
      if (v.wireName == wire) return v;
    }
    throw FormatException('Unknown application clause kind', wire);
  }
}
