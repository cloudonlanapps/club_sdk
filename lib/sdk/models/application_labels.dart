import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// The label catalogue of application forms (club_server#93, R8): the
/// form's fixed wording — headings, field labels, Male / Female / Other,
/// signature lines — in every catalogue language. The editor pre-fills
/// each label from it; a template replaces one with `labelOverrides`.
@immutable
class ApplicationLabels {
  const ApplicationLabels({required this.languages, required this.labels});

  factory ApplicationLabels.fromMap(Map<String, dynamic> map) {
    return ApplicationLabels(
      languages: List<String>.unmodifiable(map['languages'] as List),
      labels: textsById(map['labels'] as Map),
    );
  }

  /// `{id: {language: text}}` from JSON, keeping string texts only.
  static Map<String, Map<String, String>> textsById(Map<dynamic, dynamic> m) =>
      {
        for (final e in m.entries)
          e.key as String: {
            for (final t in (e.value as Map).entries)
              if (t.value is String) t.key as String: t.value as String,
          },
      };

  /// The catalogue languages: the ones a template may print in.
  final List<String> languages;

  /// Label id (`field.full_name`) → its text per language.
  final Map<String, Map<String, String>> labels;

  /// The text of label [id] in [language], or null.
  String? label(String id, String language) => labels[id]?[language];

  Map<String, dynamic> toMap() => {
    'languages': [...languages],
    'labels': {
      for (final e in labels.entries) e.key: {...e.value},
    },
  };

  @override
  String toString() =>
      'ApplicationLabels(languages: $languages, ${labels.length} labels)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationLabels &&
          const DeepCollectionEquality().equals(other.toMap(), toMap());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toMap());
}
