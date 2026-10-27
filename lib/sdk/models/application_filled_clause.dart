import 'package:meta/meta.dart';

import 'application_text.dart';

/// One library clause filled with facts, in every library language
/// (`POST /applications/clauses/fill`, club_server#107), for the editor
/// to insert into a template as custom text: [text] as a printed text,
/// and a rule's [heading] and [text] as an `ApplicationTerm`.
@immutable
class ApplicationFilledClause {
  const ApplicationFilledClause({
    required this.clause,
    required this.text,
    this.heading,
  });

  factory ApplicationFilledClause.fromMap(Map<String, dynamic> map) =>
      ApplicationFilledClause(
        clause: map['clause'] as String,
        heading: ApplicationText.fromWire(map['heading']),
        text: ApplicationText.fromMap(map['text'] as Map<String, dynamic>),
      );

  /// The clause's id in the library (`rule.matches`).
  final String clause;

  /// A rule's heading per language; null for the other kinds.
  final ApplicationText? heading;

  /// The filled sentence per language.
  final ApplicationText text;

  ApplicationFilledClause copyWith({
    String? clause,
    ApplicationText? Function()? heading,
    ApplicationText? text,
  }) => ApplicationFilledClause(
    clause: clause ?? this.clause,
    heading: heading != null ? heading() : this.heading,
    text: text ?? this.text,
  );

  Map<String, dynamic> toMap() => {
    'clause': clause,
    'heading': heading?.toMap(),
    'text': text.toMap(),
  };

  @override
  String toString() =>
      'ApplicationFilledClause(clause: $clause, heading: $heading, '
      'text: $text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationFilledClause &&
          other.clause == clause &&
          other.heading == heading &&
          other.text == text;

  @override
  int get hashCode => Object.hash(clause, heading, text);
}
