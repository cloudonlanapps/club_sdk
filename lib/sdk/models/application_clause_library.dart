import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_clause.dart';
import 'application_labels.dart';

/// The application clause library (club_server#93, R7): every clause by
/// id, and the choices a `choices` fact may name, in every catalogue
/// language. A template refers to a clause as
/// `ApplicationText.clause(id, args: {gap: factName})`.
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
      clauses: {
        for (final e in (map['clauses'] as Map).entries)
          e.key as String: ApplicationClause.fromMap(
            e.value as Map<String, dynamic>,
          ),
      },
    );
  }

  /// The languages every clause is written in.
  final List<String> languages;

  /// Choice id (`on_ice`) → its text per language.
  final Map<String, Map<String, String>> choices;

  /// Clause id (`rule.matches`) → the clause, in library order.
  final Map<String, ApplicationClause> clauses;

  /// The clauses of one [kind] (`rule`, `note`, …), in library order.
  Map<String, ApplicationClause> clausesOfKind(String kind) => {
    for (final e in clauses.entries)
      if (e.value.kind == kind) e.key: e.value,
  };

  Map<String, dynamic> toMap() => {
    'languages': [...languages],
    'choices': {
      for (final e in choices.entries) e.key: {...e.value},
    },
    'clauses': {for (final e in clauses.entries) e.key: e.value.toMap()},
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
