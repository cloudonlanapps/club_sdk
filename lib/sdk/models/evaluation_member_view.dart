import 'dart:convert';

import 'package:meta/meta.dart';

import 'evaluation_answer.dart';
import 'evaluation_member_template.dart';
import 'evaluation_status.dart';

/// A published evaluation as the member reads it (`/myevaluations`,
/// club_server#535, R38, R39).
///
/// A separate projection from `EvaluationStaffView`, not a filtered one:
/// it carries the [template]'s public items and layout, and [answers] to
/// those items only, so a private item — question, answer, coach note or
/// evidence — never reaches the member's device. The coach note on a
/// public item is written for the member (R39a). Only published
/// evaluations are served: an unpublished one answers 404, not 403, so a
/// member cannot detect that a coach is drafting something about them. Do
/// not translate that 404 into a not-authorized message.
@immutable
class EvaluationMemberView {
  const EvaluationMemberView({
    required this.id,
    required this.createdFor,
    required this.createdBy,
    required this.status,
    required this.template,
    required this.answers,
    this.owner,
    this.eventId,
    this.periodStartUtc,
    this.periodEndUtc,
    this.publishedAtUtc,
  });

  factory EvaluationMemberView.fromMap(Map<String, dynamic> map) {
    DateTime? instant(Object? wire) => wire == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (wire as num).toInt(),
            isUtc: true,
          );
    return EvaluationMemberView(
      id: map['id'] as int,
      createdFor: map['createdFor'] as String,
      createdBy: map['createdBy'] as String,
      owner: map['owner'] as String?,
      eventId: map['eventId'] as int?,
      periodStartUtc: instant(map['periodStartUtc']),
      periodEndUtc: instant(map['periodEndUtc']),
      status: EvaluationStatus.fromWire(map['status'] as String),
      publishedAtUtc: instant(map['publishedAtUtc']),
      template: EvaluationMemberTemplate.fromMap(
        Map<String, dynamic>.from(map['template'] as Map),
      ),
      answers: ((map['answers'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationAnswer.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  factory EvaluationMemberView.fromJson(String source) =>
      EvaluationMemberView.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String createdFor;
  final String createdBy;
  final String? owner;
  final int? eventId;
  final DateTime? periodStartUtc;
  final DateTime? periodEndUtc;
  final EvaluationStatus status;
  final DateTime? publishedAtUtc;

  /// The template's public items and layout.
  final EvaluationMemberTemplate template;

  /// Answers to the public items.
  final List<EvaluationAnswer> answers;

  /// The coach who wrote it: [owner], else [createdBy].
  String get effectiveOwner => owner ?? createdBy;

  EvaluationMemberView copyWith({
    int? id,
    String? createdFor,
    String? createdBy,
    String? Function()? owner,
    int? Function()? eventId,
    DateTime? Function()? periodStartUtc,
    DateTime? Function()? periodEndUtc,
    EvaluationStatus? status,
    DateTime? Function()? publishedAtUtc,
    EvaluationMemberTemplate? template,
    List<EvaluationAnswer>? answers,
  }) {
    return EvaluationMemberView(
      id: id ?? this.id,
      createdFor: createdFor ?? this.createdFor,
      createdBy: createdBy ?? this.createdBy,
      owner: owner != null ? owner() : this.owner,
      eventId: eventId != null ? eventId() : this.eventId,
      periodStartUtc: periodStartUtc != null
          ? periodStartUtc()
          : this.periodStartUtc,
      periodEndUtc: periodEndUtc != null ? periodEndUtc() : this.periodEndUtc,
      status: status ?? this.status,
      publishedAtUtc: publishedAtUtc != null
          ? publishedAtUtc()
          : this.publishedAtUtc,
      template: template ?? this.template,
      answers: answers ?? this.answers,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'createdFor': createdFor,
      'createdBy': createdBy,
      'owner': owner,
      'eventId': eventId,
      'periodStartUtc': periodStartUtc?.millisecondsSinceEpoch,
      'periodEndUtc': periodEndUtc?.millisecondsSinceEpoch,
      'status': status.wireName,
      'publishedAtUtc': publishedAtUtc?.millisecondsSinceEpoch,
      'template': template.toMap(),
      'answers': answers.map((a) => a.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationMemberView(id: $id, createdFor: $createdFor, '
      'owner: $effectiveOwner, status: $status, '
      'publishedAtUtc: $publishedAtUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationMemberView &&
        other.id == id &&
        other.createdFor == createdFor &&
        other.createdBy == createdBy &&
        other.owner == owner &&
        other.eventId == eventId &&
        other.periodStartUtc == periodStartUtc &&
        other.periodEndUtc == periodEndUtc &&
        other.status == status &&
        other.publishedAtUtc == publishedAtUtc &&
        other.template == template &&
        evaluationAnswerListEquality.equals(other.answers, answers);
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdFor,
    createdBy,
    owner,
    eventId,
    periodStartUtc,
    periodEndUtc,
    status,
    publishedAtUtc,
    template,
    evaluationAnswerListEquality.hash(answers),
  );
}
