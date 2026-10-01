/// Template layouts and lookups shared by the evaluation integration
/// suites (club_server#535, #98).
library;

import 'package:club_sdk_2/club_sdk_2.dart';

/// One item of every kind: an info block, a "Skills" section of five
/// questions, and a private Q & A.
///
/// - the rating (1..5) is required, allows evidence, and wants a coach
///   note for a 1;
/// - the multiple choice allows evidence;
/// - the private Q & A allows evidence, so the member's view can be shown
///   to leave it out.
List<EvaluationLayoutEntry<EvaluationTemplateItem>> standardLayout() => const [
  EvaluationLayoutItem(EvaluationInfoItem(markdown: 'How this review works')),
  EvaluationLayoutSection('Skills', [
    EvaluationRatingItem(
      question: 'Skating',
      isRequired: true,
      allowEvidence: true,
      showCommentArea: true,
      requireCommentFor: [1],
      rateMin: 1,
      rateMax: 5,
    ),
    EvaluationYesNoItem(question: 'Wears full kit?', labelTrue: 'Always'),
    EvaluationSingleChoiceItem(
      question: 'Position',
      choices: [
        EvaluationChoice(value: 'f', text: 'Forward'),
        EvaluationChoice(value: 'd', text: 'Defence'),
      ],
    ),
    EvaluationMultipleChoiceItem(
      question: 'Strengths',
      allowEvidence: true,
      choices: [
        EvaluationChoice(value: 'shot', text: 'Shooting'),
        EvaluationChoice(value: 'pass', text: 'Passing'),
      ],
    ),
    EvaluationNumberItem(question: 'Sprint time (s)'),
  ]),
  EvaluationLayoutItem(
    EvaluationQaItem(
      question: 'Coach-only notes',
      isPrivate: true,
      allowEvidence: true,
    ),
  ),
];

/// The id of the first item of [type] in [template].
int itemIdOf(EvaluationTemplate template, EvaluationItemType type) =>
    template.items.firstWhere((i) => i.type == type).id!;
