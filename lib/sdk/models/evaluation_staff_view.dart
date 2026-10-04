import 'dart:convert';

import 'package:meta/meta.dart';

import 'evaluation_answer.dart';
import 'evaluation_status.dart';

/// An evaluation as its effective owner reads it (club_server#535, R41):
/// every answer, private items included.
///
/// This is the projection every `/evaluations` route returns, and only the
/// effective owner — [owner], else [createdBy] — ever receives it: to
/// anyone else, an admin included, the evaluation does not exist (404
/// `EVALUATION_NOT_FOUND`, R38a). The member reads `EvaluationMemberView`.
/// No [eventId] means a general evaluation. [publishedAtUtc] is set only
/// while published (R20); [deletedAtUtc] only on soft-deleted rows.
@immutable
class EvaluationStaffView {
  const EvaluationStaffView({
    required this.id,
    required this.templateId,
    required this.createdFor,
    required this.createdBy,
    required this.status,
    required this.answers,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.owner,
    this.eventId,
    this.periodStartUtc,
    this.periodEndUtc,
    this.publishedAtUtc,
    this.deletedAtUtc,
  });

  factory EvaluationStaffView.fromMap(Map<String, dynamic> map) {
    DateTime? instant(Object? wire) => wire == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (wire as num).toInt(),
            isUtc: true,
          );
    return EvaluationStaffView(
      id: map['id'] as int,
      templateId: map['templateId'] as int,
      createdFor: map['createdFor'] as String,
      createdBy: map['createdBy'] as String,
      owner: map['owner'] as String?,
      eventId: map['eventId'] as int?,
      periodStartUtc: instant(map['periodStartUtc']),
      periodEndUtc: instant(map['periodEndUtc']),
      status: EvaluationStatus.fromWire(map['status'] as String),
      answers: ((map['answers'] as List?) ?? const <dynamic>[])
          .map((e) => EvaluationAnswer.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
      createdAtUtc: instant(map['createdAtUtc'])!,
      updatedAtUtc: instant(map['updatedAtUtc'])!,
      publishedAtUtc: instant(map['publishedAtUtc']),
      deletedAtUtc: instant(map['deletedAtUtc']),
    );
  }

  factory EvaluationStaffView.fromJson(String source) =>
      EvaluationStaffView.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;

  /// The template whose items the answers are validated against.
  final int templateId;

  /// The member the evaluation is about.
  final String createdFor;

  /// The coach who started it; never changes.
  final String createdBy;

  /// The coach it was transferred to, if any.
  final String? owner;

  /// The event assessed; null for a general evaluation.
  final int? eventId;

  /// Start of the period covered, if narrowed (R4).
  final DateTime? periodStartUtc;

  /// End of the period covered, if narrowed (R4).
  final DateTime? periodEndUtc;
  final EvaluationStatus status;

  /// The answers given, in item order.
  final List<EvaluationAnswer> answers;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Set while currently published; cleared by withdrawal (R20).
  final DateTime? publishedAtUtc;

  /// Set only when soft-deleted.
  final DateTime? deletedAtUtc;

  /// The one coach who sees and acts on it: [owner], else [createdBy].
  String get effectiveOwner => owner ?? createdBy;

  /// Whether it is about the member in general rather than one event.
  bool get isGeneral => eventId == null;

  /// Whether the member can currently read it.
  bool get isPublished => publishedAtUtc != null;

  /// The answer to item [itemId], or null.
  EvaluationAnswer? answerFor(int itemId) {
    for (final answer in answers) {
      if (answer.itemId == itemId) return answer;
    }
    return null;
  }

  EvaluationStaffView copyWith({
    int? id,
    int? templateId,
    String? createdFor,
    String? createdBy,
    String? Function()? owner,
    int? Function()? eventId,
    DateTime? Function()? periodStartUtc,
    DateTime? Function()? periodEndUtc,
    EvaluationStatus? status,
    List<EvaluationAnswer>? answers,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? Function()? publishedAtUtc,
    DateTime? Function()? deletedAtUtc,
  }) {
    return EvaluationStaffView(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      createdFor: createdFor ?? this.createdFor,
      createdBy: createdBy ?? this.createdBy,
      owner: owner != null ? owner() : this.owner,
      eventId: eventId != null ? eventId() : this.eventId,
      periodStartUtc: periodStartUtc != null
          ? periodStartUtc()
          : this.periodStartUtc,
      periodEndUtc: periodEndUtc != null ? periodEndUtc() : this.periodEndUtc,
      status: status ?? this.status,
      answers: answers ?? this.answers,
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
      'templateId': templateId,
      'createdFor': createdFor,
      'createdBy': createdBy,
      'owner': owner,
      'eventId': eventId,
      'periodStartUtc': periodStartUtc?.millisecondsSinceEpoch,
      'periodEndUtc': periodEndUtc?.millisecondsSinceEpoch,
      'status': status.wireName,
      'answers': answers.map((a) => a.toMap()).toList(),
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'publishedAtUtc': publishedAtUtc?.millisecondsSinceEpoch,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EvaluationStaffView(id: $id, createdFor: $createdFor, '
      'owner: $effectiveOwner, status: $status, eventId: $eventId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationStaffView &&
        other.id == id &&
        other.templateId == templateId &&
        other.createdFor == createdFor &&
        other.createdBy == createdBy &&
        other.owner == owner &&
        other.eventId == eventId &&
        other.periodStartUtc == periodStartUtc &&
        other.periodEndUtc == periodEndUtc &&
        other.status == status &&
        evaluationAnswerListEquality.equals(other.answers, answers) &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.publishedAtUtc == publishedAtUtc &&
        other.deletedAtUtc == deletedAtUtc;
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    createdFor,
    createdBy,
    owner,
    eventId,
    periodStartUtc,
    periodEndUtc,
    status,
    evaluationAnswerListEquality.hash(answers),
    createdAtUtc,
    updatedAtUtc,
    publishedAtUtc,
    deletedAtUtc,
  );
}
