import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

const _mapEquality = MapEquality<String, String>();

/// A text value with an optional translation per language (#90).
///
/// On the wire it is either a plain string — the default, with no
/// translations — or a map `{default, <languageCode>: …}`. [toWire] writes
/// the plain string when there are no translations, so a value the admin
/// never translated stays a plain string in the stored document.
@immutable
class LocalizedText {
  const LocalizedText(this.defaultValue, [this.byLanguage = const {}]);

  /// Reads the map form `{default, <languageCode>: …}`.
  ///
  /// Throws a [FormatException] when `default` is not a string. Entries whose
  /// value is not a string are skipped.
  factory LocalizedText.fromMap(Map<String, dynamic> map) {
    final fallback = map[defaultKey];
    if (fallback is! String) {
      throw const FormatException('LocalizedText needs a string "default"');
    }
    return LocalizedText(fallback, {
      for (final entry in map.entries)
        if (entry.key != defaultKey && entry.value is String)
          entry.key: entry.value as String,
    });
  }

  factory LocalizedText.fromJson(String source) =>
      LocalizedText.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The key holding the default text in the map form.
  static const String defaultKey = 'default';

  /// Reads either wire form, or returns `null` for anything else (a number,
  /// `null`, a map without a string `default`).
  static LocalizedText? fromWire(Object? value) {
    if (value is String) return LocalizedText(value);
    if (value is Map && value[defaultKey] is String) {
      return LocalizedText.fromMap(Map<String, dynamic>.from(value));
    }
    return null;
  }

  /// The text shown when there is no translation for the viewer's language.
  final String defaultValue;

  /// Translations keyed by language code (`mr`, `hi`, …).
  final Map<String, String> byLanguage;

  /// The text for [languageCode], else [defaultValue].
  String resolve(String languageCode) =>
      byLanguage[languageCode] ?? defaultValue;

  LocalizedText copyWith({
    String? defaultValue,
    Map<String, String>? byLanguage,
  }) {
    return LocalizedText(
      defaultValue ?? this.defaultValue,
      byLanguage ?? this.byLanguage,
    );
  }

  /// The map form, always: `{default, <languageCode>: …}`.
  Map<String, dynamic> toMap() => {defaultKey: defaultValue, ...byLanguage};

  /// The value as stored: a plain string without translations, else the map
  /// form.
  Object toWire() => byLanguage.isEmpty ? defaultValue : toMap();

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'LocalizedText($defaultValue, $byLanguage)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalizedText &&
        other.defaultValue == defaultValue &&
        _mapEquality.equals(other.byLanguage, byLanguage);
  }

  @override
  int get hashCode => Object.hash(defaultValue, _mapEquality.hash(byLanguage));
}
