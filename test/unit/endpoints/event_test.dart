import 'package:club_sdk_2/remote_store/endpoints/event.dart';
import 'package:test/test.dart';

void main() {
  const ep = EventEndpoints();

  group('EventEndpoints', () {
    test(
      'checkConflict',
      () => expect(ep.checkConflict, '/events/check-conflict'),
    );
    test(
      'checkUserConflicts',
      () => expect(
        ep.checkUserConflicts(42),
        '/events/by_id/42/check-user-conflicts',
      ),
    );
    test('list', () => expect(ep.list, '/events'));
    test('deleted', () => expect(ep.deleted, '/events/deleted'));
    test('event', () => expect(ep.event(42), '/events/by_id/42'));
    test(
      'correction',
      () => expect(ep.correction(42), '/events/by_id/42/correction'),
    );
    test('future', () => expect(ep.future(42), '/events/by_id/42/future'));
    test(
      'Issue 601: reschedule',
      () => expect(ep.reschedule(42), '/events/by_id/42/reschedule'),
    );
    test('cancel', () => expect(ep.cancel(42), '/events/by_id/42/cancel'));
    test(
      'Issue 601: undoCancel',
      () => expect(ep.undoCancel(42), '/events/by_id/42/undo-cancel'),
    );
    test(
      'Issue 16: schedules',
      () => expect(ep.schedules(42), '/events/by_id/42/schedules'),
    );
    test(
      'Issue 16: terminate',
      () => expect(ep.terminate(42), '/events/by_id/42/terminate'),
    );
    test(
      'Issue 16: extend',
      () => expect(ep.extend(42), '/events/by_id/42/extend'),
    );
    test(
      'Issue 16: extendIndefinitely',
      () => expect(
        ep.extendIndefinitely(42),
        '/events/by_id/42/extend-indefinitely',
      ),
    );
    test('Issue 16: drop', () => expect(ep.drop(42), '/events/by_id/42/drop'));
    test(
      'Issue 16: reinstate',
      () => expect(ep.reinstate(42), '/events/by_id/42/reinstate'),
    );
    test('restore', () => expect(ep.restore(42), '/events/by_id/42/restore'));
    test(
      'hardDelete',
      () => expect(ep.hardDelete(42), '/events/by_id/42/hard'),
    );
  });
}
