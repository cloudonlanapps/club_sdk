import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_clause_kind.dart';
import 'application_fact_type.dart';
import 'application_text.dart';

/// One entry of the clauses list (`GET /applications/clauses`,
/// club_server#93, R7; #126): a text the editor pastes into a template as
/// written, its `{gap}`s included. The PDF fills each gap from the
/// template's fact of that name.
///
/// A built-in clause ([ApplicationClauseSource.builtin]) is named by its
/// [key] and gives each gap's fact type in [gaps]. A club library text
/// ([ApplicationClauseSource.club], `ApplicationLibraryText`) is named by
/// its [id] and [name]; its [gaps] are null.
@immutable
class ApplicationClause {
  const ApplicationClause({
    required this.source,
    required this.kind,
    required this.text,
    this.key,
    this.id,
    this.name,
    this.gaps,
    this.heading,
  });

  factory ApplicationClause.fromMap(Map<String, dynamic> map) {
    final gaps = map['gaps'];
    return ApplicationClause(
      source: ApplicationClauseSource.fromWire(map['source'] as String),
      key: map['key'] as String?,
      id: map['id'] as int?,
      kind: ApplicationClauseKind.fromWire(map['kind'] as String),
      name: map['name'] as String?,
      gaps: gaps is Map
          ? {
              for (final e in gaps.entries)
                e.key as String: ApplicationFactType.fromWire(
                  e.value as String,
                ),
            }
          : null,
      heading: ApplicationText.fromWire(map['heading']),
      text: ApplicationText.fromMap(map['text'] as Map<String, dynamic>),
    );
  }

  /// Built-in or the club's.
  final ApplicationClauseSource source;

  /// A built-in clause's key (`rule.matches`); null for a club text.
  final String? key;

  /// A club text's id; null for a built-in clause.
  final int? id;

  /// Where the text is used on the form.
  final ApplicationClauseKind kind;

  /// A club text's name, for the editor's picker; null for a built-in
  /// clause.
  final String? name;

  /// A built-in clause's gaps: each gap's name → the type of fact it
  /// takes. Null for a club text.
  final Map<String, ApplicationFactType>? gaps;

  /// A rule's heading per language; null for the other kinds.
  final ApplicationText? heading;

  /// The text per language, with its `{gap}`s as written.
  final ApplicationText text;

  Map<String, dynamic> toMap() => {
    'source': source.wireName,
    'key': key,
    'id': id,
    'kind': kind.wireName,
    'name': name,
    'gaps': gaps == null
        ? null
        : {for (final e in gaps!.entries) e.key: e.value.wireName},
    'heading': heading?.toMap(),
    'text': text.toMap(),
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
