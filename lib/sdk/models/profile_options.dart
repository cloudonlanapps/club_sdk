import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'profile_language.dart';
import 'profile_position.dart';

const _positionsEquality = ListEquality<ProfilePosition>();
const _languagesEquality = ListEquality<ProfileLanguage>();

/// The club's profile options, the `profile_options` system preference
/// (`/system/preferences/profile_options`, club_server#92, #66): the
/// positions and languages a member chooses from for `preferredPositions`
/// and `preferredLanguages`.
///
/// Any signed-in user may read it. Never written, it has no positions and
/// the languages English and Marathi; the super admin writes it with
/// `PATCH /admin/preferences/profile_options` (club_server#98, #74). The
/// languages are also the club's application languages (club_server#133,
/// #96): the ones a form's labels, library texts and templates are
/// translated into and may print in. The server refuses a document
/// without English (`en`), with a code or name listed twice, or with a
/// position labelled in a language not in the list (422
/// `INVALID_PREFERENCE_VALUE`). The server checks a chosen value against these
/// lists when it is written (422 `INVALID_PROFILE_OPTION`); a stored value
/// whose option is removed later stays as it is.
@immutable
class ProfileOptions {
  const ProfileOptions({
    this.positions = const [],
    this.languages = const [],
  });

  /// Reads `{positions: [{value, label}], languages: [{code, name}]}`; a
  /// missing or null list reads as empty, and a language entry that is not
  /// `{code, name}` is skipped.
  factory ProfileOptions.fromMap(Map<String, dynamic> map) {
    final positions = map['positions'];
    final languages = map['languages'];
    return ProfileOptions(
      positions: positions is List
          ? positions
                .map(
                  (e) => ProfilePosition.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(growable: false)
          : const [],
      languages: languages is List
          ? [
              for (final e in languages)
                if (e is Map && e['code'] is String && e['name'] is String)
                  ProfileLanguage.fromMap(Map<String, dynamic>.from(e)),
            ].toList(growable: false)
          : const [],
    );
  }

  factory ProfileOptions.fromJson(String source) =>
      ProfileOptions.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The club's positions, in the order the admin set. Values are distinct.
  final List<ProfilePosition> positions;

  /// The club's languages, in the order the admin set; codes and names
  /// distinct. A position's [ProfilePosition.label] is keyed by these
  /// codes; a member's `preferredLanguages` hold these names.
  final List<ProfileLanguage> languages;

  /// The language codes, in order.
  List<String> get codes => [for (final l in languages) l.code];

  /// The language whose code is [code], or null when there is none.
  ProfileLanguage? language(String code) =>
      languages.firstWhereOrNull((l) => l.code == code);

  /// The language named [name] (as `preferredLanguages` holds it), or null
  /// when there is none.
  ProfileLanguage? languageNamed(String name) =>
      languages.firstWhereOrNull((l) => l.name == name);

  /// True when the club has set no position and no language.
  bool get isEmpty => positions.isEmpty && languages.isEmpty;

  /// The position whose value is [value], or null when there is none.
  ProfilePosition? position(String value) =>
      positions.firstWhereOrNull((p) => p.value == value);

  ProfileOptions copyWith({
    List<ProfilePosition>? positions,
    List<ProfileLanguage>? languages,
  }) {
    return ProfileOptions(
      positions: positions ?? this.positions,
      languages: languages ?? this.languages,
    );
  }

  Map<String, dynamic> toMap() => {
    'positions': [for (final p in positions) p.toMap()],
    'languages': [for (final l in languages) l.toMap()],
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'ProfileOptions(positions: $positions, languages: $languages)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileOptions &&
        _positionsEquality.equals(other.positions, positions) &&
        _languagesEquality.equals(other.languages, languages);
  }

  @override
  int get hashCode =>
      _positionsEquality.hash(positions) ^ _languagesEquality.hash(languages);
}
