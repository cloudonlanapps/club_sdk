import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_text.dart';

/// A closing note boxed under an application's terms (club_server#93,
/// R6): a library clause of kind `note`, or a [text] with an optional
/// [attribution] (a motto and who said it). The text may itself be a
/// clause reference.
@immutable
class ApplicationTermsNote {
  /// The library note [clauseId]; [args] names a fact for each gap.
  const ApplicationTermsNote.clause(String this.clauseId, {this.args})
    : text = null,
      attribution = null;

  /// A note with its own text.
  const ApplicationTermsNote.custom({
    required ApplicationText this.text,
    this.attribution,
  }) : clauseId = null,
       args = null;

  /// Reads a clause reference (`{"clause", "args"?}`) or a note
  /// (`{"text", "attribution"?}`).
  factory ApplicationTermsNote.fromMap(Map<String, dynamic> map) {
    final clause = map['clause'];
    if (clause is String) {
      final args = map['args'];
      return ApplicationTermsNote.clause(
        clause,
        args: args is Map ? ApplicationText.stringMap(args) : null,
      );
    }
    return ApplicationTermsNote.custom(
      text: ApplicationText.fromMap(map['text'] as Map<String, dynamic>),
      attribution: ApplicationText.fromWire(map['attribution']),
    );
  }

  /// A library note's id.
  final String? clauseId;

  /// A library note's gap → fact name; null when sent without `args`.
  final Map<String, String>? args;

  /// A note's text.
  final ApplicationText? text;

  /// Who the note is from, printed under it.
  final ApplicationText? attribution;

  /// Whether this is a library note.
  bool get isClause => clauseId != null;

  Map<String, dynamic> toMap() => isClause
      ? ApplicationText.clause(clauseId!, args: args).toMap()
      : {'text': text!.toMap(), 'attribution': ?attribution?.toMap()};

  @override
  String toString() => 'ApplicationTermsNote(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationTermsNote &&
          other.clauseId == clauseId &&
          const MapEquality<String, String>().equals(other.args, args) &&
          other.text == text &&
          other.attribution == attribution;

  @override
  int get hashCode => Object.hash(
    clauseId,
    const MapEquality<String, String>().hash(args),
    text,
    attribution,
  );
}
