import 'dart:convert';

import 'package:meta/meta.dart';

import 'evaluation_scope.dart';
import 'evaluation_score.dart';
import 'evaluation_staff_view.dart' show evaluationScoreListEquality;
import 'evaluation_status.dart';

/// An evaluation as its subject reads it (`/myevaluations`, R38–R40).
///
/// Deliberately a separate type from `EvaluationStaffView`, not a filtered
/// one: it has no coach-note field at all, so the coach's private note is
/// never one deserialization away from the member's device (R39). The
/// server only ever returns published evaluations through this projection;
/// an unpublished one answers 404, not 403, so a member cannot detect that
/// a coach is drafting something about them (R38). Do not translate that
/// 404 into a not-authorized message.
@immutable
class EvaluationMemberView {
  const EvaluationMemberView({
    required this.id,
    required this.subjectUsername,
    required this.authorUsername,
    required this.status,
    required this.scope,
    required this.scores,
    this.comment,
    this.publishedAtUtc,
  });

  /// Reads only the member-facing keys. Any `coachNote` in [map] is
  /// ignored and never stored.
  factory EvaluationMemberView.fromMap(Map<String, dynamic> map) {
    return EvaluationMemberView(
      id: map['id'] as int,
      subjectUsername: map['subjectUsername'] as String,
      authorUsername: map['authorUsername'] as String,
      status: EvaluationStatus.fromWire(map['status'] as String),
      scope: EvaluationScope.fromMap(
        Map<String, dynamic>.from(map['scope'] as Map),
      ),
      scores: ((map['scores'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationScore.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
      comment: map['comment'] as String?,
      publishedAtUtc: map['publishedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['publishedAtUtc'] as int,
              isUtc: true,
            )
          : null,
    );
  }

  factory EvaluationMemberView.fromJson(String source) =>
      EvaluationMemberView.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String subjectUsername;
  final String authorUsername;
  final EvaluationStatus status;
  final EvaluationScope scope;
  final List<EvaluationScore> scores;

  /// Text the coach wrote for the subject.
  final String? comment;
  final DateTime? publishedAtUtc;

  EvaluationMemberView copyWith({
    int? id,
    String? subjectUsername,
    String? authorUsername,
    EvaluationStatus? status,
    EvaluationScope? scope,
    List<EvaluationScore>? scores,
    String? Function()? comment,
    DateTime? Function()? publishedAtUtc,
  }) {
    return EvaluationMemberView(
      id: id ?? this.id,
      subjectUsername: subjectUsername ?? this.subjectUsername,
      authorUsername: authorUsername ?? this.authorUsername,
      status: status ?? this.status,
      scope: scope ?? this.scope,
      scores: scores ?? this.scores,
      comment: comment != null ? comment() : this.comment,
      publishedAtUtc: publishedAtUtc != null
          ? publishedAtUtc()
          : this.publishedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'subjectUsername': subjectUsername,
      'authorUsername': authorUsername,
      'status': status.wireName,
      'scope': scope.toMap(),
      'scores': scores.map((s) => s.toMap()).toList(),
      'comment': comment,
      'publishedAtUtc': publishedAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationMemberView(id: $id, subject: $subjectUsername, '
      'author: $authorUsername, status: $status, '
      'publishedAtUtc: $publishedAtUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationMemberView &&
        other.id == id &&
        other.subjectUsername == subjectUsername &&
        other.authorUsername == authorUsername &&
        other.status == status &&
        other.scope == scope &&
        evaluationScoreListEquality.equals(other.scores, scores) &&
        other.comment == comment &&
        other.publishedAtUtc == publishedAtUtc;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      subjectUsername.hashCode ^
      authorUsername.hashCode ^
      status.hashCode ^
      scope.hashCode ^
      evaluationScoreListEquality.hash(scores) ^
      comment.hashCode ^
      publishedAtUtc.hashCode;
}
