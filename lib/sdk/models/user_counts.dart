import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'user.dart';

/// Live user counts grouped by status, from `GET /users/count` (#30).
///
/// Every status is always present, zero included. Soft-deleted users and
/// super admins are counted nowhere. [total] is the sum of every bucket,
/// so it includes `registered` users, which `GET /users` omits unless
/// asked for them by status.
@immutable
class UserCounts {
  const UserCounts({required this.byStatus, required this.total});

  factory UserCounts.fromMap(Map<String, dynamic> map) {
    final raw = (map['byStatus'] as Map<String, dynamic>?) ?? const {};
    return UserCounts(
      byStatus: {
        for (final status in UserStatus.values)
          status: (raw[status.name] as int?) ?? 0,
      },
      total: (map['total'] as int?) ?? 0,
    );
  }

  factory UserCounts.fromJson(String source) =>
      UserCounts.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Count per status; every [UserStatus] is a key.
  final Map<UserStatus, int> byStatus;

  /// Sum of every bucket in [byStatus].
  final int total;

  /// Count for one [status]; zero when the server sent no bucket for it.
  int of(UserStatus status) => byStatus[status] ?? 0;

  UserCounts copyWith({Map<UserStatus, int>? byStatus, int? total}) {
    return UserCounts(
      byStatus: byStatus ?? this.byStatus,
      total: total ?? this.total,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'byStatus': {
        for (final entry in byStatus.entries) entry.key.name: entry.value,
      },
      'total': total,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'UserCounts(byStatus: $byStatus, total: $total)';

  static const _mapEquality = MapEquality<UserStatus, int>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserCounts &&
        _mapEquality.equals(other.byStatus, byStatus) &&
        other.total == total;
  }

  @override
  int get hashCode => _mapEquality.hash(byStatus) ^ total.hashCode;
}
