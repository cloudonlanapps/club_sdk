import 'package:club_sdk_2/remote_store/endpoints/application.dart';
import 'package:club_sdk_2/remote_store/endpoints/endpoints.dart';
import 'package:test/test.dart';

/// Issue 66: the `/applications` routes (club_server#93).
void main() {
  const ep = ApplicationEndpoints();

  group('ApplicationEndpoints', () {
    test('Issue 66: the collection and one template', () {
      expect(ep.list, '/applications');
      expect(ep.byId(7), '/applications/7');
    });

    test('Issue 66: the moves and duplicate', () {
      expect(ep.save(7), '/applications/7/save');
      expect(ep.publish(7), '/applications/7/publish');
      expect(ep.unpublish(7), '/applications/7/unpublish');
      expect(ep.revert(7), '/applications/7/revert');
      expect(ep.duplicate(7), '/applications/7/duplicate');
    });

    test('Issue 66: the PDFs', () {
      expect(ep.preview(7), '/applications/7/preview');
      expect(ep.ownForm(7), '/applications/7/form');
      expect(ep.memberForm(7, 'test_m1'), '/applications/7/form/test_m1');
    });

    test('Issue 66: the catalogues', () {
      expect(ep.labels, '/applications/labels');
      expect(ep.clauses, '/applications/clauses');
    });

    test('Issue 76: fill one clause', () {
      expect(ep.fillClause, '/applications/clauses/fill');
    });

    test('Issue 66: reachable from endpoints', () {
      expect(endpoints.applications.list, '/applications');
    });
  });
}
