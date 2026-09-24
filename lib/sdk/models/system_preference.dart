import 'dart:convert';

import 'package:meta/meta.dart';

/// A single server-side system preference (`/v1/admin/preferences`).
///
/// `value` is deliberately untyped: the server stores each preference as an
/// opaque JSON value, so its shape depends on the key. Callers narrow it.
@immutable
class SystemPreference {
  const SystemPreference({
    required this.key,
    required this.value,
    required this.updatedAtUtc,
    this.updatedBy,
  });

  factory SystemPreference.fromMap(Map<String, dynamic> map) {
    return SystemPreference(
      key: map['key'] as String,
      value: map['value'],
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAtUtc'] as int,
        isUtc: true,
      ),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  factory SystemPreference.fromJson(String source) =>
      SystemPreference.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Preference key, unique server-side.
  final String key;

  /// Stored value. Opaque JSON — shape depends on [key].
  final Object? value;

  /// When the preference was last written.
  final DateTime updatedAtUtc;

  /// Username of the admin who last wrote it, if recorded.
  final String? updatedBy;

  SystemPreference copyWith({
    String? key,
    Object? Function()? value,
    DateTime? updatedAtUtc,
    String? Function()? updatedBy,
  }) {
    return SystemPreference(
      key: key ?? this.key,
      value: value != null ? value() : this.value,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      updatedBy: updatedBy != null ? updatedBy() : this.updatedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'SystemPreference(key: $key, value: $value, '
        'updatedAtUtc: $updatedAtUtc, updatedBy: $updatedBy)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SystemPreference &&
        other.key == key &&
        other.value == value &&
        other.updatedAtUtc == updatedAtUtc &&
        other.updatedBy == updatedBy;
  }

  @override
  int get hashCode =>
      Object.hash(key, value, updatedAtUtc, updatedBy);
}
