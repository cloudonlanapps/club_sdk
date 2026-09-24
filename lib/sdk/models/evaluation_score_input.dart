import 'dart:convert';

import 'package:meta/meta.dart';

/// A score being sent to the server: a category [key] and its [value].
///
/// The server validates it against the evaluation's template (R10); the
/// SDK may pre-check against `EvaluationCategory` bounds for a better form
/// experience but must not treat that as authoritative.
@immutable
class EvaluationScoreInput {
  const EvaluationScoreInput({required this.key, required this.value});

  factory EvaluationScoreInput.fromMap(Map<String, dynamic> map) {
    return EvaluationScoreInput(
      key: map['key'] as String,
      value: map['value'] as int,
    );
  }

  factory EvaluationScoreInput.fromJson(String source) =>
      EvaluationScoreInput.fromMap(json.decode(source) as Map<String, dynamic>);

  final String key;
  final int value;

  EvaluationScoreInput copyWith({String? key, int? value}) {
    return EvaluationScoreInput(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{'key': key, 'value': value};

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'EvaluationScoreInput(key: $key, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationScoreInput &&
        other.key == key &&
        other.value == value;
  }

  @override
  int get hashCode => key.hashCode ^ value.hashCode;
}
