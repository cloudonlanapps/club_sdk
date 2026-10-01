part of 'evaluation_template_item.dart';

/// A Yes / No question (club_server#535). An answer is a `valueNum` of 1
/// for yes and 0 for no (`EvaluationAnswerInput.yesNo`). [labelTrue] and
/// [labelFalse] replace the words shown; [requireCommentFor] names the
/// answers that need a coach note.
@immutable
final class EvaluationYesNoItem extends EvaluationQuestionItem {
  const EvaluationYesNoItem({
    required super.question,
    super.id,
    super.isPrivate,
    super.isRequired,
    super.allowEvidence,
    super.originItemId,
    this.showCommentArea = false,
    this.requireCommentFor = const [],
    this.labelTrue,
    this.labelFalse,
  });

  factory EvaluationYesNoItem.fromMap(Map<String, dynamic> map) {
    return EvaluationYesNoItem(
      id: map['id'] as int?,
      isPrivate: (map['isPrivate'] as bool?) ?? false,
      question: map['question'] as String,
      isRequired: (map['isRequired'] as bool?) ?? false,
      allowEvidence: (map['allowEvidence'] as bool?) ?? false,
      originItemId: map['originItemId'] as int?,
      showCommentArea: (map['showCommentArea'] as bool?) ?? false,
      requireCommentFor: List<bool>.from(
        (map['requireCommentFor'] as List?) ?? const <bool>[],
      ),
      labelTrue: map['labelTrue'] as String?,
      labelFalse: map['labelFalse'] as String?,
    );
  }

  final bool showCommentArea;
  final List<bool> requireCommentFor;
  final String? labelTrue;
  final String? labelFalse;

  @override
  EvaluationItemType get type => EvaluationItemType.yesNo;

  EvaluationYesNoItem copyWith({
    int? Function()? id,
    bool? isPrivate,
    String? question,
    bool? isRequired,
    bool? allowEvidence,
    int? Function()? originItemId,
    bool? showCommentArea,
    List<bool>? requireCommentFor,
    String? Function()? labelTrue,
    String? Function()? labelFalse,
  }) {
    return EvaluationYesNoItem(
      id: id != null ? id() : this.id,
      isPrivate: isPrivate ?? this.isPrivate,
      question: question ?? this.question,
      isRequired: isRequired ?? this.isRequired,
      allowEvidence: allowEvidence ?? this.allowEvidence,
      originItemId: originItemId != null ? originItemId() : this.originItemId,
      showCommentArea: showCommentArea ?? this.showCommentArea,
      requireCommentFor: requireCommentFor ?? this.requireCommentFor,
      labelTrue: labelTrue != null ? labelTrue() : this.labelTrue,
      labelFalse: labelFalse != null ? labelFalse() : this.labelFalse,
    );
  }

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
    'labelTrue': labelTrue,
    'labelFalse': labelFalse,
  };

  @override
  String toString() => 'EvaluationYesNoItem(id: $id, question: $question)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationYesNoItem &&
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
        other.labelTrue == labelTrue &&
        other.labelFalse == labelFalse;
  }

  @override
  int get hashCode => Object.hash(
    id,
    isPrivate,
    question,
    isRequired,
    allowEvidence,
    originItemId,
    showCommentArea,
    evaluationItemListEquality.hash(requireCommentFor),
    labelTrue,
    labelFalse,
  );
}
