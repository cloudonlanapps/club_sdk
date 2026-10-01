part of 'evaluation_template_item.dart';

/// A question answered in writing, as markdown `valueText`
/// (club_server#535). Unlike the other questions it has no comment area.
@immutable
final class EvaluationQaItem extends EvaluationQuestionItem {
  const EvaluationQaItem({
    required super.question,
    super.id,
    super.isPrivate,
    super.isRequired,
    super.allowEvidence,
    super.originItemId,
  });

  factory EvaluationQaItem.fromMap(Map<String, dynamic> map) {
    return EvaluationQaItem(
      id: map['id'] as int?,
      isPrivate: (map['isPrivate'] as bool?) ?? false,
      question: map['question'] as String,
      isRequired: (map['isRequired'] as bool?) ?? false,
      allowEvidence: (map['allowEvidence'] as bool?) ?? false,
      originItemId: map['originItemId'] as int?,
    );
  }

  @override
  EvaluationItemType get type => EvaluationItemType.qa;

  EvaluationQaItem copyWith({
    int? Function()? id,
    bool? isPrivate,
    String? question,
    bool? isRequired,
    bool? allowEvidence,
    int? Function()? originItemId,
  }) {
    return EvaluationQaItem(
      id: id != null ? id() : this.id,
      isPrivate: isPrivate ?? this.isPrivate,
      question: question ?? this.question,
      isRequired: isRequired ?? this.isRequired,
      allowEvidence: allowEvidence ?? this.allowEvidence,
      originItemId: originItemId != null ? originItemId() : this.originItemId,
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
  };

  @override
  String toString() => 'EvaluationQaItem(id: $id, question: $question)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationQaItem &&
        other.id == id &&
        other.isPrivate == isPrivate &&
        other.question == question &&
        other.isRequired == isRequired &&
        other.allowEvidence == allowEvidence &&
        other.originItemId == originItemId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    isPrivate,
    question,
    isRequired,
    allowEvidence,
    originItemId,
  );
}
