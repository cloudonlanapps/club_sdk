import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_fact_type.dart';
import 'application_labels.dart';

/// One clause of the application clause library (club_server#93, R7): a
/// sentence in every catalogue language with `{gap}`s a template fills
/// with its facts.
@immutable
class ApplicationClause {
  const ApplicationClause({
    required this.kind,
    required this.text,
    this.gaps = const {},
    this.heading,
  });

  factory ApplicationClause.fromMap(Map<String, dynamic> map) {
    final texts = ApplicationLabels.textsById({
      'text': map['text'],
      if (map['heading'] != null) 'heading': map['heading'],
    });
    return ApplicationClause(
      kind: map['kind'] as String,
      gaps: {
        for (final e in ((map['gaps'] as Map?) ?? const {}).entries)
          e.key as String: ApplicationFactType.fromWire(e.value as String),
      },
      heading: texts['heading'],
      text: texts['text']!,
    );
  }

  /// Where the clause is used: `header`, `declaration`, `selection`,
  /// `rule` or `note`.
  final String kind;

  /// Each gap's name → the type of fact it takes.
  final Map<String, ApplicationFactType> gaps;

  /// A rule's heading per language; null for the other kinds.
  final Map<String, String>? heading;

  /// The sentence per language, with `{gap}` placeholders.
  final Map<String, String> text;

  Map<String, dynamic> toMap() => {
    'kind': kind,
    'gaps': {for (final e in gaps.entries) e.key: e.value.wireName},
    'heading': heading == null ? null : {...heading!},
    'text': {...text},
  };

  @override
  String toString() => 'ApplicationClause(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationClause &&
          const DeepCollectionEquality().equals(other.toMap(), toMap());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toMap());
}
