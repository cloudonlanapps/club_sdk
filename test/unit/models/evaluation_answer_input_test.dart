import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 98: EvaluationAnswerInput', () {
    test('toMap sends only the fields given', () {
      expect(const EvaluationAnswerInput(valueNum: 4).toMap(), {'valueNum': 4});
      expect(const EvaluationAnswerInput(coachNote: 'n').toMap(), {
        'coachNote': 'n',
      });
      expect(
        const EvaluationAnswerInput(
          choices: ['a', 'b'],
          coachNote: 'n',
        ).toMap(),
        {
          'choices': ['a', 'b'],
          'coachNote': 'n',
        },
      );
    });

    test('yesNo sends 1 for yes and 0 for no', () {
      expect(const EvaluationAnswerInput.yesNo(yes: true).toMap(), {
        'valueNum': 1,
      });
      expect(
        const EvaluationAnswerInput.yesNo(yes: false, coachNote: 'n').toMap(),
        {
          'valueNum': 0,
          'coachNote': 'n',
        },
      );
    });

    test('round-trips through toMap and toJson', () {
      const input = EvaluationAnswerInput(valueText: 'f', coachNote: 'n');
      expect(EvaluationAnswerInput.fromMap(input.toMap()), input);
      expect(EvaluationAnswerInput.fromJson(input.toJson()), input);
    });

    test('copyWith clears fields, and equality', () {
      const input = EvaluationAnswerInput(choices: ['a'], coachNote: 'n');
      expect(input.copyWith(coachNote: () => null).coachNote, isNull);
      expect(input.copyWith(choices: () => null).choices, isNull);
      expect(input.copyWith(valueNum: () => 2).valueNum, 2);
      expect(input.copyWith(), input);
      expect(input.hashCode, input.copyWith().hashCode);
      expect(input, isNot(input.copyWith(choices: () => ['b'])));
    });
  });
}
