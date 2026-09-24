import 'dart:convert';

import 'package:meta/meta.dart';

/// One score category declared by an evaluation template (R10, R12).
///
/// The categories are the validation contract: a score naming a [key] the
/// template does not declare, or a value outside [minValue]..[maxValue],
/// is rejected by the server with 422 `INVALID_SCORE`. [defaultValue]
/// seeds the score when the template is applied. [id] is assigned by the
/// server and is null on a category being sent for creation or update.
@immutable
class EvaluationCategory {
  const EvaluationCategory({
    required this.key,
    required this.label,
    required this.minValue,
    required this.maxValue,
    this.id,
    this.defaultValue,
  });

  factory EvaluationCategory.fromMap(Map<String, dynamic> map) {
    return EvaluationCategory(
      id: map['id'] as int?,
      key: map['key'] as String,
      label: map['label'] as String,
      minValue: map['minValue'] as int,
      maxValue: map['maxValue'] as int,
      defaultValue: map['defaultValue'] as int?,
    );
  }

  factory EvaluationCategory.fromJson(String source) =>
      EvaluationCategory.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Server-assigned id; null on input.
  final int? id;
  final String key;
  final String label;
  final int minValue;
  final int maxValue;
  final int? defaultValue;

  EvaluationCategory copyWith({
    int? Function()? id,
    String? key,
    String? label,
    int? minValue,
    int? maxValue,
    int? Function()? defaultValue,
  }) {
    return EvaluationCategory(
      id: id != null ? id() : this.id,
      key: key ?? this.key,
      label: label ?? this.label,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      defaultValue: defaultValue != null ? defaultValue() : this.defaultValue,
    );
  }

  /// The wire shape. [id] is included only when set, so the same map is
  /// valid as a creation payload.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'key': key,
      'label': label,
      'minValue': minValue,
      'maxValue': maxValue,
      'defaultValue': defaultValue,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationCategory(id: $id, key: $key, label: $label, '
      'minValue: $minValue, maxValue: $maxValue, '
      'defaultValue: $defaultValue)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationCategory &&
        other.id == id &&
        other.key == key &&
        other.label == label &&
        other.minValue == minValue &&
        other.maxValue == maxValue &&
        other.defaultValue == defaultValue;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      key.hashCode ^
      label.hashCode ^
      minValue.hashCode ^
      maxValue.hashCode ^
      defaultValue.hashCode;
}
