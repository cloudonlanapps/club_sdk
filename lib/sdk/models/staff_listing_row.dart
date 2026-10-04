import 'dart:convert';

import 'package:meta/meta.dart';

/// One coach's curation on the website staff page
/// (`GET /admin/staff-listing`, club_server#332, #24).
///
/// Consent (`isPublicProfile`) is the coach's own; curation is the admin's
/// and can only order or withhold, never grant visibility. A coach with no
/// row is public and uncurated; the row's absence is a `null` [position]
/// with both flags false.
@immutable
class StaffListingRow {
  const StaffListingRow({
    required this.username,
    required this.displayName,
    required this.isPublicProfile,
    this.position,
    this.isGuest = false,
    this.isHidden = false,
  });

  factory StaffListingRow.fromMap(Map<String, dynamic> map) {
    return StaffListingRow(
      username: map['username'] as String,
      displayName: map['displayName'] as String,
      isPublicProfile: (map['isPublicProfile'] as bool?) ?? false,
      position: map['position'] as int?,
      isGuest: (map['isGuest'] as bool?) ?? false,
      isHidden: (map['isHidden'] as bool?) ?? false,
    );
  }

  factory StaffListingRow.fromJson(String source) =>
      StaffListingRow.fromMap(json.decode(source) as Map<String, dynamic>);

  final String username;
  final String displayName;

  /// The coach's own consent to appear on the staff page.
  final bool isPublicProfile;

  /// Curated order; positioned coaches come first, ascending.
  final int? position;

  /// Withheld from the staff page unless guests are asked for.
  final bool isGuest;

  /// Withheld from the staff page unconditionally.
  final bool isHidden;

  StaffListingRow copyWith({
    String? username,
    String? displayName,
    bool? isPublicProfile,
    int? Function()? position,
    bool? isGuest,
    bool? isHidden,
  }) {
    return StaffListingRow(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      position: position != null ? position() : this.position,
      isGuest: isGuest ?? this.isGuest,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'displayName': displayName,
      'isPublicProfile': isPublicProfile,
      'position': position,
      'isGuest': isGuest,
      'isHidden': isHidden,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'StaffListingRow(username: $username, position: $position, '
      'isGuest: $isGuest, isHidden: $isHidden)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StaffListingRow &&
        other.username == username &&
        other.displayName == displayName &&
        other.isPublicProfile == isPublicProfile &&
        other.position == position &&
        other.isGuest == isGuest &&
        other.isHidden == isHidden;
  }

  @override
  int get hashCode =>
      username.hashCode ^
      displayName.hashCode ^
      isPublicProfile.hashCode ^
      position.hashCode ^
      isGuest.hashCode ^
      isHidden.hashCode;
}
