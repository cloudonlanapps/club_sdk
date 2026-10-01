import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 98: EvaluationItemType', () {
    const wire = {
      EvaluationItemType.rating: 'rating',
      EvaluationItemType.yesNo: 'yesNo',
      EvaluationItemType.singleChoice: 'singleChoice',
      EvaluationItemType.multipleChoice: 'multipleChoice',
      EvaluationItemType.number: 'number',
      EvaluationItemType.qa: 'qa',
      EvaluationItemType.info: 'info',
    };

    test('every value has its wire name, both ways', () {
      expect(wire.keys, unorderedEquals(EvaluationItemType.values));
      for (final MapEntry(key: type, value: name) in wire.entries) {
        expect(type.wireName, name);
        expect(EvaluationItemType.fromWire(name), type);
      }
    });

    test('an unknown wire name is refused', () {
      expect(() => EvaluationItemType.fromWire('slider'), throwsArgumentError);
    });

    test('isQuestion is false only for info', () {
      expect(
        EvaluationItemType.values.where((t) => !t.isQuestion),
        [EvaluationItemType.info],
      );
    });
  });
}
