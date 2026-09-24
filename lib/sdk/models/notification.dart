import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Notification channel enumeration.
enum NotificationChannel {
  email,
  push,
  sms,
  otp,
  inApp;

  factory NotificationChannel.fromName(String name) {
    final normalized = name.toLowerCase().replaceAll('_', '');
    if (normalized == 'inapp') return NotificationChannel.inApp;
    return NotificationChannel.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () => NotificationChannel.inApp,
    );
  }
}

/// Server-side categories of actionable notifications. The server filters by
/// these on `GET /notifications/pending-actions` and auto-dismisses entries
/// whose linked domain row reaches a terminal state.
enum PendingActionType {
  groupJoinRequest('group_join_request'),
  enrollmentOpportunity('enrollment_opportunity'),
  enrollmentRequest('enrollment_request'),
  attendanceCorrection('attendance_correction'),
  userApproval('user_approval');

  const PendingActionType(this.wireName);

  final String wireName;

  static PendingActionType? fromWire(String? wire) {
    if (wire == null) return null;
    for (final v in PendingActionType.values) {
      if (v.wireName == wire) return v;
    }
    return null;
  }
}

/// System-level configuration for which notification channels are supported.
///
/// This defines the platform capabilities, not user preferences.
/// For example, if OTP is not supported, the system cannot send OTP messages.
@immutable
class NotificationChannelSupport {
  const NotificationChannelSupport({
    this.emailSupported = true,
    this.pushSupported = true,
    this.smsSupported = false,
    this.otpSupported = false,
    this.inAppSupported = true,
  });

  factory NotificationChannelSupport.fromMap(Map<String, dynamic> map) {
    return NotificationChannelSupport(
      emailSupported: map['emailSupported'] as bool? ?? true,
      pushSupported: map['pushSupported'] as bool? ?? true,
      smsSupported: map['smsSupported'] as bool? ?? false,
      otpSupported: map['otpSupported'] as bool? ?? false,
      inAppSupported: map['inAppSupported'] as bool? ?? true,
    );
  }

  factory NotificationChannelSupport.fromJson(String source) =>
      NotificationChannelSupport.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );
  final bool emailSupported;
  final bool pushSupported;
  final bool smsSupported;
  final bool otpSupported;
  final bool inAppSupported;

  /// Check if a specific channel is supported.
  bool isSupported(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.email:
        return emailSupported;
      case NotificationChannel.push:
        return pushSupported;
      case NotificationChannel.sms:
        return smsSupported;
      case NotificationChannel.otp:
        return otpSupported;
      case NotificationChannel.inApp:
        return inAppSupported;
    }
  }

  /// Get list of all supported channels.
  List<NotificationChannel> get supportedChannels {
    return NotificationChannel.values.where(isSupported).toList();
  }

  NotificationChannelSupport copyWith({
    bool? emailSupported,
    bool? pushSupported,
    bool? smsSupported,
    bool? otpSupported,
    bool? inAppSupported,
  }) {
    return NotificationChannelSupport(
      emailSupported: emailSupported ?? this.emailSupported,
      pushSupported: pushSupported ?? this.pushSupported,
      smsSupported: smsSupported ?? this.smsSupported,
      otpSupported: otpSupported ?? this.otpSupported,
      inAppSupported: inAppSupported ?? this.inAppSupported,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emailSupported': emailSupported,
      'pushSupported': pushSupported,
      'smsSupported': smsSupported,
      'otpSupported': otpSupported,
      'inAppSupported': inAppSupported,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'NotificationChannelSupport(email: $emailSupported, '
        'push: $pushSupported, sms: $smsSupported, '
        'otp: $otpSupported, inApp: $inAppSupported)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationChannelSupport &&
        other.emailSupported == emailSupported &&
        other.pushSupported == pushSupported &&
        other.smsSupported == smsSupported &&
        other.otpSupported == otpSupported &&
        other.inAppSupported == inAppSupported;
  }

  @override
  int get hashCode =>
      emailSupported.hashCode ^
      pushSupported.hashCode ^
      smsSupported.hashCode ^
      otpSupported.hashCode ^
      inAppSupported.hashCode;
}

const payloadEquality = DeepCollectionEquality();

