import 'dart:convert';

import 'package:meta/meta.dart';

import 'user.dart';

/// Immutable filter state for the admin user list.
///
/// All fields are nullable so the filter can be partial. Pass through
/// directly to `client.users.getUsers(...)`.
@immutable
class UserListFilter {
  const UserListFilter({
    this.status,
    this.role,
    this.searchTerm,
    this.sortBy = 'username',
    this.descending = false,
  });

  factory UserListFilter.fromMap(Map<String, dynamic> map) {
    return UserListFilter(
      status: map['status'] != null
          ? UserStatus.fromName(map['status'] as String)
          : null,
      role: map['role'] as String?,
      searchTerm: map['searchTerm'] as String?,
      sortBy: map['sortBy'] as String? ?? 'username',
      descending: map['descending'] as bool? ?? false,
    );
  }

  factory UserListFilter.fromJson(String source) =>
      UserListFilter.fromMap(json.decode(source) as Map<String, dynamic>);

  final UserStatus? status;
  final String? role;
  final String? searchTerm;
  final String sortBy;
  final bool descending;

  UserListFilter copyWith({
    UserStatus? Function()? status,
    String? Function()? role,
    String? Function()? searchTerm,
    String? sortBy,
    bool? descending,
  }) {
    return UserListFilter(
      status: status != null ? status() : this.status,
      role: role != null ? role() : this.role,
      searchTerm: searchTerm != null ? searchTerm() : this.searchTerm,
      sortBy: sortBy ?? this.sortBy,
      descending: descending ?? this.descending,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status?.name,
      'role': role,
      'searchTerm': searchTerm,
      'sortBy': sortBy,
      'descending': descending,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'UserListFilter(status: $status, role: $role, '
        'searchTerm: $searchTerm, sortBy: $sortBy, descending: $descending)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserListFilter &&
        other.status == status &&
        other.role == role &&
        other.searchTerm == searchTerm &&
        other.sortBy == sortBy &&
        other.descending == descending;
  }

  @override
  int get hashCode =>
      status.hashCode ^
      role.hashCode ^
      searchTerm.hashCode ^
      sortBy.hashCode ^
      descending.hashCode;
}
