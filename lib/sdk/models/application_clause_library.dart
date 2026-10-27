import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_clause.dart';
import 'application_clause_kind.dart';
import 'application_labels.dart';

/// The clauses list (`GET /applications/clauses`, club_server#93, R7;
/// #126): the built-in clauses in library order, then the club's library
/// texts oldest first, and the choices a `choices` fact may name, in every
/// catalogue language. A template does not refer to a clause: the editor
/// pastes its text, gaps included, and the PDF fills the gaps.
@immutable
class ApplicationClauseLibrary {
  const ApplicationClauseLibrary({
    required this.languages,
    required this.choices,
    required this.clauses,
  });

  factory ApplicationClauseLibrary.fromMap(Map<String, dynamic> map) {
    return ApplicationClauseLibrary(
      languages: List<String>.unmodifiable(map['languages'] as List),
      choices: ApplicationLabels.textsById(map['choices'] as Map),
      clauses: List<ApplicationClause>.unmodifiable([
        for (final c in map['clauses'] as List)
          ApplicationClause.fromMap(c as Map<String, dynamic>),
      ]),
    );
  }

  /// The catalogue languages.
  final List<String> languages;

  /// Choice id (`on_ice`) → its text per language.
  final Map<String, Map<String, String>> choices;

  /// The built-in clauses, then the club's texts.
  final List<ApplicationClause> clauses;

  /// The built-in clause [key] (`rule.matches`), or null when there is
  /// none.
  ApplicationClause? builtinClause(String key) => clauses.firstWhereOrNull(
    (c) => c.source == ApplicationClauseSource.builtin && c.key == key,
  );

  /// The club's library texts, oldest first.
  List<ApplicationClause> get clubTexts => [
    for (final c in clauses)
      if (c.source == ApplicationClauseSource.club) c,
  ];

  /// The clauses of one [kind], in list order.
  List<ApplicationClause> clausesOfKind(ApplicationClauseKind kind) => [
    for (final c in clauses)
      if (c.kind == kind) c,
  ];

  Map<String, dynamic> toMap() => {
    'languages': [...languages],
    'choices': {
      for (final e in choices.entries) e.key: {...e.value},
    },
    'clauses': [for (final c in clauses) c.toMap()],
  };

  @override
  String toString() =>
      'ApplicationClauseLibrary(languages: $languages, '
      '${clauses.length} clauses)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationClauseLibrary &&
          const DeepCollectionEquality().equals(other.toMap(), toMap());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toMap());
}
