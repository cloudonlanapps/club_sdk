/// Assignable user roles in the system.
///
/// There is no `member` role: the server dropped it (club_server#400,
/// SDK #27) because it gated nothing. A user with no roles is an ordinary
/// member, and their `UserRoles.rawRoles` is simply empty.
///
/// Nor is there a `super_admin` role (club_server#514): super admin is the
/// `isSuperAdmin` flag, which changes only by `UserSource.transferSuperAdmin`.
/// The server refuses `super_admin` with 422 on both assign and remove.
enum Role {
  admin,
  coach;

  /// Creates a Role from its string name.
  ///
  /// Accepts camelCase or snake_case names, ignoring case.
  factory Role.fromName(String name) {
    final normalized = name.toLowerCase().replaceAll('_', '');
    return Role.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => throw ArgumentError('Unknown role: $name'),
    );
  }

  /// Tries to parse a role name, returning null if invalid.
  static Role? tryFromName(String name) {
    final normalized = name.toLowerCase().replaceAll('_', '');
    for (final role in Role.values) {
      if (role.name.toLowerCase() == normalized) {
        return role;
      }
    }
    return null;
  }

  /// Converts the role to snake_case format for API communication.
  ///
  /// Example: `admin` → `admin`; a camelCase name becomes snake_case.
  String toSnakeCase() {
    return name.replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => '_${m.group(0)!.toLowerCase()}',
    );
  }
}
