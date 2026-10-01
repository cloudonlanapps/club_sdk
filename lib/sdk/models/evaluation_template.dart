import 'dart:convert';

import 'package:meta/meta.dart';

import 'evaluation_layout_entry.dart';
import 'evaluation_template_item.dart';

/// A template: a [name], its [items] and their [layout] (club_server#535,
/// R12, R12c, R49).
///
/// The items are the contract every evaluation's answers are validated
/// against. [layout] names each item id exactly once, at the top level or
/// in a section; [items] come in layout order. While any evaluation uses
/// the template its items and layout are frozen (422 `TEMPLATE_IN_USE`);
/// renaming stays allowed; [inUse] says so up front (R27a). [deletedAtUtc]
/// is set only on soft-deleted rows.
@immutable
class EvaluationTemplate {
  const EvaluationTemplate({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.layout,
    required this.items,
    required this.inUse,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.deletedAtUtc,
  });

  factory EvaluationTemplate.fromMap(Map<String, dynamic> map) {
    return EvaluationTemplate(
      id: map['id'] as int,
      name: map['name'] as String,
      createdBy: map['createdBy'] as String,
      layout: EvaluationLayoutEntry.idsFromWire(map['layout'] as List?),
      items: ((map['items'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationTemplateItem.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
      inUse: map['inUse'] as bool? ?? false,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAtUtc'] as int,
        isUtc: true,
      ),
      deletedAtUtc: map['deletedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['deletedAtUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory EvaluationTemplate.fromJson(String source) =>
      EvaluationTemplate.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String name;

  /// Username of the admin who created the template.
  final String createdBy;

  /// The order of items, by id, optionally grouped into sections.
  final List<EvaluationLayoutEntry<int>> layout;

  /// Every item, in layout order.
  final List<EvaluationTemplateItem> items;

  /// Whether any evaluation, soft-deleted included, is written against the
  /// template: its items and layout are then frozen (club_server#535, R27a).
  final bool inUse;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Set only when the template is soft-deleted.
  final DateTime? deletedAtUtc;

  /// The item with [itemId], or null.
  EvaluationTemplateItem? itemById(int itemId) {
    for (final item in items) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  EvaluationTemplate copyWith({
    int? id,
    String? name,
    String? createdBy,
    List<EvaluationLayoutEntry<int>>? layout,
    List<EvaluationTemplateItem>? items,
    bool? inUse,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? Function()? deletedAtUtc,
  }) {
    return EvaluationTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      layout: layout ?? this.layout,
      items: items ?? this.items,
      inUse: inUse ?? this.inUse,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdBy': createdBy,
      'layout': layout.map((e) => e.toWire((id) => id)).toList(),
      'items': items.map((i) => i.toMap()).toList(),
      'inUse': inUse,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationTemplate(id: $id, name: $name, items: ${items.length}, '
      'inUse: $inUse, deletedAtUtc: $deletedAtUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationTemplate &&
        other.id == id &&
        other.name == name &&
        other.createdBy == createdBy &&
        evaluationLayoutEquality.equals(other.layout, layout) &&
        evaluationLayoutEquality.equals(other.items, items) &&
        other.inUse == inUse &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.deletedAtUtc == deletedAtUtc;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdBy,
    evaluationLayoutEquality.hash(layout),
    evaluationLayoutEquality.hash(items),
    inUse,
    createdAtUtc,
    updatedAtUtc,
    deletedAtUtc,
  );
}
