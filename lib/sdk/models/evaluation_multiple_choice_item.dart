part of 'evaluation_template_item.dart';

/// A question answered with one or more of its choices, each once, as
/// `choices` (club_server#535).
@immutable
final class EvaluationMultipleChoiceItem extends EvaluationChoiceItem {
  const EvaluationMultipleChoiceItem({
    required super.question,
    required super.choices,
    super.id,
    super.isPrivate,
    super.isRequired,
    super.allowEvidence,
    super.originItemId,
    super.showCommentArea,
    super.requireCommentFor,
  });

  factory EvaluationMultipleChoiceItem.fromMap(Map<String, dynamic> map) {
    return EvaluationMultipleChoiceItem(
      id: map['id'] as int?,
      isPrivate: (map['isPrivate'] as bool?) ?? false,
      question: map['question'] as String,
      isRequired: (map['isRequired'] as bool?) ?? false,
      allowEvidence: (map['allowEvidence'] as bool?) ?? false,
      originItemId: map['originItemId'] as int?,
      showCommentArea: (map['showCommentArea'] as bool?) ?? false,
      requireCommentFor: List<String>.from(
        (map['requireCommentFor'] as List?) ?? const <String>[],
      ),
      choices: ((map['choices'] as List?) ?? const [])
          .map((e) => EvaluationChoice.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  EvaluationItemType get type => EvaluationItemType.multipleChoice;

  EvaluationMultipleChoiceItem copyWith({
    int? Function()? id,
    bool? isPrivate,
    String? question,
    bool? isRequired,
    bool? allowEvidence,
    int? Function()? originItemId,
    bool? showCommentArea,
    List<String>? requireCommentFor,
    List<EvaluationChoice>? choices,
  }) {
    return EvaluationMultipleChoiceItem(
      id: id != null ? id() : this.id,
      isPrivate: isPrivate ?? this.isPrivate,
      question: question ?? this.question,
      isRequired: isRequired ?? this.isRequired,
      allowEvidence: allowEvidence ?? this.allowEvidence,
      originItemId: originItemId != null ? originItemId() : this.originItemId,
      showCommentArea: showCommentArea ?? this.showCommentArea,
      requireCommentFor: requireCommentFor ?? this.requireCommentFor,
      choices: choices ?? this.choices,
    );
  }
}
