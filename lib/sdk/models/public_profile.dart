import 'dart:convert';

import 'package:meta/meta.dart';

import 'media_ref.dart';

/// Privacy-safe profile for public website display.
///
/// Contains only information that can be safely shown to unauthenticated users.
/// Does not expose internal identifiers like username.
@immutable
class PublicProfile {
  const PublicProfile({
    required this.publicId,
    required this.displayName,
    this.bio,
    this.achievements,
    this.avatar,
    this.isGuest = false,
  });

  factory PublicProfile.fromMap(Map<String, dynamic> map) {
    return PublicProfile(
      publicId: map['publicId'] as String,
      displayName: map['displayName'] as String,
      bio: map['bio'] as String?,
      achievements: map['achievements'] as String?,
      avatar: map['avatar'] != null
          ? MediaRef.fromMap(map['avatar'] as Map<String, dynamic>)
          : null,
      isGuest: (map['isGuest'] as bool?) ?? false,
    );
  }

  factory PublicProfile.fromJson(String source) =>
      PublicProfile.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Encrypted identifier for public URLs (not real username).
  ///
  /// Generated via HMAC-SHA256 of username with app secret.
  /// Consistent for the same username, but not reversible.
  final String publicId;

  /// Display name for public, unauthenticated viewing.
  ///
  /// Computed by [computePublicDisplayName] on the server, this respects the
  /// user's privacy preference and intentionally falls back to
  /// "Name not provided" when no shareable identifier exists.
  ///
  /// In authenticated contexts (e.g., on `UserInfo`/`UserPrivate`), this
  /// field is instead populated by [computeDisplayName], which has access to
  /// the underlying name fields and never returns the placeholder.
  final String displayName;

  /// User biography/description, if available.
  final String? bio;

  /// User achievements/qualifications, if available.
  final String? achievements;

  /// The user's current avatar, when it is publicly viewable.
  ///
  /// Set by the server's `/public` endpoints only when the latest
  /// `user_avatar`-tagged media is marked `public`; `null` otherwise. Build a
  /// download URL from it with the SDK's `mediaDownloadUrl` helper.
  final MediaRef? avatar;

  /// Whether this is a guest account (club_server#332, #24): a visiting
  /// coach an admin created with the guest flag, published on the admin's
  /// authority and never expected to log in. Staff listings withhold guests
  /// unless asked for them.
  final bool isGuest;

  // [avatar] is intentionally omitted from copyWith: it is
  // read-only, server-resolved data on the `/public` projection and is never
  // mutated client-side. Keeping it out also avoids forcing the field onto
  // the UserInfo / UserPrivate copyWith overrides, where it has no meaning.
  PublicProfile copyWith({
    String? publicId,
    String? displayName,
    String? Function()? bio,
    String? Function()? achievements,
    bool? isGuest,
  }) {
    return PublicProfile(
      publicId: publicId ?? this.publicId,
      displayName: displayName ?? this.displayName,
      bio: bio != null ? bio() : this.bio,
      achievements: achievements != null ? achievements() : this.achievements,
      avatar: avatar,
      isGuest: isGuest ?? this.isGuest,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'publicId': publicId,
      'displayName': displayName,
      'bio': bio,
      'achievements': achievements,
      'avatar': avatar?.toMap(),
      'isGuest': isGuest,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'PublicProfile(publicId: $publicId, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PublicProfile &&
        other.publicId == publicId &&
        other.displayName == displayName &&
        other.bio == bio &&
        other.achievements == achievements &&
        other.avatar == avatar &&
        other.isGuest == isGuest;
  }

  @override
  int get hashCode {
    return publicId.hashCode ^
        displayName.hashCode ^
        bio.hashCode ^
        achievements.hashCode ^
        avatar.hashCode ^
        isGuest.hashCode;
  }
}

/// Computes the privacy-filtered display name for **public** contexts.
///
/// Returns "Name not provided" when no shareable identifier is available
/// per the user's privacy preference. This is the value the server stores
/// on [PublicProfile.displayName] for unauthenticated endpoints (e.g., the
/// public coach listing).
///
/// For authenticated contexts where the viewer already has access to all of
/// the user's name fields, prefer [computeDisplayName] — it will fall back
/// through firstName/lastName/nickname/username instead of showing a
/// placeholder.
///
/// Logic:
/// - If [useNamePublicly] is true: shows real name (firstName + lastName)
/// - If [useNamePublicly] is false: shows [nickname] or "Name not provided"
///
/// Example:
/// ```dart
/// computePublicDisplayName(
///   useNamePublicly: true, firstName: 'John', lastName: 'Doe',
/// )
/// // 'John Doe'
///
/// computePublicDisplayName(useNamePublicly: false, nickname: 'JD')
/// // 'JD'
///
/// computePublicDisplayName(useNamePublicly: false)
/// // 'Name not provided'
/// ```
String computePublicDisplayName({
  required bool useNamePublicly,
  String? firstName,
  String? middleName,
  String? lastName,
  String? nickname,
}) {
  if (useNamePublicly) {
    final name = [
      firstName,
      middleName,
      lastName,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
    return name.isNotEmpty ? name : 'Name not provided';
  } else {
    return nickname ?? 'Name not provided';
  }
}

/// Computes a display name for **authenticated** contexts that always
/// returns a non-empty identifier the viewer can use to recognise the user.
///
/// Unlike [computePublicDisplayName], this never returns the
/// "Name not provided" placeholder. The viewer is already authenticated and
/// has access to every field on `UserInfo`, so the SDK falls back through
/// every available identifier in turn.
///
/// Resolution order:
/// 1. If [useNamePublicly] is true and a real name exists:
///    `firstName lastName`.
/// 2. If [useNamePublicly] is false and [nickname] is set: nickname.
/// 3. Otherwise, the first non-empty value among: `firstName lastName`,
///    nickname, [username].
///
/// Example:
/// ```dart
/// computeDisplayName(
///   username: 'sudo', useNamePublicly: false, firstName: 'Sudo',
/// )
/// // 'Sudo'  — privacy choice yields no nickname, so we fall back to firstName
///
/// computeDisplayName(username: 'jd', useNamePublicly: false, nickname: 'JD')
/// // 'JD'
///
/// computeDisplayName(username: 'plain', useNamePublicly: false)
/// // 'plain'  — last-resort fallback to username
/// ```
String computeDisplayName({
  required String username,
  required bool useNamePublicly,
  String? firstName,
  String? middleName,
  String? lastName,
  String? nickname,
}) {
  final realName = [
    firstName,
    middleName,
    lastName,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
  final nick = (nickname ?? '').trim();

  if (useNamePublicly && realName.isNotEmpty) return realName;
  if (!useNamePublicly && nick.isNotEmpty) return nick;

  // The privacy-preferred path produced nothing — fall back to whatever real
  // data we have. Authenticated viewers can see it all anyway.
  if (realName.isNotEmpty) return realName;
  if (nick.isNotEmpty) return nick;
  return username;
}
