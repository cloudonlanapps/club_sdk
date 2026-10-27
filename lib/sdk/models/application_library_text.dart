import 'package:meta/meta.dart';

import 'application_clause_kind.dart';
import 'application_text.dart';

/// A text of the club's library (`/applications/library`, club_server#126,
/// R7a): club-wide, for an admin to paste into any template as written.
/// Its texts may hold `{gap}`s, filled from the template's facts when the
/// PDF is drawn. Only a rule has a [heading].
///
/// The server's built-in clauses are seeded into the library on its first
/// use (club_server#133, #96): each is then an ordinary library text,
/// edited and deleted like any other, that keeps the built-in clause it
/// came from in [key]. The clauses list (`ApplicationClauseLibrary`) holds
/// these texts too.
///
/// Texts are shown in the club's languages (`ProfileOptions.languages`).
@immutable
class ApplicationLibraryText {
  const ApplicationLibraryText({
    required this.id,
    required this.kind,
    required this.name,
    required this.text,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.key,
    this.heading,
    this.createdBy,
  });

  factory ApplicationLibraryText.fromMap(Map<String, dynamic> map) =>
      ApplicationLibraryText(
        id: map['id'] as int,
        key: map['key'] as String?,
        kind: ApplicationClauseKind.fromWire(map['kind'] as String),
        name: map['name'] as String,
        heading: ApplicationText.fromWire(map['heading']),
        text: ApplicationText.fromMap(map['text'] as Map<String, dynamic>),
        createdBy: map['createdBy'] as String?,
        createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
          map['createdAtUtc'] as int,
          isUtc: true,
        ),
        updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
          map['updatedAtUtc'] as int,
          isUtc: true,
        ),
      );

  final int id;

  /// The built-in clause a seeded text came from (`rule.matches`); null
  /// for a text the club wrote. Not writable.
  final String? key;

  /// Where the text is used on the form.
  final ApplicationClauseKind kind;

  /// A short name for the editor's picker, 1–100 characters.
  final String name;

  /// A rule's heading per language; null for the other kinds.
  final ApplicationText? heading;

  /// The text per language, gaps as written.
  final ApplicationText text;

  /// Username of the admin who created it.
  final String? createdBy;

  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  ApplicationLibraryText copyWith({
    int? id,
    String? Function()? key,
    ApplicationClauseKind? kind,
    String? name,
    ApplicationText? Function()? heading,
    ApplicationText? text,
    String? Function()? createdBy,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => ApplicationLibraryText(
    id: id ?? this.id,
    key: key != null ? key() : this.key,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    heading: heading != null ? heading() : this.heading,
    text: text ?? this.text,
    createdBy: createdBy != null ? createdBy() : this.createdBy,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'key': key,
    'kind': kind.wireName,
    'name': name,
    'heading': heading?.toMap(),
    'text': text.toMap(),
    'createdBy': createdBy,
    'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
    'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
  };

  @override
  String toString() =>
      'ApplicationLibraryText(id: $id, key: $key, kind: ${kind.wireName}, '
      'name: $name, heading: $heading, text: $text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationLibraryText &&
          other.id == id &&
          other.key == key &&
          other.kind == kind &&
          other.name == name &&
          other.heading == heading &&
          other.text == text &&
          other.createdBy == createdBy &&
          other.createdAtUtc == createdAtUtc &&
          other.updatedAtUtc == updatedAtUtc;

  @override
  int get hashCode => Object.hash(
    id,
    key,
    kind,
    name,
    heading,
    text,
    createdBy,
    createdAtUtc,
    updatedAtUtc,
  );
}

/// A new club library text, for `ApplicationSource.createLibraryText`
/// (club_server#126).
///
/// [name] is 1–100 characters; [text] and [heading] hold at least one
/// non-empty text, gaps allowed. Only a [ApplicationClauseKind.rule] has a
/// [heading]. The server checks all of it: a refusal is 422
/// `VALIDATION_ERROR`, and a text in a language the club does not have
/// (`ProfileOptions.languages`) is 422 `APPLICATION_LANGUAGE_NOT_OFFERED`
/// (`ApplicationLanguageNotOfferedException`, club_server#133).
@immutable
class ApplicationLibraryTextInput {
  const ApplicationLibraryTextInput({
    required this.kind,
    required this.name,
    required this.text,
    this.heading,
  });

  final ApplicationClauseKind kind;
  final String name;
  final ApplicationText? heading;
  final ApplicationText text;

  /// The POST body; `heading` only when there is one.
  Map<String, dynamic> toMap() => {
    'kind': kind.wireName,
    'name': name,
    if (heading != null) 'heading': heading!.toMap(),
    'text': text.toMap(),
  };

  @override
  String toString() => 'ApplicationLibraryTextInput(${toMap()})';
}

/// A change to a club library text, for
/// `ApplicationSource.updateLibraryText` (club_server#126).
///
/// A field left null keeps its value; one given replaces it. [heading]
/// follows the ValueGetter pattern: an omitted getter keeps it, a getter
/// returning null clears it. The result is checked as a new text is (a
/// heading only on a rule): a refusal is 422 `VALIDATION_ERROR` and
/// changes nothing.
@immutable
class ApplicationLibraryTextPatch {
  const ApplicationLibraryTextPatch({
    this.kind,
    this.name,
    this.heading,
    this.text,
  });

  final ApplicationClauseKind? kind;
  final String? name;
  final ApplicationText? Function()? heading;
  final ApplicationText? text;

  /// Whether the patch changes nothing.
  bool get isEmpty => toMap().isEmpty;

  /// The PATCH body: only the fields given.
  Map<String, dynamic> toMap() => {
    if (kind != null) 'kind': kind!.wireName,
    if (name != null) 'name': name,
    if (heading != null) 'heading': heading!()?.toMap(),
    if (text != null) 'text': text!.toMap(),
  };

  @override
  String toString() => 'ApplicationLibraryTextPatch(${toMap()})';
}
