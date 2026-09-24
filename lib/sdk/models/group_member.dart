import 'dart:convert';

import 'package:meta/meta.dart';

/// A member row as returned by `GET /v1/groups/by_id/{id}/members`.
///
/// The server sends exactly these four fields (`GroupMemberInfo`). This was
/// previously parsed as `UserInfo`, whose extra fields then fell to their
/// defaults — so every member reported `status: pending` with no roles.
/// Fetch the full record separately when more than a name is needed.
@immutable
class GroupMember {
  const GroupMember({
    required this.membername,
    this.firstName,
    this.lastName,
    this.nickname,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      membername: map['membername'] as String,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      nickname: map['nickname'] as String?,
    );
  }

  factory GroupMember.fromJson(String source) =>
      GroupMember.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The member's username.
  final String membername;

  final String? firstName;
  final String? lastName;
  final String? nickname;

  /// Best available display name, falling back to the username.
  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    final parts = [firstName, lastName].whereType<String>().where(
          (p) => p.isNotEmpty,
        );
    return parts.isEmpty ? membername : parts.join(' ');
  }

  GroupMember copyWith({
    String? membername,
    String? Function()? firstName,
    String? Function()? lastName,
    String? Function()? nickname,
  }) {
    return GroupMember(
      membername: membername ?? this.membername,
      firstName: firstName != null ? firstName() : this.firstName,
      lastName: lastName != null ? lastName() : this.lastName,
      nickname: nickname != null ? nickname() : this.nickname,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'membername': membername,
      'firstName': firstName,
      'lastName': lastName,
      'nickname': nickname,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'GroupMember(membername: $membername, firstName: $firstName, '
        'lastName: $lastName, nickname: $nickname)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroupMember &&
        other.membername == membername &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.nickname == nickname;
  }

  @override
  int get hashCode => Object.hash(membername, firstName, lastName, nickname);
}
