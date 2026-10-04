import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Lifecycle status of an admin-authored broadcast.
enum BroadcastStatus {
  sent('sent'),
  revoked('revoked');

  const BroadcastStatus(this.wireName);

  final String wireName;

  static BroadcastStatus fromWire(String wire) {
    for (final v in BroadcastStatus.values) {
      if (v.wireName == wire) return v;
    }
    return BroadcastStatus.sent;
  }
}

/// Kind of audience selector accepted by `POST /broadcasts`.
enum AudienceKind {
  allUsers('all_users'),
  role('role'),
  group('group'),
  eventMembers('event_members'),
  eventStaff('event_staff'),
  users('users');

  const AudienceKind(this.wireName);

  final String wireName;

  static AudienceKind fromWire(String wire) {
    for (final v in AudienceKind.values) {
      if (v.wireName == wire) return v;
    }
    throw ArgumentError('Unknown audience kind: $wire');
  }
}

const listEquality = ListEquality<String>();

/// Audience selector for a broadcast. Construct via one of the named
/// factories; serialize via [toMap]. The shape matches the server's
/// single flat-object contract (see `BroadcastCreate` in the server).
@immutable
class AudienceSelector {
  const AudienceSelector({
    required this.kind,
    this.role,
    this.groupId,
    this.eventId,
    this.usernames,
  });

  /// `{kind: 'all_users'}`
  const AudienceSelector.allUsers()
    : kind = AudienceKind.allUsers,
      role = null,
      groupId = null,
      eventId = null,
      usernames = null;

  /// `{kind: 'role', role: 'admin'|'coach'}`
  const AudienceSelector.role(this.role)
    : kind = AudienceKind.role,
      groupId = null,
      eventId = null,
      usernames = null;

  /// `{kind: 'group', groupId: <id>}`
  const AudienceSelector.group(this.groupId)
    : kind = AudienceKind.group,
      role = null,
      eventId = null,
      usernames = null;

  /// `{kind: 'event_members', eventId: <id>}`
  const AudienceSelector.eventMembers(this.eventId)
    : kind = AudienceKind.eventMembers,
      role = null,
      groupId = null,
      usernames = null;

  /// `{kind: 'event_staff', eventId: <id>}`
  const AudienceSelector.eventStaff(this.eventId)
    : kind = AudienceKind.eventStaff,
      role = null,
      groupId = null,
      usernames = null;

  /// `{kind: 'users', usernames: [...]}`
  AudienceSelector.users(List<String> usernames)
    : kind = AudienceKind.users,
      role = null,
      groupId = null,
      eventId = null,
      usernames = List<String>.unmodifiable(usernames);

  factory AudienceSelector.fromMap(Map<String, dynamic> map) {
    final kind = AudienceKind.fromWire(map['kind'] as String);
    switch (kind) {
      case AudienceKind.allUsers:
        return const AudienceSelector.allUsers();
      case AudienceKind.role:
        return AudienceSelector.role(map['role'] as String);
      case AudienceKind.group:
        return AudienceSelector.group(map['groupId'] as int);
      case AudienceKind.eventMembers:
        return AudienceSelector.eventMembers(map['eventId'] as int);
      case AudienceKind.eventStaff:
        return AudienceSelector.eventStaff(map['eventId'] as int);
      case AudienceKind.users:
        final raw = (map['usernames'] as List?) ?? const <dynamic>[];
        return AudienceSelector.users(raw.cast<String>());
    }
  }

  final AudienceKind kind;
  final String? role;
  final int? groupId;
  final int? eventId;
  final List<String>? usernames;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'kind': kind.wireName,
      if (role != null) 'role': role,
      if (groupId != null) 'groupId': groupId,
      if (eventId != null) 'eventId': eventId,
      if (usernames != null) 'usernames': usernames,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'AudienceSelector(${toMap()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudienceSelector &&
        other.kind == kind &&
        other.role == role &&
        other.groupId == groupId &&
        other.eventId == eventId &&
        listEquality.equals(other.usernames, usernames);
  }

  @override
  int get hashCode =>
      kind.hashCode ^
      role.hashCode ^
      groupId.hashCode ^
      eventId.hashCode ^
      (usernames == null ? 0 : listEquality.hash(usernames));
}

const payloadEquality = DeepCollectionEquality();

/// Admin-authored broadcast. Carries the fan-out metadata server-side; the
/// [readCount] / [unreadCount] fields are populated only on the detail view
/// (`GET /broadcasts/by_id/{id}`) and remain null on list rows.
@immutable
class Broadcast {
  const Broadcast({
    required this.id,
    required this.audienceSelector,
    required this.payload,
    required this.sentAtUtc,
    required this.status,
    required this.recipientCount,
    this.senderUsername,
    this.expiresAtUtc,
    this.readCount,
    this.unreadCount,
  });

