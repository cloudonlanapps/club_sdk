import 'dart:convert';

import 'package:meta/meta.dart';

/// One score on an evaluation as the server returns it (R10).
///
/// Carries the category [label] and the [minValue]..[maxValue] bounds the
/// [value] was validated against, so a client can render the score without
/// fetching the template. To send a score use `EvaluationScoreInput`.
@immutable
class EvaluationScore {
  const EvaluationScore({
    required this.key,
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
  });

  factory EvaluationScore.fromMap(Map<String, dynamic> map) {
    return EvaluationScore(
      key: map['key'] as String,
      label: map['label'] as String,
      value: map['value'] as int,
      minValue: map['minValue'] as int,
      maxValue: map['maxValue'] as int,
    );
  }

  factory EvaluationScore.fromJson(String source) =>
      EvaluationScore.fromMap(json.decode(source) as Map<String, dynamic>);

  final String key;
  final String label;
  final int value;
  final int minValue;
  final int maxValue;

  EvaluationScore copyWith({
    String? key,
    String? label,
    int? value,
    int? minValue,
    int? maxValue,
  }) {
    return EvaluationScore(
      key: key ?? this.key,
      label: label ?? this.label,
      value: value ?? this.value,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'key': key,
      'label': label,
      'value': value,
      'minValue': minValue,
      'maxValue': maxValue,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationScore(key: $key, label: $label, value: $value, '
      'minValue: $minValue, maxValue: $maxValue)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationScore &&
        other.key == key &&
        other.label == label &&
        other.value == value &&
        other.minValue == minValue &&
        other.maxValue == maxValue;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      label.hashCode ^
      value.hashCode ^
      minValue.hashCode ^
      maxValue.hashCode;
}