/// A notification sent to a user.
///
/// Uses `username` as FK to `users.username`. The display content lives inside
/// [payload], which follows the server's `{v, type, data}` envelope; `title`
/// and `body` are no longer first-class fields on the row.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.username,
    required this.type,
    required this.channel,
    required this.payload,
    required this.isRead,
    required this.createdAtUtc,
    this.pendingActionType,
    this.pendingActionId,
    this.pendingActionKey,
    this.broadcastId,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as int,
      username: map['username'] as String,
      type: map['type'] as String,
      channel: NotificationChannel.fromName(map['channel'] as String),
      payload: Map<String, dynamic>.from(
        (map['payload'] as Map?) ?? const <String, dynamic>{},
      ),
      pendingActionType: PendingActionType.fromWire(
        map['pendingActionType'] as String?,
      ),
      pendingActionId: map['pendingActionId'] as int?,
      pendingActionKey: map['pendingActionKey'] as String?,
      broadcastId: map['broadcastId'] as int?,
      isRead: map['isRead'] as bool? ?? false,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
    );
  }

  factory AppNotification.fromJson(String source) =>
      AppNotification.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;

  /// FK to users.username - the recipient's username.
  final String username;

  /// Domain.event taxonomy, e.g. `group.created`, `enrollment.invited`.
  final String type;
  final NotificationChannel channel;

  /// `{v, type, data}` envelope. Display strings, deep-link hints, etc. live
  /// inside `data`. Required on every notification.
  final Map<String, dynamic> payload;

  /// Set when this notification requires a user action; null otherwise.
  final PendingActionType? pendingActionType;

  /// FK to the linked domain row referenced by [pendingActionType].
  final int? pendingActionId;

  /// Text key for the linked domain row when it has no integer primary key
  /// (e.g. `users.username` for `user_approval`). Complements
  /// [pendingActionId].
  final String? pendingActionKey;

  /// FK back to the originating broadcast row, when this notification was
  /// fanned out from a broadcast.
  final int? broadcastId;
  final bool isRead;
  final DateTime createdAtUtc;

  AppNotification copyWith({
    int? id,
    String? username,
    String? type,
    NotificationChannel? channel,
    Map<String, dynamic>? payload,
    PendingActionType? Function()? pendingActionType,
    int? Function()? pendingActionId,
    String? Function()? pendingActionKey,
    int? Function()? broadcastId,
    bool? isRead,
    DateTime? createdAtUtc,
  }) {
    return AppNotification(
      id: id ?? this.id,
      username: username ?? this.username,
      type: type ?? this.type,
      channel: channel ?? this.channel,
      payload: payload ?? this.payload,
      pendingActionType: pendingActionType != null
          ? pendingActionType()
          : this.pendingActionType,
      pendingActionId: pendingActionId != null
          ? pendingActionId()
          : this.pendingActionId,
      pendingActionKey: pendingActionKey != null
          ? pendingActionKey()
          : this.pendingActionKey,
      broadcastId: broadcastId != null ? broadcastId() : this.broadcastId,
      isRead: isRead ?? this.isRead,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'type': type,
      'channel': channel.name,
      'payload': payload,
      'pendingActionType': pendingActionType?.wireName,
      'pendingActionId': pendingActionId,
      'pendingActionKey': pendingActionKey,
      'broadcastId': broadcastId,
      'isRead': isRead,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'AppNotification(id: $id, username: $username, '
        'type: $type, channel: $channel, '
        'pendingActionType: $pendingActionType, '
        'pendingActionId: $pendingActionId, '
        'pendingActionKey: $pendingActionKey, broadcastId: $broadcastId, '
        'isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppNotification &&
        other.id == id &&
        other.username == username &&
        other.type == type &&
        other.channel == channel &&
        payloadEquality.equals(other.payload, payload) &&
        other.pendingActionType == pendingActionType &&
        other.pendingActionId == pendingActionId &&
        other.pendingActionKey == pendingActionKey &&
        other.broadcastId == broadcastId &&
        other.isRead == isRead &&
        other.createdAtUtc == createdAtUtc;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      type.hashCode ^
      channel.hashCode ^
      payloadEquality.hash(payload) ^
      pendingActionType.hashCode ^
      pendingActionId.hashCode ^
      pendingActionKey.hashCode ^
      broadcastId.hashCode ^
      isRead.hashCode ^
      createdAtUtc.hashCode;
}

/// User preferences for notification channels.
///
/// Uses `username` as FK to `users.username`.
@immutable
class NotificationPref {
  const NotificationPref({
    required this.username,
    required this.emailEnabled,
    required this.pushEnabled,
    required this.smsEnabled,
  });

  factory NotificationPref.fromMap(Map<String, dynamic> map) {
    return NotificationPref(
      username: map['username'] as String? ?? '',
      emailEnabled: map['emailEnabled'] as bool? ?? true,
      pushEnabled: map['pushEnabled'] as bool? ?? true,
      smsEnabled: map['smsEnabled'] as bool? ?? false,
    );
  }

  factory NotificationPref.fromJson(String source) =>
      NotificationPref.fromMap(json.decode(source) as Map<String, dynamic>);

  /// FK to users.username - the user's username.
  final String username;
  final bool emailEnabled;
  final bool pushEnabled;
  final bool smsEnabled;

  NotificationPref copyWith({
    String? username,
    bool? emailEnabled,
    bool? pushEnabled,
    bool? smsEnabled,
  }) {
    return NotificationPref(
      username: username ?? this.username,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'emailEnabled': emailEnabled,
      'pushEnabled': pushEnabled,
      'smsEnabled': smsEnabled,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'NotificationPref(username: $username, emailEnabled: $emailEnabled, '
        'pushEnabled: $pushEnabled, smsEnabled: $smsEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationPref &&
        other.username == username &&
        other.emailEnabled == emailEnabled &&
        other.pushEnabled == pushEnabled &&
        other.smsEnabled == smsEnabled;
  }

  @override
  int get hashCode =>
      username.hashCode ^
      emailEnabled.hashCode ^
      pushEnabled.hashCode ^
      smsEnabled.hashCode;
}
