import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// One printed text of an application template: the text in each language,
/// `{"en": "…", "mr": "…"}` (club_server#93, R6; #107).
///
/// A template's printed texts are custom text only: the server refuses a
/// `{"clause": …}` or `{"fact": …}` reference with 422. A text may hold
/// `{name}` gaps (club_server#126), kept as written and filled from the
/// template's fact of that name when the PDF is drawn; to print a library
/// clause, paste its text (`ApplicationClause.text`).
@immutable
class ApplicationText {
  /// The text keyed by language code.
  const ApplicationText(this.texts);

  /// Reads `{language: text}`; an entry whose value is not a string is
  /// skipped.
  factory ApplicationText.fromMap(Map<String, dynamic> map) =>
      ApplicationText(stringMap(map));

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

  /// Language code → text.
  final Map<String, String> texts;

  Map<String, dynamic> toMap() => {...texts};

  @override
  String toString() => 'ApplicationText($texts)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationText &&
          const MapEquality<String, String>().equals(other.texts, texts);

  @override
  int get hashCode => const MapEquality<String, String>().hash(texts);
}
