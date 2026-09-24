import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'address.dart';
import 'gender.dart';
import 'public_profile.dart';
import 'role.dart';

enum UserStatus {
  registered,
  pending,
  active,
  blocked,
  left;

  factory UserStatus.fromName(String name) {
    return UserStatus.values.firstWhere(
      (e) => e.name == name.toLowerCase(),
      orElse: () => UserStatus.pending,
    );
  }
}

@immutable
class UserRoles {
  const UserRoles({
    this.isAdmin = false,
    this.isCoach = false,
    this.isMember = false,
    this.rawRoles = const [],
  });

  /// Creates UserRoles from a list of role strings.
  ///
  /// Unknown names (including the retired `member`, #27) are dropped from
  /// [rawRoles]; a user with no roles is an ordinary member.
  factory UserRoles.fromList(List<String> roles) {
    final parsedRoles = <Role>[];
    for (final r in roles) {
      final role = Role.tryFromName(r);
      if (role != null) parsedRoles.add(role);
    }
    return UserRoles(
      isAdmin: roles.contains('admin'),
      isCoach: roles.contains('coach'),
      isMember: roles.contains('member'),
      rawRoles: parsedRoles,
    );
  }

  factory UserRoles.fromMap(Map<String, dynamic> map) {
    final rawList = map['rawRoles'] as List? ?? [];
    final parsedRoles = <Role>[];
    for (final r in rawList) {
      final role = Role.tryFromName(r as String);
      if (role != null) parsedRoles.add(role);
    }
    return UserRoles(
      isAdmin: map['isAdmin'] as bool? ?? false,
      isCoach: map['isCoach'] as bool? ?? false,
      isMember: map['isMember'] as bool? ?? false,
      rawRoles: parsedRoles,
    );
  }

  factory UserRoles.fromJson(String source) =>
      UserRoles.fromMap(json.decode(source) as Map<String, dynamic>);

  final bool isAdmin;
  final bool isCoach;
  final bool isMember;
  final List<Role> rawRoles;

  /// Returns the list of assignable roles as strings (for API communication).
  List<String> toList() => rawRoles.map((r) => r.name).toList();

  /// Checks if the user has the specified role.
  ///
  /// Accepts both [Role] enum values and strings for flexibility.
  bool hasRole(Object role) {
    final roleName = role is Role ? role.name : role.toString();
    if (roleName == 'admin') return isAdmin;
    if (roleName == 'coach') return isCoach;
    if (roleName == 'member') return isMember;
    if (role is Role) return rawRoles.contains(role);
    final parsed = Role.tryFromName(roleName);
    return parsed != null && rawRoles.contains(parsed);
  }

  UserRoles copyWith({
    bool? isAdmin,
    bool? isCoach,
    bool? isMember,
    List<Role>? rawRoles,
  }) {
    return UserRoles(
      isAdmin: isAdmin ?? this.isAdmin,
      isCoach: isCoach ?? this.isCoach,
      isMember: isMember ?? this.isMember,
      rawRoles: rawRoles ?? this.rawRoles,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isAdmin': isAdmin,
      'isCoach': isCoach,
      'isMember': isMember,
      'rawRoles': rawRoles.map((r) => r.name).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'UserRoles(isAdmin: $isAdmin, isCoach: $isCoach, '
        'isMember: $isMember)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is UserRoles &&
        other.isAdmin == isAdmin &&
        other.isCoach == isCoach &&
        other.isMember == isMember &&
        listEquals(other.rawRoles, rawRoles);
  }

  @override
  int get hashCode =>
      isAdmin.hashCode ^
      isCoach.hashCode ^
      isMember.hashCode ^
      const DeepCollectionEquality().hash(rawRoles);
}

/// Public user profile information.
///
/// Extends [PublicProfile] with additional fields for authenticated internal
/// use.
/// Uses `username` as the unique identifier (no separate id field).
/// For internal database operations, use [UserPrivate] which has additional
/// private fields.
@immutable
class UserInfo extends PublicProfile {
  /// [publicId] is optional. When omitted, it falls back to [username].
  ///
  /// Rationale: `PublicProfile.publicId` is the privacy hash used by the
  /// public website (e.g., `/public/coaches/<publicId>`) so anonymous users
  /// can't see usernames. `UserInfo` and its subclass `UserPrivate` are only
  /// used in **authenticated** contexts (admin lists, `/auth/me`,
  /// `/users/{username}`), where the caller already knows the username.
  /// In those contexts the server's `UserInfoResponse` /
  /// `UserPrivateResponse` schemas legitimately omit `publicId`, so we
  /// derive it here. If the server *does* send a `publicId` (e.g., from a
  /// public-facing endpoint, or after a future schema change), we honour
  /// it — no SDK update needed.
  const UserInfo({
    required this.username,
    required super.displayName,
    required this.status,
    required this.isSuperAdmin,
    required this.roles,
    String? publicId,
    super.bio,
    super.achievements,
    this.firstName,
    this.middleName,
    this.lastName,
    this.nickname,
    this.useNamePublicly = false,
    this.isPublicProfile = false,
    super.isGuest,
    this.deletedAtUtc,
  }) : super(publicId: publicId ?? username);

