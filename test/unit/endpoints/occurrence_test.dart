import 'package:club_sdk_2/remote_store/endpoints/occurrence.dart';
import 'package:test/test.dart';

void main() {
  const ep = OccurrenceEndpoints();

  group('OccurrenceEndpoints', () {
    test('list', () => expect(ep.list, '/events/occurrences'));
    test('occurrence with String timeStr', () {
      expect(
        ep.occurrence(1, '1700000000000'),
        '/events/by_id/1/occurrences/1700000000000',
      );
    });
    test('occurrence with int timeStr', () {
      expect(
        ep.occurrence(1, 1700000000000),
        '/events/by_id/1/occurrences/1700000000000',
      );
    });
    test('reschedule', () {
      expect(
        ep.reschedule(1, '1700000000000'),
        '/events/by_id/1/occurrences/1700000000000/reschedule',
      );
    });
    test('cancel', () {
      expect(
        ep.cancel(1, '1700000000000'),
        '/events/by_id/1/occurrences/1700000000000/cancel',
      );
    });
    test('undoCancel', () {
      expect(
        ep.undoCancel(1, '1700000000000'),
        '/events/by_id/1/occurrences/1700000000000/undo-cancel',
      );
    });
  });
}
