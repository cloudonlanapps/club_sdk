import 'dart:convert';

import 'package:meta/meta.dart';

/// One of the club's languages in its `ProfileOptions` (club_server#133,
/// #96): its [code], which translations are keyed by (`en`, `mr`, `kok`,
/// or `x-<name>` for one the server knows no code for), and its [name],
/// which a member chooses in `preferredLanguages`.
@immutable
class ProfileLanguage {
  const ProfileLanguage({required this.code, required this.name});

  /// Reads `{code, name}`.
  factory ProfileLanguage.fromMap(Map<String, dynamic> map) =>
      ProfileLanguage(code: map['code'] as String, name: map['name'] as String);

  factory ProfileLanguage.fromJson(String source) =>
      ProfileLanguage.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The language code (`mr`).
  final String code;

  /// The language's name (`Marathi`).
  final String name;

  ProfileLanguage copyWith({String? code, String? name}) =>
      ProfileLanguage(code: code ?? this.code, name: name ?? this.name);

  Map<String, dynamic> toMap() => {'code': code, 'name': name};

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ProfileLanguage($code: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileLanguage && other.code == code && other.name == name;

  @override
  int get hashCode => Object.hash(code, name);
}
