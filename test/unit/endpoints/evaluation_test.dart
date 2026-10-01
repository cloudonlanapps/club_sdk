import 'package:club_sdk_2/remote_store/endpoints/evaluation.dart';
import 'package:club_sdk_2/remote_store/endpoints/my_evaluations.dart';
import 'package:test/test.dart';

void main() {
  const ep = EvaluationEndpoints();

  group('Issue 98: EvaluationEndpoints', () {
    test('answer', () {
      expect(ep.answer(21, 11), '/evaluations/by_id/21/answers/11');
    });
    test('pdf', () => expect(ep.pdf(21), '/evaluations/by_id/21/pdf'));
    test('evidence', () {
      expect(ep.evidence(21, 11), '/evaluations/by_id/21/evidence/11');
    });
    test('transfer', () {
      expect(ep.transfer(21), '/evaluations/by_id/21/transfer');
    });
    test('templateItems', () {
      expect(ep.templateItems(5), '/evaluations/templates/by_id/5/items');
    });
    test('templateItem', () {
      expect(ep.templateItem(5, 11), '/evaluations/templates/by_id/5/items/11');
    });
    test('itemSearch', () {
      expect(ep.itemSearch, '/evaluations/templates/items');
    });
  });

  group('MyEvaluationsEndpoints', () {
    const my = MyEvaluationsEndpoints();
    test('list', () => expect(my.list('a'), '/myevaluations/by_id/a'));
    test('one', () => expect(my.one('a', 2), '/myevaluations/by_id/a/2'));
    test('media', () {
      expect(my.media('a', 2), '/myevaluations/by_id/a/2/media');
    });
  });
}
