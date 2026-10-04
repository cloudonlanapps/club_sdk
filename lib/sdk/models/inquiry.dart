import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'inquiry_kind.dart';

const _extraEquality = DeepCollectionEquality();

/// One row of the admin inquiry inbox (club_server#407, #35).
///
/// The row is PII and carries no source hash: the server withholds the
/// submitter's address hash from this projection. [handledAtUtc] and
/// [handledBy] are set together when an admin marks it handled and cleared
/// together when they reopen it.
@immutable
class Inquiry {
  const Inquiry({
    required this.id,
    required this.kind,
    required this.name,
    required this.email,
    required this.message,
    required this.createdAtUtc,
    this.phone,
    this.extra,
    this.handledAtUtc,
    this.handledBy,
  });

  factory Inquiry.fromMap(Map<String, dynamic> map) {
    final handledAt = map['handledAt'];
    return Inquiry(
      id: map['id'] as int,
      kind: InquiryKind.fromWire(map['kind'] as String),
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String?,
      message: map['message'] as String,
      extra: map['extra'] != null
          ? Map<String, dynamic>.from(map['extra'] as Map)
          : null,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      handledAtUtc: handledAt is int
          ? DateTime.fromMillisecondsSinceEpoch(handledAt, isUtc: true)
          : null,
      handledBy: map['handledBy'] as String?,
    );
  }

  factory Inquiry.fromJson(String source) =>
      Inquiry.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final InquiryKind kind;
  final String name;
  final String email;
  final String? phone;
  final String message;

  /// Whatever the form carried beyond the named fields.
  final Map<String, dynamic>? extra;

  final DateTime createdAtUtc;

  /// When an admin marked it handled; null while it is open.
  final DateTime? handledAtUtc;

  /// The admin who marked it handled.
  final String? handledBy;

  /// Open until an admin marks it handled.
  bool get isHandled => handledAtUtc != null;

  Inquiry copyWith({
    int? id,
    InquiryKind? kind,
    String? name,
    String? email,
    String? Function()? phone,
    String? message,
    Map<String, dynamic>? Function()? extra,
    DateTime? createdAtUtc,
    DateTime? Function()? handledAtUtc,
    String? Function()? handledBy,
  }) {
    return Inquiry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone != null ? phone() : this.phone,
      message: message ?? this.message,
      extra: extra != null ? extra() : this.extra,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      handledAtUtc: handledAtUtc != null ? handledAtUtc() : this.handledAtUtc,
      handledBy: handledBy != null ? handledBy() : this.handledBy,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind.wireName,
    'name': name,
    'email': email,
    'phone': phone,
    'message': message,
    'extra': extra,
    'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
    'handledAt': handledAtUtc?.millisecondsSinceEpoch,
    'handledBy': handledBy,
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'Inquiry(id: $id, kind: ${kind.wireName}, name: $name, '
      'handled: $isHandled)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Inquiry &&
        other.id == id &&
        other.kind == kind &&
        other.name == name &&
        other.email == email &&
        other.phone == phone &&
        other.message == message &&
        _extraEquality.equals(other.extra, extra) &&
        other.createdAtUtc == createdAtUtc &&
        other.handledAtUtc == handledAtUtc &&
        other.handledBy == handledBy;
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    email,
    phone,
    message,
    _extraEquality.hash(extra),
    createdAtUtc,
    handledAtUtc,
    handledBy,
  );
}
