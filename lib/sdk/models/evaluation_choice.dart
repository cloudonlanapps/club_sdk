import 'dart:convert';

import 'package:meta/meta.dart';

/// One choice of a single- or multiple-choice item (club_server#535).
///
/// An answer names the [value]; [text] is what the reader sees. Values are
/// unique within an item, and a copy of an item keeps its values (R12b).
@immutable
class EvaluationChoice {
  const EvaluationChoice({required this.value, required this.text});

  factory EvaluationChoice.fromMap(Map<String, dynamic> map) {
    return EvaluationChoice(
      value: map['value'] as String,
      text: map['text'] as String,
    );
  }

  factory EvaluationChoice.fromJson(String source) =>
      EvaluationChoice.fromMap(json.decode(source) as Map<String, dynamic>);

  final String value;
  final String text;

  EvaluationChoice copyWith({String? value, String? text}) {
    return EvaluationChoice(
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
  String toString() => 'EvaluationChoice(value: $value, text: $text)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationChoice &&
        other.value == value &&
        other.text == text;
  }

  @override
  int get hashCode => value.hashCode ^ text.hashCode;
}
