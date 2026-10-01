import 'dart:convert';

import 'package:meta/meta.dart';

import 'evaluation_template_item.dart';

/// One item found by the cross-template item search, and the template it
/// lives in (club_server#535, R46a). Copy it into another template by
/// adding it with `originItemId` set to its id (R12b).
@immutable
class EvaluationTemplateItemHit {
  const EvaluationTemplateItemHit({
    required this.templateId,
    required this.templateName,
    required this.item,
  });

  factory EvaluationTemplateItemHit.fromMap(Map<String, dynamic> map) {
    return EvaluationTemplateItemHit(
      templateId: map['templateId'] as int,
      templateName: map['templateName'] as String,
      item: EvaluationTemplateItem.fromMap(
        Map<String, dynamic>.from(map['item'] as Map),
      ),
    );
  }

  factory EvaluationTemplateItemHit.fromJson(String source) =>
      EvaluationTemplateItemHit.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  final int templateId;
  final String templateName;
  final EvaluationTemplateItem item;

  EvaluationTemplateItemHit copyWith({
    int? templateId,
    String? templateName,
    EvaluationTemplateItem? item,
  }) {
    return EvaluationTemplateItemHit(
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      item: item ?? this.item,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'templateId': templateId,
    'templateName': templateName,
    'item': item.toMap(),
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationTemplateItemHit(templateId: $templateId, '
      'templateName: $templateName, item: $item)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationTemplateItemHit &&
        other.templateId == templateId &&
        other.templateName == templateName &&
        other.item == item;
  }

  @override
  int get hashCode => Object.hash(templateId, templateName, item);
}
