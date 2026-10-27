/// Where an application text is used on the form (club_server#93, R7;
/// #126): the kind of a built-in clause and of a club library text.
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

/// Where an entry of the clauses list comes from (club_server#126).
enum ApplicationClauseSource {
  /// A clause of the server's built-in library, named by its key.
  builtin('builtin'),

  /// A text of the club's own library, named by its id.
  club('club');

  const ApplicationClauseSource(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Parse a wire value. The server knows no other source, so an unknown
  /// one is a [FormatException].
  static ApplicationClauseSource fromWire(String wire) {
    for (final v in ApplicationClauseSource.values) {
      if (v.wireName == wire) return v;
    }
    throw FormatException('Unknown application clause source', wire);
  }
}
