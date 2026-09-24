import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'evaluation_category.dart';
import 'evaluation_scope_type.dart';

const evaluationTemplateListEquality = DeepCollectionEquality();

/// A named, reusable set of score categories (R49–R51).
///
/// Every evaluation names exactly one template (R10a), whose [categories]
/// are the contract its scores are validated against. A template declares
/// the [scopes] it may be applied within; applying it elsewhere is 422
/// `TEMPLATE_SCOPE_MISMATCH`. A template referenced by any evaluation
/// cannot be deleted or have its categories re-declared (422
/// `TEMPLATE_IN_USE`). [deletedAtUtc] is set only on soft-deleted rows.
@immutable
class EvaluationTemplate {
  const EvaluationTemplate({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.scopes,
    required this.categories,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.description,
    this.deletedAtUtc,
  });

  factory EvaluationTemplate.fromMap(Map<String, dynamic> map) {
    return EvaluationTemplate(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdBy: map['createdBy'] as String,
      scopes: ((map['scopes'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationScopeType.fromWire(e as String))
          .toList(growable: false),
      categories: ((map['categories'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationCategory.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
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
  final String? description;

  /// Username of the admin who created the template.
  final String createdBy;

  /// The scopes this template may be applied within.
  final List<EvaluationScopeType> scopes;

  /// The validation contract for scores.
  final List<EvaluationCategory> categories;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Set only when the template is soft-deleted.
  final DateTime? deletedAtUtc;

  EvaluationTemplate copyWith({
    int? id,
    String? name,
    String? Function()? description,
    String? createdBy,
    List<EvaluationScopeType>? scopes,
    List<EvaluationCategory>? categories,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? Function()? deletedAtUtc,
  }) {
    return EvaluationTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description != null ? description() : this.description,
      createdBy: createdBy ?? this.createdBy,
      scopes: scopes ?? this.scopes,
      categories: categories ?? this.categories,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'scopes': scopes.map((s) => s.wireName).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationTemplate(id: $id, name: $name, scopes: $scopes, '
      'categories: ${categories.length}, deletedAtUtc: $deletedAtUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationTemplate &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.createdBy == createdBy &&
        evaluationTemplateListEquality.equals(other.scopes, scopes) &&
        evaluationTemplateListEquality.equals(other.categories, categories) &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.deletedAtUtc == deletedAtUtc;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      createdBy.hashCode ^
      evaluationTemplateListEquality.hash(scopes) ^
      evaluationTemplateListEquality.hash(categories) ^
      createdAtUtc.hashCode ^
      updatedAtUtc.hashCode ^
      deletedAtUtc.hashCode;
}
