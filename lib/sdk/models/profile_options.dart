import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'profile_position.dart';

const _positionsEquality = ListEquality<ProfilePosition>();
const _languagesEquality = ListEquality<String>();

/// The club's profile options, the `profile_options` system preference
/// (`/system/preferences/profile_options`, club_server#92, #66): the
/// positions and languages a member chooses from for `preferredPositions`
/// and `preferredLanguages`.
///
/// Any signed-in user may read it; both lists are empty until the super
/// admin writes it (`PATCH /admin/preferences/profile_options`,
/// club_server#98, #74). The server checks a chosen value against these
/// lists when it is written (422 `INVALID_PROFILE_OPTION`); a stored value
/// whose option is removed later stays as it is.
@immutable
class ProfileOptions {
  const ProfileOptions({
    this.positions = const [],
    this.languages = const [],
  });

  /// Reads `{positions: [{value, label}], languages: [name]}`; a missing or
  /// null list reads as empty.
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
          ? languages.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  factory ProfileOptions.fromJson(String source) =>
      ProfileOptions.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The club's positions, in the order the admin set. Values are distinct.
  final List<ProfilePosition> positions;

  /// The club's languages by name (`English`, `Marathi`, …), distinct. A
  /// language here has no tie to the languages a position is labelled in.
  final List<String> languages;

  /// True when the club has set no position and no language.
  bool get isEmpty => positions.isEmpty && languages.isEmpty;

  /// The position whose value is [value], or null when there is none.
  ProfilePosition? position(String value) =>
      positions.firstWhereOrNull((p) => p.value == value);

  ProfileOptions copyWith({
    List<ProfilePosition>? positions,
    List<String>? languages,
  }) {
    return ProfileOptions(
      positions: positions ?? this.positions,
      languages: languages ?? this.languages,
    );
  }

  Map<String, dynamic> toMap() => {
    'positions': [for (final p in positions) p.toMap()],
    'languages': languages,
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
