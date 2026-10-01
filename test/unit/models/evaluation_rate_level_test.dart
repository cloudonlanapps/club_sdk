import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 98: EvaluationRateLevel', () {
    const level = EvaluationRateLevel(value: 1, text: 'Low');

    test('round-trips through toMap and toJson', () {
      expect(level.toMap(), {'value': 1, 'text': 'Low'});
      expect(EvaluationRateLevel.fromMap(level.toMap()), level);
      expect(EvaluationRateLevel.fromJson(level.toJson()), level);
    });

    test('copyWith and equality', () {
      expect(level.copyWith(value: 2).value, 2);
      expect(level.copyWith(), level);
      expect(level.hashCode, level.copyWith().hashCode);
      expect(level, isNot(level.copyWith(text: 'High')));
    });
  });
}
