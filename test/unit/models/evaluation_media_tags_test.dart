import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 98: EvaluationMediaTags', () {
    test('evidence is tagged with the item id', () {
      expect(EvaluationMediaTags.evidence(42), '42');
    });

    test('the member copy has its own tag', () {
      expect(EvaluationMediaTags.memberCopy, 'member_copy');
    });

    test('itemIdOf reads an evidence tag back, and nothing else', () {
      expect(EvaluationMediaTags.itemIdOf('42'), 42);
      expect(EvaluationMediaTags.itemIdOf('member_copy'), isNull);
    });
  });
}
