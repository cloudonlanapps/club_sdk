import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// One text a save found missing print languages (club_server#101): its
/// API path ([field]: `title`, `terms[1].heading`, …) and the print
/// [languages] it lacks — every print language when the text is missing
/// altogether. A club label the template does not override is
/// `labels.<key>` ([labelKey], club_server#133).
@immutable
class ApplicationMissingText {
  const ApplicationMissingText({required this.field, required this.languages});

  /// Reads `{"field", "languages"}`; a language that is not a string is
  /// skipped.
  factory ApplicationMissingText.fromMap(Map<String, dynamic> map) =>
      ApplicationMissingText(
        field: map['field'] as String,
        languages: List<String>.unmodifiable(
          ((map['languages'] as List?) ?? const []).whereType<String>(),
        ),
      );

  /// The text's API path.
  final String field;

  /// The print languages it lacks.
  final List<String> languages;

  /// The key of the club label this entry names (`labels.field.full_name`
  /// → `field.full_name`), or null for any other text: fill it in with
  /// `ApplicationSource.updateLabel`.
  String? get labelKey => field.startsWith(_labelsPrefix)
      ? field.substring(_labelsPrefix.length)
      : null;

  static const _labelsPrefix = 'labels.';

  Map<String, dynamic> toMap() => {
    'field': field,
    'languages': [...languages],
  };

  @override
  String toString() => '$field (${languages.join(', ')})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationMissingText &&
          other.field == field &&
          const ListEquality<String>().equals(other.languages, languages);

  @override
  int get hashCode =>
      Object.hash(field, const ListEquality<String>().hash(languages));
}
