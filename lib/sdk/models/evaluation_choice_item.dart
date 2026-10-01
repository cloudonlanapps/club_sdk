part of 'evaluation_template_item.dart';

/// A question answered from its [choices] (club_server#535):
/// [EvaluationSingleChoiceItem] takes one, as `valueText`;
/// [EvaluationMultipleChoiceItem] one or more, as `choices`. Choice values
/// are unique; [requireCommentFor] names the values whose answer needs a
/// coach note.
@immutable
sealed class EvaluationChoiceItem extends EvaluationQuestionItem {
  const EvaluationChoiceItem({
    required super.question,
    required this.choices,
    super.id,
    super.isPrivate,
    super.isRequired,
    super.allowEvidence,
    super.originItemId,
    this.showCommentArea = false,
    this.requireCommentFor = const [],
  });

  final List<EvaluationChoice> choices;
  final bool showCommentArea;
  final List<String> requireCommentFor;

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'isPrivate': isPrivate,
    'question': question,
    'isRequired': isRequired,
    'allowEvidence': allowEvidence,
    'originItemId': originItemId,
    'type': type.wireName,
    'showCommentArea': showCommentArea,
    'requireCommentFor': requireCommentFor,
    'choices': choices.map((c) => c.toMap()).toList(),
  };

  @override
  String toString() =>
      'EvaluationChoiceItem(type: ${type.wireName}, id: $id, '
      'question: $question, choices: $choices)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationChoiceItem &&
        other.type == type &&
        other.id == id &&
        other.isPrivate == isPrivate &&
        other.question == question &&
        other.isRequired == isRequired &&
        other.allowEvidence == allowEvidence &&
        other.originItemId == originItemId &&
        other.showCommentArea == showCommentArea &&
        evaluationItemListEquality.equals(
          other.requireCommentFor,
          requireCommentFor,
        ) &&
        evaluationItemListEquality.equals(other.choices, choices);
  }

  @override
  int get hashCode => Object.hash(
    type,
    id,
    isPrivate,
    question,
    isRequired,
    allowEvidence,
    originItemId,
    showCommentArea,
    evaluationItemListEquality.hash(requireCommentFor),
    evaluationItemListEquality.hash(choices),
  );
}
