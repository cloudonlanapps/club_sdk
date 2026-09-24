import 'dart:convert';

import 'package:meta/meta.dart';

/// Aggregated user statistics for the admin dashboard.
///
/// Counts are fetched independently of the user list filter so they remain
/// stable regardless of the currently applied filter.
@immutable
class UserStats {
  const UserStats({
    required this.total,
    required this.active,
    required this.pending,
    required this.blocked,
    required this.left,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      total: map['total'] as int? ?? 0,
      active: map['active'] as int? ?? 0,
      pending: map['pending'] as int? ?? 0,
      blocked: map['blocked'] as int? ?? 0,
      left: map['left'] as int? ?? 0,
    );
  }

  factory UserStats.fromJson(String source) =>
      UserStats.fromMap(json.decode(source) as Map<String, dynamic>);

  final int total;
  final int active;
  final int pending;
  final int blocked;
  final int left;

  UserStats copyWith({
    int? total,
    int? active,
    int? pending,
    int? blocked,
    int? left,
  }) {
    return UserStats(
      total: total ?? this.total,
      active: active ?? this.active,
      pending: pending ?? this.pending,
      blocked: blocked ?? this.blocked,
      left: left ?? this.left,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'active': active,
      'pending': pending,
      'blocked': blocked,
      'left': left,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'UserStats(total: $total, active: $active, '
        'pending: $pending, blocked: $blocked, left: $left)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserStats &&
        other.total == total &&
        other.active == active &&
        other.pending == pending &&
        other.blocked == blocked &&
        other.left == left;
  }

  @override
  int get hashCode =>
      total.hashCode ^
      active.hashCode ^
      pending.hashCode ^
      blocked.hashCode ^
      left.hashCode;
}
