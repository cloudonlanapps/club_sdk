import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_text_kind.dart';

/// One printed text of an application template (club_server#93, R6): a
/// custom text per language, a library clause whose gaps name the
/// template's facts, or a fact on its own ([kind]).
///
/// [toMap] writes the shape `fromMap` read, so a text reads back as it was
/// sent: `{"en": "…", "mr": "…"}`, `{"clause": "rule.matches", "args":
/// {"dates": "matches"}}` (no `args` when there are none) or
/// `{"fact": "venue"}`.
@immutable
class ApplicationText {
  /// A text written for this template, keyed by language code.
  const ApplicationText.custom(Map<String, String> this.texts)
    : kind = ApplicationTextKind.custom,
      clauseId = null,
      args = null,
      factName = null;

  /// The library clause [clauseId]; [args] names a fact for each gap.
  const ApplicationText.clause(String this.clauseId, {this.args})
    : kind = ApplicationTextKind.clause,
      texts = null,
      factName = null;

  /// The fact [factName], printed on its own.
  const ApplicationText.fact(String this.factName)
    : kind = ApplicationTextKind.fact,
      texts = null,
      clauseId = null,
      args = null;

  /// Reads any of the three shapes: a `clause` key makes a clause, a
  /// `fact` key a fact, anything else a custom text.
  factory ApplicationText.fromMap(Map<String, dynamic> map) {
    final clause = map['clause'];
    if (clause is String) {
      final args = map['args'];
      return ApplicationText.clause(
        clause,
        args: args is Map ? stringMap(args) : null,
      );
    }
    final fact = map['fact'];
    if (fact is String) return ApplicationText.fact(fact);
    return ApplicationText.custom(stringMap(map));
  }

  /// Reads a text, or returns null for a null or non-map value.
  static ApplicationText? fromWire(Object? value) => value is Map
      ? ApplicationText.fromMap(Map<String, dynamic>.from(value))
      : null;

  /// The string entries of a JSON map.
  static Map<String, String> stringMap(Map<dynamic, dynamic> map) => {
    for (final e in map.entries)
      if (e.key is String && e.value is String)
        e.key as String: e.value as String,
  };

  /// Which shape this text is.
  final ApplicationTextKind kind;

  /// A custom text's language → text.
  final Map<String, String>? texts;

  /// A clause's id in the library (`rule.matches`).
  final String? clauseId;

  /// A clause's gap → fact name; null when it was sent without `args`.
  final Map<String, String>? args;

  /// A fact reference's fact name.
  final String? factName;

  Map<String, dynamic> toMap() => switch (kind) {
    ApplicationTextKind.custom => {...?texts},
    ApplicationTextKind.clause => {
      'clause': clauseId,
      if (args != null) 'args': {...?args},
    },
    ApplicationTextKind.fact => {'fact': factName},
  };

  @override
  String toString() => 'ApplicationText(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationText &&
          const DeepCollectionEquality().equals(other.toMap(), toMap());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toMap());
}
