part of 'evaluation_template_item.dart';

/// A question answered with any number, as `valueNum` (club_server#535).
/// [requireCommentFor] names the values whose answer needs a coach note.
@immutable
final class EvaluationNumberItem extends EvaluationQuestionItem {
  const EvaluationNumberItem({
    required super.question,
    super.id,
    super.isPrivate,
    super.isRequired,
    super.allowEvidence,
    super.originItemId,
    this.showCommentArea = false,
    this.requireCommentFor = const [],
  });

  factory EvaluationNumberItem.fromMap(Map<String, dynamic> map) {
    return EvaluationNumberItem(
      id: map['id'] as int?,
      isPrivate: (map['isPrivate'] as bool?) ?? false,
      question: map['question'] as String,
      isRequired: (map['isRequired'] as bool?) ?? false,
      allowEvidence: (map['allowEvidence'] as bool?) ?? false,
      originItemId: map['originItemId'] as int?,
      showCommentArea: (map['showCommentArea'] as bool?) ?? false,
      requireCommentFor: List<num>.from(
        (map['requireCommentFor'] as List?) ?? const <num>[],
      ),
    );
  }

  final bool showCommentArea;
  final List<num> requireCommentFor;

  @override
  EvaluationItemType get type => EvaluationItemType.number;

  EvaluationNumberItem copyWith({
    int? Function()? id,
    bool? isPrivate,
    String? question,
    bool? isRequired,
    bool? allowEvidence,
    int? Function()? originItemId,
    bool? showCommentArea,
    List<num>? requireCommentFor,
  }) {
    return EvaluationNumberItem(
      id: id != null ? id() : this.id,
      isPrivate: isPrivate ?? this.isPrivate,
      question: question ?? this.question,
      isRequired: isRequired ?? this.isRequired,
      allowEvidence: allowEvidence ?? this.allowEvidence,
      originItemId: originItemId != null ? originItemId() : this.originItemId,
      showCommentArea: showCommentArea ?? this.showCommentArea,
      requireCommentFor: requireCommentFor ?? this.requireCommentFor,
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
  };

  @override
  String toString() => 'EvaluationNumberItem(id: $id, question: $question)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationNumberItem &&
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
        );
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
  );
}