  factory Broadcast.fromMap(Map<String, dynamic> map) {
    return Broadcast(
      id: map['id'] as int,
      senderUsername: map['senderUsername'] as String?,
      audienceSelector: AudienceSelector.fromMap(
        Map<String, dynamic>.from(map['audienceSelector'] as Map),
      ),
      payload: Map<String, dynamic>.from(
        (map['payload'] as Map?) ?? const <String, dynamic>{},
      ),
      sentAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['sentAtUtc'] as int,
        isUtc: true,
      ),
      expiresAtUtc: map['expiresAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['expiresAtUtc'] as int,
              isUtc: true,
            )
          : null,
      status: BroadcastStatus.fromWire(map['status'] as String),
      recipientCount: map['recipientCount'] as int? ?? 0,
      readCount: map['readCount'] as int?,
      unreadCount: map['unreadCount'] as int?,
    );
  }

  factory Broadcast.fromJson(String source) =>
      Broadcast.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String? senderUsername;
  final AudienceSelector audienceSelector;
  final Map<String, dynamic> payload;
  final DateTime sentAtUtc;
  final DateTime? expiresAtUtc;
  final BroadcastStatus status;
  final int recipientCount;

  /// Populated only on the detail view; null on list rows.
  final int? readCount;

  /// Populated only on the detail view; null on list rows.
  final int? unreadCount;

  Broadcast copyWith({
    int? id,
    String? Function()? senderUsername,
    AudienceSelector? audienceSelector,
    Map<String, dynamic>? payload,
    DateTime? sentAtUtc,
    DateTime? Function()? expiresAtUtc,
    BroadcastStatus? status,
    int? recipientCount,
    int? Function()? readCount,
    int? Function()? unreadCount,
  }) {
    return Broadcast(
      id: id ?? this.id,
      senderUsername: senderUsername != null
          ? senderUsername()
          : this.senderUsername,
      audienceSelector: audienceSelector ?? this.audienceSelector,
      payload: payload ?? this.payload,
      sentAtUtc: sentAtUtc ?? this.sentAtUtc,
      expiresAtUtc: expiresAtUtc != null ? expiresAtUtc() : this.expiresAtUtc,
      status: status ?? this.status,
      recipientCount: recipientCount ?? this.recipientCount,
      readCount: readCount != null ? readCount() : this.readCount,
      unreadCount: unreadCount != null ? unreadCount() : this.unreadCount,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'senderUsername': senderUsername,
      'audienceSelector': audienceSelector.toMap(),
      'payload': payload,
      'sentAtUtc': sentAtUtc.millisecondsSinceEpoch,
      'expiresAtUtc': expiresAtUtc?.millisecondsSinceEpoch,
      'status': status.wireName,
      'recipientCount': recipientCount,
      'readCount': readCount,
      'unreadCount': unreadCount,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'Broadcast(id: $id, status: $status, '
      'recipientCount: $recipientCount, '
      'readCount: $readCount, unreadCount: $unreadCount)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Broadcast &&
        other.id == id &&
        other.senderUsername == senderUsername &&
        other.audienceSelector == audienceSelector &&
        payloadEquality.equals(other.payload, payload) &&
        other.sentAtUtc == sentAtUtc &&
        other.expiresAtUtc == expiresAtUtc &&
        other.status == status &&
        other.recipientCount == recipientCount &&
        other.readCount == readCount &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      senderUsername.hashCode ^
      audienceSelector.hashCode ^
      payloadEquality.hash(payload) ^
      sentAtUtc.hashCode ^
      expiresAtUtc.hashCode ^
      status.hashCode ^
      recipientCount.hashCode ^
      readCount.hashCode ^
      unreadCount.hashCode;
}

/// One row in `GET /broadcasts/by_id/{id}/recipients`.
@immutable
class BroadcastRecipient {
  const BroadcastRecipient({
    required this.username,
    required this.isRead,
    required this.createdAtUtc,
  });

  factory BroadcastRecipient.fromMap(Map<String, dynamic> map) {
    return BroadcastRecipient(
      username: map['username'] as String,
      isRead: map['isRead'] as bool? ?? false,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
    );
  }

  factory BroadcastRecipient.fromJson(String source) =>
      BroadcastRecipient.fromMap(json.decode(source) as Map<String, dynamic>);

  final String username;
  final bool isRead;
  final DateTime createdAtUtc;

  BroadcastRecipient copyWith({
    String? username,
    bool? isRead,
    DateTime? createdAtUtc,
  }) {
    return BroadcastRecipient(
      username: username ?? this.username,
      isRead: isRead ?? this.isRead,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'username': username,
      'isRead': isRead,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'BroadcastRecipient(username: $username, isRead: $isRead)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BroadcastRecipient &&
        other.username == username &&
        other.isRead == isRead &&
        other.createdAtUtc == createdAtUtc;
  }

  @override
  int get hashCode =>
      username.hashCode ^ isRead.hashCode ^ createdAtUtc.hashCode;
}
