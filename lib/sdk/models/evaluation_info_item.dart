part of 'evaluation_template_item.dart';

/// Markdown shown to the reader; it asks nothing and takes no answer
/// (club_server#535). It has no question fields and is never a copy.
@immutable
final class EvaluationInfoItem extends EvaluationTemplateItem {
  const EvaluationInfoItem({required this.markdown, super.id, super.isPrivate});

  factory EvaluationInfoItem.fromMap(Map<String, dynamic> map) {
    return EvaluationInfoItem(
      id: map['id'] as int?,
      isPrivate: (map['isPrivate'] as bool?) ?? false,
      markdown: map['markdown'] as String,
    );
  }

  final String markdown;

  @override
  EvaluationItemType get type => EvaluationItemType.info;

  EvaluationInfoItem copyWith({
    int? Function()? id,
    bool? isPrivate,
    String? markdown,
  }) {
    return EvaluationInfoItem(
      id: id != null ? id() : this.id,
      isPrivate: isPrivate ?? this.isPrivate,
      markdown: markdown ?? this.markdown,
    );
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'isPrivate': isPrivate,
    'type': type.wireName,
    'markdown': markdown,
  };

  @override
  String toString() => 'EvaluationInfoItem(id: $id)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationInfoItem &&
        other.id == id &&
        other.isPrivate == isPrivate &&
        other.markdown == markdown;
  }

  @override
  int get hashCode => Object.hash(id, isPrivate, markdown);
}
