import 'dart:convert';

import 'package:meta/meta.dart';

import 'enums.dart';

/// Unified Enrollment model for event series enrollment.
///
/// Represents a user's enrollment in an event series, tracking their status,
/// type (regular/trial), and related metadata.
///
/// Uses `membername` as FK to `users.username`. User details (name, email)
/// should be queried via JOIN with the users table when needed.
@immutable
class Enrollment {
  const Enrollment({
    required this.id,
    required this.membername,
    required this.eventId,
    required this.status,
    required this.createdAtUtc,
    this.isTrial = false,
    this.previousStatus,
    this.withdrawalReason,
    this.updatedAtUtc,
    this.enrolledAtUtc,
    this.withdrawnAtUtc,
  });

  factory Enrollment.fromMap(Map<String, dynamic> map) {
    return Enrollment(
      id: map['id'] as int,
      membername: map['membername'] as String,
      eventId: map['eventId'] as int,
      status: EnrollmentStatus.values.byName(map['status'] as String),
      isTrial: map['isTrial'] as bool? ?? false,
      previousStatus: map['previousStatus'] as String?,
      withdrawalReason: map['withdrawalReason'] as String?,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      updatedAtUtc: map['updatedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['updatedAtUtc'] as int,
              isUtc: true,
            )
          : null,
      enrolledAtUtc: map['enrolledAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['enrolledAtUtc'] as int,
              isUtc: true,
            )
          : null,
      withdrawnAtUtc: map['withdrawnAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['withdrawnAtUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory Enrollment.fromJson(String source) =>
      Enrollment.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;

  /// FK to users.username - the enrolled member's username.
  final String membername;
  final int eventId;
  final EnrollmentStatus status;
  final bool isTrial;
  final String? previousStatus;
  final String? withdrawalReason;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;

  /// When the user became actively enrolled (accepted, assigned, etc.).
  final DateTime? enrolledAtUtc;

  /// When the user withdrew or was removed from the enrollment.
  final DateTime? withdrawnAtUtc;

  Enrollment copyWith({
    int? id,
    String? membername,
    int? eventId,
    EnrollmentStatus? status,
    bool? isTrial,
    String? Function()? previousStatus,
    String? Function()? withdrawalReason,
    DateTime? createdAtUtc,
    DateTime? Function()? updatedAtUtc,
    DateTime? Function()? enrolledAtUtc,
    DateTime? Function()? withdrawnAtUtc,
  }) {
    return Enrollment(
      id: id ?? this.id,
      membername: membername ?? this.membername,
      eventId: eventId ?? this.eventId,
      status: status ?? this.status,
      isTrial: isTrial ?? this.isTrial,
      previousStatus: previousStatus != null
          ? previousStatus()
          : this.previousStatus,
      withdrawalReason: withdrawalReason != null
          ? withdrawalReason()
          : this.withdrawalReason,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc != null ? updatedAtUtc() : this.updatedAtUtc,
      enrolledAtUtc: enrolledAtUtc != null
          ? enrolledAtUtc()
          : this.enrolledAtUtc,
      withdrawnAtUtc: withdrawnAtUtc != null
          ? withdrawnAtUtc()
          : this.withdrawnAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'membername': membername,
      'eventId': eventId,
      'status': status.name,
      'isTrial': isTrial,
      'previousStatus': previousStatus,
      'withdrawalReason': withdrawalReason,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc?.millisecondsSinceEpoch,
      'enrolledAtUtc': enrolledAtUtc?.millisecondsSinceEpoch,
      'withdrawnAtUtc': withdrawnAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'Enrollment(id: $id, membername: $membername, eventId: $eventId, '
        'status: $status, isTrial: $isTrial)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Enrollment &&
        other.id == id &&
        other.membername == membername &&
        other.eventId == eventId &&
        other.status == status &&
        other.isTrial == isTrial &&
        other.previousStatus == previousStatus &&
        other.withdrawalReason == withdrawalReason &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.enrolledAtUtc == enrolledAtUtc &&
        other.withdrawnAtUtc == withdrawnAtUtc;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        membername.hashCode ^
        eventId.hashCode ^
        status.hashCode ^
        isTrial.hashCode ^
        previousStatus.hashCode ^
        withdrawalReason.hashCode ^
        createdAtUtc.hashCode ^
        updatedAtUtc.hashCode ^
        enrolledAtUtc.hashCode ^
        withdrawnAtUtc.hashCode;
  }
}
