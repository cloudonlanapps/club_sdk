import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 98: EvaluationChoice', () {
    const choice = EvaluationChoice(value: 'f', text: 'Forward');

    test('round-trips through toMap and toJson', () {
      expect(choice.toMap(), {'value': 'f', 'text': 'Forward'});
      expect(EvaluationChoice.fromMap(choice.toMap()), choice);
      expect(EvaluationChoice.fromJson(choice.toJson()), choice);
    });

    test('copyWith and equality', () {
      expect(choice.copyWith(text: 'Wing').text, 'Wing');
      expect(choice.copyWith(), choice);
      expect(choice.hashCode, choice.copyWith().hashCode);
      expect(choice, isNot(choice.copyWith(value: 'd')));
    });
  });
}
