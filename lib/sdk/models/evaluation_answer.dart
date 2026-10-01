import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'evaluation_evidence.dart';

const evaluationAnswerListEquality = DeepCollectionEquality();

/// One answer of an evaluation, as read (club_server#535, R9).
///
/// Which value field carries the answer depends on the item: [valueNum]
/// for a rating, a number or a Yes / No (1 or 0, see [yesNo]); [valueText]
/// for a Q & A or a single choice; [choices] for a multiple choice. An
/// answer may carry only a [coachNote] or only [evidence]. On the member's
/// view the coach note is written for the member (R39a).
@immutable
class EvaluationAnswer {
  const EvaluationAnswer({
    required this.itemId,
    this.valueNum,
    this.valueText,
    this.choices = const [],
    this.coachNote,
    this.evidence = const [],
  });

  factory EvaluationAnswer.fromMap(Map<String, dynamic> map) {
    return EvaluationAnswer(
      itemId: map['itemId'] as int,
      valueNum: map['valueNum'] as num?,
      valueText: map['valueText'] as String?,
      choices: List<String>.from(
        (map['choices'] as List?) ?? const <String>[],
      ),
      coachNote: map['coachNote'] as String?,
      evidence: ((map['evidence'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationEvidence.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  factory EvaluationAnswer.fromJson(String source) =>
      EvaluationAnswer.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The item this answers.
  final int itemId;
  final num? valueNum;
  final String? valueText;
  final List<String> choices;
  final String? coachNote;
  final List<EvaluationEvidence> evidence;

  /// [valueNum] read as a Yes / No answer: 0 is no, anything else yes.
  bool? get yesNo => valueNum == null ? null : valueNum != 0;

  EvaluationAnswer copyWith({
    int? itemId,
    num? Function()? valueNum,
    String? Function()? valueText,
    List<String>? choices,
    String? Function()? coachNote,
    List<EvaluationEvidence>? evidence,
  }) {
    return EvaluationAnswer(
      itemId: itemId ?? this.itemId,
      valueNum: valueNum != null ? valueNum() : this.valueNum,
      valueText: valueText != null ? valueText() : this.valueText,
      choices: choices ?? this.choices,
      coachNote: coachNote != null ? coachNote() : this.coachNote,
      evidence: evidence ?? this.evidence,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'itemId': itemId,
    'valueNum': valueNum,
    'valueText': valueText,
    'choices': choices,
    'coachNote': coachNote,
    'evidence': evidence.map((e) => e.toMap()).toList(),
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationAnswer(itemId: $itemId, valueNum: $valueNum, '
      'valueText: $valueText, choices: $choices, '
      'evidence: ${evidence.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationAnswer &&
        other.itemId == itemId &&
        other.valueNum == valueNum &&
        other.valueText == valueText &&
        evaluationAnswerListEquality.equals(other.choices, choices) &&
        other.coachNote == coachNote &&
        evaluationAnswerListEquality.equals(other.evidence, evidence);
  }

  @override
  int get hashCode => Object.hash(
    itemId,
    valueNum,
    valueText,
    evaluationAnswerListEquality.hash(choices),
    coachNote,
    evaluationAnswerListEquality.hash(evidence),
  );
}
