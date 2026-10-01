import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/evaluation_payloads.dart';

void main() {
  group('Issue 98: EvaluationAnswer', () {
    final answer = EvaluationAnswer.fromMap(answerPayload());

    test('fromMap reads value, note and evidence', () {
      expect(answer.itemId, 11);
      expect(answer.valueNum, 4);
      expect(answer.valueText, isNull);
      expect(answer.choices, isEmpty);
      expect(answer.coachNote, 'Good edges');
      expect(answer.evidence, const [EvaluationEvidence(mediaUuid: 'm1')]);
    });

    test('fromMap reads an evidence-only answer with missing fields', () {
      final only = EvaluationAnswer.fromMap(const {
        'itemId': 3,
        'evidence': [
          {'mediaUuid': 'm2', 'metadata': null},
        ],
      });
      expect(only.valueNum, isNull);
      expect(only.choices, isEmpty);
      expect(only.coachNote, isNull);
      expect(only.evidence.single.mediaUuid, 'm2');
    });

    test('yesNo reads 1 as yes and 0 as no', () {
      expect(answer.copyWith(valueNum: () => 1).yesNo, isTrue);
      expect(answer.copyWith(valueNum: () => 0).yesNo, isFalse);
      expect(answer.copyWith(valueNum: () => null).yesNo, isNull);
    });

    test('round-trips through toMap and toJson', () {
      expect(answer.toMap(), answerPayload());
      expect(EvaluationAnswer.fromMap(answer.toMap()), answer);
      expect(EvaluationAnswer.fromJson(answer.toJson()), answer);
    });

    test('copyWith clears nullable fields, and equality', () {
      final cleared = answer.copyWith(
        valueNum: () => null,
        coachNote: () => null,
      );
      expect(cleared.valueNum, isNull);
      expect(cleared.coachNote, isNull);
      expect(answer.copyWith(), answer);
      expect(answer.hashCode, answer.copyWith().hashCode);
      expect(answer, isNot(answer.copyWith(evidence: const [])));
      expect(answer, isNot(answer.copyWith(choices: const ['a'])));
    });
  });
}
