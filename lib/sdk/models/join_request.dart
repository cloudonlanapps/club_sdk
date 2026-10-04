import 'dart:convert';

import 'package:meta/meta.dart';

/// Lifecycle state of a group join request.
///
/// Mirrors the server's `GroupJoinRequest.status` column.
enum JoinRequestStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static JoinRequestStatus fromWire(String value) {
    return JoinRequestStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => throw ArgumentError.value(
        value,
        'value',
        'Unknown JoinRequestStatus',
      ),
    );
  }
}

/// A single member-submitted request to join a group.
///
/// Used both by the admin-facing triage flow (list / approve / reject) and by
/// the member-facing mygroups flow (submit / list-own / cancel).
@immutable
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.username,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedBy,
    this.reason,
  });

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    return JoinRequest(
      id: map['id'] as int,
      groupId: map['groupId'] as int,
      groupName: map['groupName'] as String,
      username: map['username'] as String,
      status: JoinRequestStatus.fromWire(map['status'] as String),
      requestedAt: map['requestedAt'] as int,
      decidedAt: map['decidedAt'] as int?,
      decidedBy: map['decidedBy'] as String?,
      reason: map['reason'] as String?,
    );
  }

  factory JoinRequest.fromJson(String source) =>
      JoinRequest.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final int groupId;
  final String groupName;
  final String username;
  final JoinRequestStatus status;
  final int requestedAt;
  final int? decidedAt;
  final String? decidedBy;
  final String? reason;

  JoinRequest copyWith({
    int? id,
    int? groupId,
    String? groupName,
    String? username,
    JoinRequestStatus? status,
    int? requestedAt,
    int? Function()? decidedAt,
    String? Function()? decidedBy,
    String? Function()? reason,
  }) {
    return JoinRequest(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      username: username ?? this.username,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      decidedAt: decidedAt != null ? decidedAt() : this.decidedAt,
      decidedBy: decidedBy != null ? decidedBy() : this.decidedBy,
      reason: reason != null ? reason() : this.reason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'groupName': groupName,
      'username': username,
      'status': status.name,
      'requestedAt': requestedAt,
      'decidedAt': decidedAt,
      'decidedBy': decidedBy,
      'reason': reason,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'JoinRequest(id: $id, groupId: $groupId, groupName: $groupName, '
      'username: $username, status: ${status.name})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is JoinRequest &&
        other.id == id &&
        other.groupId == groupId &&
        other.groupName == groupName &&
        other.username == username &&
        other.status == status &&
        other.requestedAt == requestedAt &&
        other.decidedAt == decidedAt &&
        other.decidedBy == decidedBy &&
        other.reason == reason;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      groupId.hashCode ^
      groupName.hashCode ^
      username.hashCode ^
      status.hashCode ^
      requestedAt.hashCode ^
      decidedAt.hashCode ^
      decidedBy.hashCode ^
      reason.hashCode;
}
