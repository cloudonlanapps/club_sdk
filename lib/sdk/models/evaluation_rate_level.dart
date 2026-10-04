import 'dart:convert';

import 'package:meta/meta.dart';

/// One labelled level of a rating (club_server#535). A rating's levels run
/// 1..n in order; an answer is the level's [value].
@immutable
class EvaluationRateLevel {
  const EvaluationRateLevel({required this.value, required this.text});

  factory EvaluationRateLevel.fromMap(Map<String, dynamic> map) {
    return EvaluationRateLevel(
      value: (map['value'] as num).toInt(),
      text: map['text'] as String,
    );
  }

  factory EvaluationRateLevel.fromJson(String source) =>
      EvaluationRateLevel.fromMap(json.decode(source) as Map<String, dynamic>);

  final int value;
  final String text;

  EvaluationRateLevel copyWith({int? value, String? text}) {
    return EvaluationRateLevel(
      value: value ?? this.value,
      text: text ?? this.text,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'value': value,
    'text': text,
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'EvaluationRateLevel(value: $value, text: $text)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationRateLevel &&
        other.value == value &&
        other.text == text;
  }

  @override
  int get hashCode => value.hashCode ^ text.hashCode;
}
