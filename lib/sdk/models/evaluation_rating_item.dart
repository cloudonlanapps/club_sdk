part of 'evaluation_template_item.dart';

/// A rating (club_server#535): a range [rateMin]..[rateMax] (1..5 when
/// both are null), optionally shown as [EvaluationRateType.stars], or
/// labelled [rateValues] running 1..n — never both. An answer is a
/// `valueNum` on the scale.
///
/// [requireCommentFor] names the values whose answer needs a coach note,
/// which needs [showCommentArea].
@immutable
final class EvaluationRatingItem extends EvaluationQuestionItem {
  const EvaluationRatingItem({
    required super.question,
    super.id,
    super.isPrivate,
    super.isRequired,
    super.allowEvidence,
    super.originItemId,
    this.showCommentArea = false,
    this.requireCommentFor = const [],
    this.rateType,
    this.rateMin,
    this.rateMax,
    this.rateValues,
  });

  factory EvaluationRatingItem.fromMap(Map<String, dynamic> map) {
    return EvaluationRatingItem(
      id: map['id'] as int?,
      isPrivate: (map['isPrivate'] as bool?) ?? false,
      question: map['question'] as String,
      isRequired: (map['isRequired'] as bool?) ?? false,
      allowEvidence: (map['allowEvidence'] as bool?) ?? false,
      originItemId: map['originItemId'] as int?,
      showCommentArea: (map['showCommentArea'] as bool?) ?? false,
      requireCommentFor: ((map['requireCommentFor'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(growable: false),
      rateType: map['rateType'] != null
          ? EvaluationRateType.fromWire(map['rateType'] as String)
          : null,
      rateMin: (map['rateMin'] as num?)?.toInt(),
      rateMax: (map['rateMax'] as num?)?.toInt(),
      rateValues: (map['rateValues'] as List?)
          ?.map((e) => EvaluationRateLevel.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final bool showCommentArea;
  final List<int> requireCommentFor;
  final EvaluationRateType? rateType;
  final int? rateMin;
  final int? rateMax;
  final List<EvaluationRateLevel>? rateValues;

  @override
  EvaluationItemType get type => EvaluationItemType.rating;

  EvaluationRatingItem copyWith({
    int? Function()? id,
    bool? isPrivate,
    String? question,
    bool? isRequired,
    bool? allowEvidence,
    int? Function()? originItemId,
    bool? showCommentArea,
    List<int>? requireCommentFor,
    EvaluationRateType? Function()? rateType,
    int? Function()? rateMin,
    int? Function()? rateMax,
    List<EvaluationRateLevel>? Function()? rateValues,
  }) {
    return EvaluationRatingItem(
      id: id != null ? id() : this.id,
      isPrivate: isPrivate ?? this.isPrivate,
      question: question ?? this.question,
      isRequired: isRequired ?? this.isRequired,
      allowEvidence: allowEvidence ?? this.allowEvidence,
      originItemId: originItemId != null ? originItemId() : this.originItemId,
      showCommentArea: showCommentArea ?? this.showCommentArea,
      requireCommentFor: requireCommentFor ?? this.requireCommentFor,
      rateType: rateType != null ? rateType() : this.rateType,
      rateMin: rateMin != null ? rateMin() : this.rateMin,
      rateMax: rateMax != null ? rateMax() : this.rateMax,
      rateValues: rateValues != null ? rateValues() : this.rateValues,
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
    'rateType': rateType?.wireName,
    'rateMin': rateMin,
    'rateMax': rateMax,
    'rateValues': rateValues?.map((l) => l.toMap()).toList(),
  };

  @override
  String toString() =>
      'EvaluationRatingItem(id: $id, question: $question, '
      'rateMin: $rateMin, rateMax: $rateMax, rateValues: $rateValues)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationRatingItem &&
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
        other.rateType == rateType &&
        other.rateMin == rateMin &&
        other.rateMax == rateMax &&
        evaluationItemListEquality.equals(other.rateValues, rateValues);
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
    rateType,
    rateMin,
    rateMax,
    evaluationItemListEquality.hash(rateValues),
  );
}
