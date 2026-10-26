import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_text.dart';

/// One rule printed on an application's page 2 (club_server#93, R6): a
/// library clause of kind `rule`, which brings its own heading, or a rule
/// written for this template, a [heading] and a [body].
@immutable
class ApplicationTerm {
  /// The library rule [clauseId]; [args] names a fact for each gap.
  const ApplicationTerm.clause(String this.clauseId, {this.args})
    : heading = null,
      body = null;

  /// A rule written for this template.
  const ApplicationTerm.custom({
    required ApplicationText this.heading,
    required ApplicationText this.body,
  }) : clauseId = null,
       args = null;

  /// Reads a clause reference (`{"clause", "args"?}`) or a custom rule
  /// (`{"heading", "body"}`).
  factory ApplicationTerm.fromMap(Map<String, dynamic> map) {
    final clause = map['clause'];
    if (clause is String) {
      final args = map['args'];
      return ApplicationTerm.clause(
        clause,
        args: args is Map ? ApplicationText.stringMap(args) : null,
      );
    }
    return ApplicationTerm.custom(
      heading: ApplicationText.fromMap(map['heading'] as Map<String, dynamic>),
      body: ApplicationText.fromMap(map['body'] as Map<String, dynamic>),
    );
  }

  /// A library rule's id.
  final String? clauseId;

  /// A library rule's gap → fact name; null when sent without `args`.
  final Map<String, String>? args;

  /// A custom rule's heading.
  final ApplicationText? heading;

  /// A custom rule's text.
  final ApplicationText? body;

  /// Whether this is a library rule.
  bool get isClause => clauseId != null;

  Map<String, dynamic> toMap() => isClause
      ? ApplicationText.clause(clauseId!, args: args).toMap()
      : {'heading': heading!.toMap(), 'body': body!.toMap()};

  @override
  String toString() => 'ApplicationTerm(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationTerm &&
          other.clauseId == clauseId &&
          const MapEquality<String, String>().equals(other.args, args) &&
          other.heading == heading &&
          other.body == body;

  @override
  int get hashCode => Object.hash(
    clauseId,
    const MapEquality<String, String>().hash(args),
    heading,
    body,
  );
}
