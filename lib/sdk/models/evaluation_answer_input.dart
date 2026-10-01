import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// An answer being written to one item of a draft (club_server#535, R9,
/// R10), replacing any earlier one.
///
/// Give the value in the field the item's type uses — [valueNum] for a
/// rating, a number or a Yes / No ([EvaluationAnswerInput.yesNo]);
/// [valueText] for a Q & A or a single choice; [choices] for a multiple
/// choice — and optionally a [coachNote], or the note alone. The server
/// validates it against the item (422 `INVALID_ANSWER`). Only the fields
/// given are sent.
@immutable
class EvaluationAnswerInput {
  const EvaluationAnswerInput({
    this.valueNum,
    this.valueText,
    this.choices,
    this.coachNote,
  });

  /// A Yes / No answer: 1 for yes, 0 for no.
  const EvaluationAnswerInput.yesNo({required bool yes, this.coachNote})
    : valueNum = yes ? yesValue : noValue,
      valueText = null,
      choices = null;

  factory EvaluationAnswerInput.fromMap(Map<String, dynamic> map) {
    return EvaluationAnswerInput(
      valueNum: map['valueNum'] as num?,
      valueText: map['valueText'] as String?,
      choices: map['choices'] != null
          ? List<String>.from(map['choices'] as List)
          : null,
      coachNote: map['coachNote'] as String?,
    );
  }

  factory EvaluationAnswerInput.fromJson(String source) =>
      EvaluationAnswerInput.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  /// The `valueNum` of a yes.
  static const yesValue = 1;

  /// The `valueNum` of a no.
  static const noValue = 0;

  final num? valueNum;
  final String? valueText;
  final List<String>? choices;
  final String? coachNote;

  EvaluationAnswerInput copyWith({
    num? Function()? valueNum,
    String? Function()? valueText,
    List<String>? Function()? choices,
    String? Function()? coachNote,
  }) {
    return EvaluationAnswerInput(
      valueNum: valueNum != null ? valueNum() : this.valueNum,
      valueText: valueText != null ? valueText() : this.valueText,
      choices: choices != null ? choices() : this.choices,
      coachNote: coachNote != null ? coachNote() : this.coachNote,
    );
  }

  /// The request body: only the fields given.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'valueNum': ?valueNum,
    'valueText': ?valueText,
    'choices': ?choices,
    'coachNote': ?coachNote,
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationAnswerInput(valueNum: $valueNum, valueText: $valueText, '
      'choices: $choices, coachNote: $coachNote)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationAnswerInput &&
        other.valueNum == valueNum &&
        other.valueText == valueText &&
        const ListEquality<String>().equals(other.choices, choices) &&
        other.coachNote == coachNote;
  }

  @override
  int get hashCode => Object.hash(
    valueNum,
    valueText,
    const ListEquality<String>().hash(choices),
    coachNote,
  );
}
