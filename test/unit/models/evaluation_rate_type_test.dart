import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 98: EvaluationRateType', () {
    test('stars has its wire name, both ways', () {
      expect(EvaluationRateType.stars.wireName, 'stars');
      expect(EvaluationRateType.fromWire('stars'), EvaluationRateType.stars);
      expect(() => EvaluationRateType.fromWire('hearts'), throwsArgumentError);
    });
  });
}
