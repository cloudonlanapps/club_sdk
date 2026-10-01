part of 'evaluation_template_item.dart';

/// An item that takes an answer (club_server#535, R12).
///
/// [question] is markdown. An [isRequired] question must be answered
/// before the evaluation is saved (422 `INCOMPLETE`); an [allowEvidence]
/// question accepts files attached to its answer (R56a). [originItemId] is
/// set on a copy of another template's item (R12b): a copy keeps its
/// origin's type and answer domain, so answers to the two compare.
@immutable
sealed class EvaluationQuestionItem extends EvaluationTemplateItem {
  const EvaluationQuestionItem({
    required this.question,
    super.id,
    super.isPrivate,
    this.isRequired = false,
    this.allowEvidence = false,
    this.originItemId,
  });

  final String question;
  final bool isRequired;
  final bool allowEvidence;

  /// The item this one was first copied from, if a copy.
  final int? originItemId;
}
