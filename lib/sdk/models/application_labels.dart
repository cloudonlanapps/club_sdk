import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_text.dart';

/// The club's labels of application forms (club_server#93, R8; #133): the
/// form's fixed wording — headings, field labels, Male / Female / Other,
/// signature lines — in the club's languages. They are seeded once from
/// the server's catalogue and are then the club's, an admin editing one
/// with `ApplicationSource.updateLabel`. The editor pre-fills each label
/// from them; a template replaces one with `labelOverrides`.
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

  /// The club's language codes (`ProfileOptions.languages`): the ones a
  /// template may print in.
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

/// One of the club's labels as `PATCH /applications/labels/{key}` answers
/// it (club_server#133, R8a): its [key] (`field.full_name`) and its [text]
/// in the club's languages.
@immutable
class ApplicationLabel {
  const ApplicationLabel({required this.key, required this.text});

  factory ApplicationLabel.fromMap(Map<String, dynamic> map) =>
      ApplicationLabel(
        key: map['key'] as String,
        text: ApplicationText.fromMap(map['text'] as Map<String, dynamic>),
      );

  /// The label's key in the catalogue.
  final String key;

  /// The label's text per language.
  final ApplicationText text;

  Map<String, dynamic> toMap() => {'key': key, 'text': text.toMap()};

  @override
  String toString() => 'ApplicationLabel($key: ${text.texts})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationLabel && other.key == key && other.text == text;

  @override
  int get hashCode => Object.hash(key, text);
}