  /// Creates a UserInfo with automatically computed displayName.
  ///
  /// This is the recommended way to create UserInfo instances when you have
  /// the raw user data but not the computed privacy fields.
  ///
  /// [publicId] must be provided by the server (generated via HMAC-SHA256).
  factory UserInfo.create({
    required String publicId,
    required String username,
    required UserStatus status,
    required bool isSuperAdmin,
    required UserRoles roles,
    String? firstName,
    String? middleName,
    String? lastName,
    String? nickname,
    bool useNamePublicly = false,
    bool isPublicProfile = false,
    bool isGuest = false,
    String? bio,
    String? achievements,
  }) {
    return UserInfo(
      publicId: publicId,
      displayName: computeDisplayName(
        username: username,
        useNamePublicly: useNamePublicly,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        nickname: nickname,
      ),
      username: username,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      nickname: nickname,
      useNamePublicly: useNamePublicly,
      isPublicProfile: isPublicProfile,
      isGuest: isGuest,
      bio: bio,
      achievements: achievements,
      status: status,
      isSuperAdmin: isSuperAdmin,
      roles: roles,
    );
  }

  factory UserInfo.fromMap(Map<String, dynamic> map) {
    final rolesRaw = map['roles'];
    UserRoles roles;
    if (rolesRaw is Map<String, dynamic>) {
      roles = UserRoles.fromMap(rolesRaw);
    } else if (rolesRaw is List) {
      roles = UserRoles.fromList(rolesRaw.cast<String>());
    } else {
      roles = const UserRoles();
    }

    final username = map['username'] as String;
    final firstName =
        map['firstName'] as String? ?? map['first_name'] as String?;
    final middleName =
        map['middleName'] as String? ?? map['middle_name'] as String?;
    final lastName = map['lastName'] as String? ?? map['last_name'] as String?;
    final nickname = map['nickname'] as String?;
    final useNamePublicly =
        map['useNamePublicly'] as bool? ??
        map['use_name_publicly'] as bool? ??
        false;

    // publicId is optional in the JSON: authenticated endpoints
    // (`/auth/me`, `/users`, `/users/{username}/private`) omit it because
    // the caller already knows the username. Public-facing endpoints
    // (e.g. staff listings) still include it. The constructor falls back
    // to `username` when this is null.
    final publicId = map['publicId'] as String?;
    // The server may send a privacy-filtered displayName ("Name not
    // provided") computed via [computePublicDisplayName]. In authenticated
    // contexts the viewer can see all the underlying name fields anyway, so
    // we recompute via [computeDisplayName] which falls back through them.
    final rawDisplayName = map['displayName'] as String?;
    final displayName =
        (rawDisplayName != null && rawDisplayName != 'Name not provided')
        ? rawDisplayName
        : computeDisplayName(
            username: username,
            useNamePublicly: useNamePublicly,
            firstName: firstName,
            middleName: middleName,
            lastName: lastName,
            nickname: nickname,
          );

    return UserInfo(
      publicId: publicId,
      displayName: displayName,
      username: username,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      nickname: nickname,
      useNamePublicly: useNamePublicly,
      isPublicProfile:
          map['isPublicProfile'] as bool? ??
          map['is_public_profile'] as bool? ??
          false,
      isGuest: (map['isGuest'] as bool?) ?? false,
      bio: map['bio'] as String?,
      achievements: map['achievements'] as String?,
      status: UserStatus.fromName(map['status'] as String? ?? 'pending'),
      isSuperAdmin: map['isSuperAdmin'] as bool? ?? false,
      roles: roles,
      deletedAtUtc: map['deletedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['deletedAtUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory UserInfo.fromJson(String source) =>
      UserInfo.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Unique identifier for the user.
  final String username;

  final String? firstName;
  final String? middleName;
  final String? lastName;

  /// User's preferred nickname for privacy-respecting display.
  final String? nickname;

  /// Whether the user opts into showing their real name publicly.
  ///
  /// Drives [computePublicDisplayName] (used for the public website):
  /// - true → real name (firstName + lastName), or "Name not provided"
  /// - false → nickname, or "Name not provided"
  ///
  /// In authenticated contexts (i.e. on this [UserInfo]), the
  /// [displayName] field is computed via [computeDisplayName] instead, which
  /// honours this preference but falls back through firstName/lastName/
  /// nickname/username so the viewer always sees a real identifier.
  final bool useNamePublicly;

  /// Whether this user is eligible for a public profile (an active coach an
  /// admin has surfaced via `display_order`). Server-computed on
  /// `UserInfoResponse`; drives whether the app links a coach name to the
  /// public `/public/profile/by_id/{publicId}` view. `false` when the server
  /// omits it.
  final bool isPublicProfile;

  final UserStatus status;
  final bool isSuperAdmin;
  final UserRoles roles;
  final DateTime? deletedAtUtc;

  /// Whether this user has effective admin privileges
  /// (explicit admin role or super admin).
  bool get isAdmin => roles.isAdmin || isSuperAdmin;

  /// Whether this user can access management screens (admin or coach).
  bool get isCoachOrAdmin => isAdmin || roles.isCoach;

  @override
  UserInfo copyWith({
    String? publicId,
    String? displayName,
    String? Function()? bio,
    String? Function()? achievements,
    String? username,
    String? Function()? firstName,
    String? Function()? middleName,
    String? Function()? lastName,
    String? Function()? nickname,
    bool? useNamePublicly,
    bool? isPublicProfile,
    bool? isGuest,
    UserStatus? status,
    bool? isSuperAdmin,
    UserRoles? roles,
    DateTime? Function()? deletedAtUtc,
  }) {
    return UserInfo(
      publicId: publicId ?? this.publicId,
      displayName: displayName ?? this.displayName,
      bio: bio != null ? bio() : this.bio,
      achievements: achievements != null ? achievements() : this.achievements,
      username: username ?? this.username,
      firstName: firstName != null ? firstName() : this.firstName,
      middleName: middleName != null ? middleName() : this.middleName,
      lastName: lastName != null ? lastName() : this.lastName,
      nickname: nickname != null ? nickname() : this.nickname,
      useNamePublicly: useNamePublicly ?? this.useNamePublicly,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      isGuest: isGuest ?? this.isGuest,
      status: status ?? this.status,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      roles: roles ?? this.roles,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'publicId': publicId,
      'displayName': displayName,
      'username': username,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'nickname': nickname,
      'useNamePublicly': useNamePublicly,
      'isPublicProfile': isPublicProfile,
      'isGuest': isGuest,
      'bio': bio,
      'achievements': achievements,
      'status': status.name,
      'isSuperAdmin': isSuperAdmin,
      'roles': roles.toMap(),
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
    };
  }

  @override
  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'UserInfo(username: $username, firstName: $firstName, '
        'middleName: $middleName, lastName: $lastName, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserInfo &&
        other.publicId == publicId &&
        other.displayName == displayName &&
        other.username == username &&
        other.firstName == firstName &&
        other.middleName == middleName &&
        other.lastName == lastName &&
        other.nickname == nickname &&
        other.useNamePublicly == useNamePublicly &&
        other.isPublicProfile == isPublicProfile &&
        other.isGuest == isGuest &&
        other.bio == bio &&
        other.achievements == achievements &&
        other.status == status &&
        other.isSuperAdmin == isSuperAdmin &&
        other.roles == roles &&
        other.deletedAtUtc == deletedAtUtc;
  }

  @override
  int get hashCode =>
      publicId.hashCode ^
      displayName.hashCode ^
      username.hashCode ^
      firstName.hashCode ^
      middleName.hashCode ^
      lastName.hashCode ^
      nickname.hashCode ^
      useNamePublicly.hashCode ^
      isPublicProfile.hashCode ^
      isGuest.hashCode ^
      bio.hashCode ^
      achievements.hashCode ^
      status.hashCode ^
      isSuperAdmin.hashCode ^
      roles.hashCode ^
      deletedAtUtc.hashCode;
}

/// Private user profile with sensitive information.
///
/// Extends [UserInfo] with additional private fields like email, password, etc.
/// Uses `username` as the unique identifier (inherited from UserInfo).
@immutable
class UserPrivate extends UserInfo {
  /// [publicId] is optional — see [UserInfo]'s constructor for the rationale.
  /// When omitted it falls back to [username] via the parent constructor.
  const UserPrivate({
    required super.username,
    required super.displayName,
    required super.status,
    required super.isSuperAdmin,
    required super.roles,
    required this.createdAtUtc,
    super.publicId,
    super.bio,
    super.achievements,
    super.firstName,
    super.middleName,
    super.lastName,
    super.nickname,
    super.useNamePublicly,
    super.isPublicProfile,
    super.isGuest,
    super.deletedAtUtc,
    this.email,
    this.phone,
    this.dateOfBirthUtc,
    this.medicalInfo,
    this.emergencyContact,
    this.lastLoginAtUtc,
    this.password,
    this.gender,
    this.address,
    this.adminReviewNote,
  });

  /// Creates a UserPrivate with automatically computed displayName.
  ///
  /// [publicId] must be provided by the server (generated via HMAC-SHA256).
  factory UserPrivate.create({
    required String publicId,
    required String username,
    required UserStatus status,
    required bool isSuperAdmin,
    required UserRoles roles,
    required DateTime createdAtUtc,
    String? firstName,
    String? middleName,
    String? lastName,
    String? nickname,
    bool useNamePublicly = false,
    bool isPublicProfile = false,
    bool isGuest = false,
    String? bio,
    String? achievements,
    String? email,
    String? phone,
    DateTime? dateOfBirthUtc,
    String? medicalInfo,
    String? emergencyContact,
    DateTime? lastLoginAtUtc,
    String? password,
    Gender? gender,
    Address? address,
    DateTime? deletedAtUtc,
    String? adminReviewNote,
  }) {
    return UserPrivate(
      publicId: publicId,
      displayName: computeDisplayName(
        username: username,
        useNamePublicly: useNamePublicly,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        nickname: nickname,
      ),
      username: username,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      nickname: nickname,
      useNamePublicly: useNamePublicly,
      isPublicProfile: isPublicProfile,
      isGuest: isGuest,
      bio: bio,
      achievements: achievements,
      status: status,
      isSuperAdmin: isSuperAdmin,
      roles: roles,
      createdAtUtc: createdAtUtc,
      email: email,
      phone: phone,
      dateOfBirthUtc: dateOfBirthUtc,
      medicalInfo: medicalInfo,
      emergencyContact: emergencyContact,
      lastLoginAtUtc: lastLoginAtUtc,
      password: password,
      gender: gender,
      address: address,
      deletedAtUtc: deletedAtUtc,
      adminReviewNote: adminReviewNote,
    );
  }

  factory UserPrivate.fromMap(Map<String, dynamic> map) {
    final public = UserInfo.fromMap(map);

    return UserPrivate(
      publicId: public.publicId,
      displayName: public.displayName,
      username: public.username,
      firstName: public.firstName,
      middleName: public.middleName,
      lastName: public.lastName,
      nickname: public.nickname,
      useNamePublicly: public.useNamePublicly,
      isPublicProfile: public.isPublicProfile,
      isGuest: public.isGuest,
      bio: public.bio,
      achievements: public.achievements,
      status: public.status,
      isSuperAdmin: public.isSuperAdmin,
      roles: public.roles,
      deletedAtUtc: public.deletedAtUtc,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      dateOfBirthUtc: map['dateOfBirthUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['dateOfBirthUtc'] as int,
              isUtc: true,
            )
          : null,
      medicalInfo: map['medicalInfo'] as String?,
      emergencyContact: map['emergencyContact'] as String?,
      lastLoginAtUtc: map['lastLoginAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['lastLoginAtUtc'] as int,
              isUtc: true,
            )
          : null,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      password: map['password'] as String?,
      gender: map['gender'] != null
          ? Gender.fromName(map['gender'] as String)
          : null,
      address: map['address'] != null
          ? Address.fromMap(map['address'] as Map<String, dynamic>)
          : null,
      adminReviewNote: map['adminReviewNote'] as String?,
    );
  }

  factory UserPrivate.fromJson(String source) =>
      UserPrivate.fromMap(json.decode(source) as Map<String, dynamic>);

  final String? email;
  final String? phone;
  final DateTime? dateOfBirthUtc;
  final String? medicalInfo;
  final String? emergencyContact;
  final DateTime? lastLoginAtUtc;
  final DateTime createdAtUtc;
  final String? password;
  final Gender? gender;
  final Address? address;

  /// Admin review note surfaced from the active `user_review_requests` row
  /// (server #123). Read-only; `null` whenever the server omits it (status
  /// not `registered`, or no active review row). Absent by design from the
  /// public [UserInfo] / list responses.
  final String? adminReviewNote;

  @override
  UserPrivate copyWith({
    String? publicId,
    String? displayName,
    String? Function()? bio,
    String? Function()? achievements,
    String? username,
    String? Function()? firstName,
    String? Function()? middleName,
    String? Function()? lastName,
    String? Function()? nickname,
    bool? useNamePublicly,
    bool? isPublicProfile,
    bool? isGuest,
    UserStatus? status,
    bool? isSuperAdmin,
    UserRoles? roles,
    DateTime? Function()? deletedAtUtc,
    String? Function()? email,
    String? Function()? phone,
    DateTime? Function()? dateOfBirthUtc,
    String? Function()? medicalInfo,
    String? Function()? emergencyContact,
    DateTime? Function()? lastLoginAtUtc,
    DateTime? createdAtUtc,
    String? Function()? password,
    Gender? Function()? gender,
    Address? Function()? address,
    String? Function()? adminReviewNote,
  }) {
    return UserPrivate(
      publicId: publicId ?? this.publicId,
      displayName: displayName ?? this.displayName,
      bio: bio != null ? bio() : this.bio,
      achievements: achievements != null ? achievements() : this.achievements,
      username: username ?? this.username,
      firstName: firstName != null ? firstName() : this.firstName,
      middleName: middleName != null ? middleName() : this.middleName,
      lastName: lastName != null ? lastName() : this.lastName,
      nickname: nickname != null ? nickname() : this.nickname,
      useNamePublicly: useNamePublicly ?? this.useNamePublicly,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      isGuest: isGuest ?? this.isGuest,
      status: status ?? this.status,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      roles: roles ?? this.roles,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
      email: email != null ? email() : this.email,
      phone: phone != null ? phone() : this.phone,
      dateOfBirthUtc: dateOfBirthUtc != null
          ? dateOfBirthUtc()
          : this.dateOfBirthUtc,
      medicalInfo: medicalInfo != null ? medicalInfo() : this.medicalInfo,
      emergencyContact: emergencyContact != null
          ? emergencyContact()
          : this.emergencyContact,
      lastLoginAtUtc: lastLoginAtUtc != null
          ? lastLoginAtUtc()
          : this.lastLoginAtUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      password: password != null ? password() : this.password,
      gender: gender != null ? gender() : this.gender,
      address: address != null ? address() : this.address,
      adminReviewNote: adminReviewNote != null
          ? adminReviewNote()
          : this.adminReviewNote,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['email'] = email;
    map['phone'] = phone;
    map['dateOfBirthUtc'] = dateOfBirthUtc?.millisecondsSinceEpoch;
    map['medicalInfo'] = medicalInfo;
    map['emergencyContact'] = emergencyContact;
    map['lastLoginAtUtc'] = lastLoginAtUtc?.millisecondsSinceEpoch;
    map['createdAtUtc'] = createdAtUtc.millisecondsSinceEpoch;
    map['password'] = password;
    map['gender'] = gender?.serverValue;
    map['address'] = address?.toMap();
    map['adminReviewNote'] = adminReviewNote;
    return map;
  }

  @override
  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'UserPrivate(username: $username, email: $email, '
        'status: $status, adminReviewNote: $adminReviewNote)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserPrivate &&
        super == other &&
        other.email == email &&
        other.phone == phone &&
        other.dateOfBirthUtc == dateOfBirthUtc &&
        other.medicalInfo == medicalInfo &&
        other.emergencyContact == emergencyContact &&
        other.lastLoginAtUtc == lastLoginAtUtc &&
        other.createdAtUtc == createdAtUtc &&
        other.password == password &&
        other.gender == gender &&
        other.address == address &&
        other.adminReviewNote == adminReviewNote;
  }

  @override
  int get hashCode =>
      super.hashCode ^
      email.hashCode ^
      phone.hashCode ^
      dateOfBirthUtc.hashCode ^
      medicalInfo.hashCode ^
      emergencyContact.hashCode ^
      lastLoginAtUtc.hashCode ^
      createdAtUtc.hashCode ^
      password.hashCode ^
      gender.hashCode ^
      address.hashCode ^
      adminReviewNote.hashCode;
}
