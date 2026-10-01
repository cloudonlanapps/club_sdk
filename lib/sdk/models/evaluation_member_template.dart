import 'dart:convert';

import 'package:meta/meta.dart';

import 'evaluation_layout_entry.dart';
import 'evaluation_template_item.dart';

/// What the member reads of an evaluation's template (club_server#535,
/// R39): its name, its public [items] in layout order, and the [layout]
/// with private items — and any section they emptied — removed.
@immutable
class EvaluationMemberTemplate {
  const EvaluationMemberTemplate({
    required this.id,
    required this.name,
    required this.layout,
    required this.items,
  });

  factory EvaluationMemberTemplate.fromMap(Map<String, dynamic> map) {
    return EvaluationMemberTemplate(
      id: map['id'] as int,
      name: map['name'] as String,
      layout: EvaluationLayoutEntry.idsFromWire(map['layout'] as List?),
      items: ((map['items'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationTemplateItem.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  factory EvaluationMemberTemplate.fromJson(String source) =>
      EvaluationMemberTemplate.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  final int id;
  final String name;
  final List<EvaluationLayoutEntry<int>> layout;
  final List<EvaluationTemplateItem> items;

  EvaluationMemberTemplate copyWith({
    int? id,
    String? name,
    List<EvaluationLayoutEntry<int>>? layout,
    List<EvaluationTemplateItem>? items,
  }) {
    return EvaluationMemberTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      layout: layout ?? this.layout,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'name': name,
    'layout': layout.map((e) => e.toWire((id) => id)).toList(),
    'items': items.map((i) => i.toMap()).toList(),
  };

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationMemberTemplate(id: $id, name: $name, '
      'items: ${items.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationMemberTemplate &&
        other.id == id &&
        other.name == name &&
        evaluationLayoutEquality.equals(other.layout, layout) &&
        evaluationLayoutEquality.equals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    evaluationLayoutEquality.hash(layout),
    evaluationLayoutEquality.hash(items),
  );
}
