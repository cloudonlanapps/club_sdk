import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'evaluation_scope.dart';
import 'evaluation_score.dart';
import 'evaluation_status.dart';

const evaluationScoreListEquality = DeepCollectionEquality();

/// An evaluation as staff read it (R41): every field, including the
/// private [coachNote].
///
/// This is the projection returned by every `/evaluations` route. The
/// subject reads `EvaluationMemberView` instead, a separate type that has
/// no coach note at all (R39). [publishedAtUtc] is set only while the
/// evaluation is currently published; withdrawal clears it (R20).
/// [deletedAtUtc] is set only on soft-deleted rows.
@immutable
class EvaluationStaffView {
  const EvaluationStaffView({
    required this.id,
    required this.subjectUsername,
    required this.authorUsername,
    required this.templateId,
    required this.status,
    required this.scope,
    required this.scores,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.comment,
    this.coachNote,
    this.publishedAtUtc,
    this.deletedAtUtc,
  });

  factory EvaluationStaffView.fromMap(Map<String, dynamic> map) {
    return EvaluationStaffView(
      id: map['id'] as int,
      subjectUsername: map['subjectUsername'] as String,
      authorUsername: map['authorUsername'] as String,
      templateId: map['templateId'] as int,
      status: EvaluationStatus.fromWire(map['status'] as String),
      scope: EvaluationScope.fromMap(
        Map<String, dynamic>.from(map['scope'] as Map),
      ),
      scores: ((map['scores'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationScore.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
      comment: map['comment'] as String?,
      coachNote: map['coachNote'] as String?,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAtUtc'] as int,
        isUtc: true,
      ),
      publishedAtUtc: map['publishedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['publishedAtUtc'] as int,
              isUtc: true,
            )
          : null,
      deletedAtUtc: map['deletedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['deletedAtUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory EvaluationStaffView.fromJson(String source) =>
      EvaluationStaffView.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;

  /// The member assessed.
  final String subjectUsername;

  /// The coach the evaluation is assigned to.
  final String authorUsername;

  /// The template whose categories the scores are validated against.
  final int templateId;
  final EvaluationStatus status;
  final EvaluationScope scope;
  final List<EvaluationScore> scores;

  /// Text meant for the subject.
  final String? comment;

  /// Private note for staff; never reaches the subject (R39).
  final String? coachNote;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Set while currently published; cleared by withdrawal (R20).
  final DateTime? publishedAtUtc;

  /// Set only when soft-deleted.
  final DateTime? deletedAtUtc;

  /// Whether the subject can currently read this evaluation.
  bool get isPublished => publishedAtUtc != null;

  EvaluationStaffView copyWith({
    int? id,
    String? subjectUsername,
    String? authorUsername,
    int? templateId,
    EvaluationStatus? status,
    EvaluationScope? scope,
    List<EvaluationScore>? scores,
    String? Function()? comment,
    String? Function()? coachNote,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? Function()? publishedAtUtc,
    DateTime? Function()? deletedAtUtc,
  }) {
    return EvaluationStaffView(
      id: id ?? this.id,
      subjectUsername: subjectUsername ?? this.subjectUsername,
      authorUsername: authorUsername ?? this.authorUsername,
      templateId: templateId ?? this.templateId,
      status: status ?? this.status,
      scope: scope ?? this.scope,
      scores: scores ?? this.scores,
      comment: comment != null ? comment() : this.comment,
      coachNote: coachNote != null ? coachNote() : this.coachNote,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      publishedAtUtc: publishedAtUtc != null
          ? publishedAtUtc()
          : this.publishedAtUtc,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'subjectUsername': subjectUsername,
      'authorUsername': authorUsername,
      'templateId': templateId,
      'status': status.wireName,
      'scope': scope.toMap(),
      'scores': scores.map((s) => s.toMap()).toList(),
      'comment': comment,
      'coachNote': coachNote,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'publishedAtUtc': publishedAtUtc?.millisecondsSinceEpoch,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationStaffView(id: $id, subject: $subjectUsername, '
      'author: $authorUsername, status: $status, scope: $scope, '
      'publishedAtUtc: $publishedAtUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationStaffView &&
        other.id == id &&
        other.subjectUsername == subjectUsername &&
        other.authorUsername == authorUsername &&
        other.templateId == templateId &&
        other.status == status &&
        other.scope == scope &&
        evaluationScoreListEquality.equals(other.scores, scores) &&
        other.comment == comment &&
        other.coachNote == coachNote &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.publishedAtUtc == publishedAtUtc &&
        other.deletedAtUtc == deletedAtUtc;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      subjectUsername.hashCode ^
      authorUsername.hashCode ^
      templateId.hashCode ^
      status.hashCode ^
      scope.hashCode ^
      evaluationScoreListEquality.hash(scores) ^
      comment.hashCode ^
      coachNote.hashCode ^
      createdAtUtc.hashCode ^
      updatedAtUtc.hashCode ^
      publishedAtUtc.hashCode ^
      deletedAtUtc.hashCode;
}
