import 'dart:convert';

import 'package:meta/meta.dart';

/// Minimal user shape returned by the group-eligibility endpoint.
///
/// Mirrors the server's `EligibleUserInfo`. Distinct from `UserInfo` /
/// `UserPrivate` because the server returns only the four fields needed to
/// render a "who can join" picker.
@immutable
class EligibleUser {
  const EligibleUser({
    required this.username,
    this.firstName,
    this.lastName,
    this.nickname,
  });

  factory EligibleUser.fromMap(Map<String, dynamic> map) {
    return EligibleUser(
      username: map['username'] as String,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      nickname: map['nickname'] as String?,
    );
  }

  factory EligibleUser.fromJson(String source) =>
      EligibleUser.fromMap(json.decode(source) as Map<String, dynamic>);

  final String username;
  final String? firstName;
  final String? lastName;
  final String? nickname;

  EligibleUser copyWith({
    String? username,
    String? Function()? firstName,
    String? Function()? lastName,
    String? Function()? nickname,
  }) {
    return EligibleUser(
      username: username ?? this.username,
      firstName: firstName != null ? firstName() : this.firstName,
      lastName: lastName != null ? lastName() : this.lastName,
      nickname: nickname != null ? nickname() : this.nickname,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EligibleUser(username: $username, firstName: $firstName, '
      'lastName: $lastName, nickname: $nickname)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EligibleUser &&
        other.username == username &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.nickname == nickname;
  }

  @override
  int get hashCode =>
      username.hashCode ^
      firstName.hashCode ^
      lastName.hashCode ^
      nickname.hashCode;
}
