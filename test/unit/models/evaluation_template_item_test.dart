import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  group('Issue 98: EvaluationTemplateItem.fromMap', () {
    final cases = <String, (Map<String, dynamic>, TypeMatcher<Object>)>{
      'rating': (ratingItemPayload(), isA<EvaluationRatingItem>()),
      'yesNo': (yesNoItemPayload(), isA<EvaluationYesNoItem>()),
      'singleChoice': (
        singleChoiceItemPayload(),
        isA<EvaluationSingleChoiceItem>(),
      ),
      'multipleChoice': (
        multipleChoiceItemPayload(),
        isA<EvaluationMultipleChoiceItem>(),
      ),
      'number': (numberItemPayload(), isA<EvaluationNumberItem>()),
      'qa': (qaItemPayload(), isA<EvaluationQaItem>()),
      'info': (infoItemPayload(), isA<EvaluationInfoItem>()),
    };

    for (final MapEntry(key: type, value: (payload, matcher))
        in cases.entries) {
      test('reads a $type item as its own variant', () {
        final item = EvaluationTemplateItem.fromMap(payload);
        expect(item, matcher);
        expect(item.type.wireName, type);
        expect(item.id, payload['id']);
      });

      test('a $type item round-trips through toMap to the server shape', () {
        final item = EvaluationTemplateItem.fromMap(payload);
        expect(item.toMap(), payload);
        expect(EvaluationTemplateItem.fromMap(item.toMap()), item);
        expect(EvaluationTemplateItem.fromJson(item.toJson()), item);
      });

      test('two $type items read from one payload are equal', () {
        final a = EvaluationTemplateItem.fromMap(payload);
        final b = EvaluationTemplateItem.fromMap(Map.of(payload));
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });
    }

    test('an unknown type is refused', () {
      expect(
        () => EvaluationTemplateItem.fromMap(const {'type': 'slider', 'id': 1}),
        throwsArgumentError,
      );
    });

    test('missing optional flags default to false and empty lists', () {
      final item = EvaluationTemplateItem.fromMap(const {
        'type': 'number',
        'question': 'Laps',
      });
      expect(item, isA<EvaluationNumberItem>());
      final number = item as EvaluationNumberItem;
      expect(number.id, isNull);
      expect(number.isPrivate, isFalse);
      expect(number.isRequired, isFalse);
      expect(number.allowEvidence, isFalse);
      expect(number.showCommentArea, isFalse);
      expect(number.requireCommentFor, isEmpty);
      expect(number.originItemId, isNull);
    });

    test('only questions are EvaluationQuestionItem', () {
      expect(
        EvaluationTemplateItem.fromMap(qaItemPayload()),
        isA<EvaluationQuestionItem>(),
      );
      expect(
        EvaluationTemplateItem.fromMap(infoItemPayload()),
        isNot(isA<EvaluationQuestionItem>()),
      );
    });
  });

  group('Issue 98: EvaluationRatingItem', () {
    final item =
        EvaluationTemplateItem.fromMap(ratingItemPayload())
            as EvaluationRatingItem;
    final levels =
        EvaluationTemplateItem.fromMap(levelsItemPayload())
            as EvaluationRatingItem;

    test('reads a range scale', () {
      expect(item.question, 'Skating');
      expect(item.isRequired, isTrue);
      expect(item.allowEvidence, isTrue);
      expect(item.showCommentArea, isTrue);
      expect(item.requireCommentFor, [1]);
      expect(item.rateMin, 1);
      expect(item.rateMax, 5);
      expect(item.rateValues, isNull);
      expect(item.rateType, isNull);
    });

    test('reads labelled levels and the origin', () {
      expect(levels.rateValues, const [
        EvaluationRateLevel(value: 1, text: 'Low'),
        EvaluationRateLevel(value: 2, text: 'High'),
      ]);
      expect(levels.originItemId, 3);
    });

    test('reads stars', () {
      final stars = EvaluationTemplateItem.fromMap(
        ratingItemPayload()..['rateType'] = 'stars',
      );
      expect(
        (stars as EvaluationRatingItem).rateType,
        EvaluationRateType.stars,
      );
      expect(stars.toMap()['rateType'], 'stars');
    });

    test('copyWith changes fields and clears nullable ones', () {
      final changed = item.copyWith(
        question: 'Edges',
        rateMax: () => 10,
        originItemId: () => 4,
      );
      expect(changed.question, 'Edges');
      expect(changed.rateMax, 10);
      expect(changed.originItemId, 4);
      final cleared = item.copyWith(
        id: () => null,
        rateMin: () => null,
        rateMax: () => null,
      );
      expect(cleared.id, isNull);
      expect(cleared.rateMin, isNull);
      expect(cleared.rateMax, isNull);
      expect(item.copyWith(), item);
    });

    test('differing levels are not equal', () {
      expect(
        levels,
        isNot(
          levels.copyWith(
            rateValues: () => const [
              EvaluationRateLevel(value: 1, text: 'Low'),
            ],
          ),
        ),
      );
    });
  });

  group('Issue 98: EvaluationYesNoItem', () {
    final item =
        EvaluationTemplateItem.fromMap(yesNoItemPayload())
            as EvaluationYesNoItem;

    test('reads labels and the note rule', () {
      expect(item.labelTrue, 'Always');
      expect(item.labelFalse, 'Not yet');
      expect(item.requireCommentFor, [false]);
    });

    test('copyWith clears a label', () {
      expect(item.copyWith(labelTrue: () => null).labelTrue, isNull);
      expect(item.copyWith(), item);
      expect(item, isNot(item.copyWith(requireCommentFor: [true])));
    });
  });

  group('Issue 98: choice items', () {
    final single =
        EvaluationTemplateItem.fromMap(singleChoiceItemPayload())
            as EvaluationSingleChoiceItem;
    final multiple =
        EvaluationTemplateItem.fromMap(multipleChoiceItemPayload())
            as EvaluationMultipleChoiceItem;

    test('read their choices', () {
      expect(single.choices, const [
        EvaluationChoice(value: 'f', text: 'Forward'),
        EvaluationChoice(value: 'd', text: 'Defence'),
      ]);
      expect(multiple.requireCommentFor, ['pass']);
    });

    test('single and multiple are not equal on the same fields', () {
      final asSingle = EvaluationSingleChoiceItem(
        id: multiple.id,
        question: multiple.question,
        allowEvidence: multiple.allowEvidence,
        showCommentArea: multiple.showCommentArea,
        requireCommentFor: multiple.requireCommentFor,
        choices: multiple.choices,
      );
      expect(asSingle, isNot(multiple));
    });

    test('copyWith replaces the choices', () {
      final changed = single.copyWith(
        choices: const [EvaluationChoice(value: 'g', text: 'Goalie')],
      );
      expect(changed.choices.single.value, 'g');
      expect(changed, isNot(single));
      expect(multiple.copyWith(), multiple);
      expect(
        multiple.copyWith(isPrivate: true).toMap()['type'],
        'multipleChoice',
      );
    });
  });

  group('Issue 98: EvaluationNumberItem', () {
    final item =
        EvaluationTemplateItem.fromMap(numberItemPayload())
            as EvaluationNumberItem;

    test('reads numeric note rules', () {
      expect(item.requireCommentFor, [0, 2.5]);
      expect(item.isPrivate, isTrue);
    });

    test('copyWith', () {
      expect(item.copyWith(requireCommentFor: []).requireCommentFor, isEmpty);
      expect(item.copyWith(), item);
    });
  });

  group('Issue 98: EvaluationQaItem', () {
    final item =
        EvaluationTemplateItem.fromMap(qaItemPayload()) as EvaluationQaItem;

    test('carries no comment area', () {
      expect(item.toMap().containsKey('showCommentArea'), isFalse);
      expect(item.toMap().containsKey('requireCommentFor'), isFalse);
    });

    test('copyWith', () {
      expect(item.copyWith(isPrivate: false).isPrivate, isFalse);
      expect(item.copyWith(), item);
      expect(item, isNot(item.copyWith(question: 'Other')));
    });
  });

  group('Issue 98: EvaluationInfoItem', () {
    final item =
        EvaluationTemplateItem.fromMap(infoItemPayload()) as EvaluationInfoItem;

    test('carries markdown and no question fields', () {
      expect(item.markdown, '**Read me**');
      expect(item.toMap().containsKey('question'), isFalse);
      expect(item.toMap().containsKey('originItemId'), isFalse);
    });

    test('copyWith', () {
      expect(item.copyWith(markdown: 'x').markdown, 'x');
      expect(item.copyWith(id: () => null).id, isNull);
      expect(item.copyWith(), item);
    });
  });
}
