import 'package:club_sdk_2/remote_store/endpoints/my_events.dart';
import 'package:test/test.dart';

void main() {
  const ep = MyEventsEndpoints();

  group('MyEventsEndpoints', () {
    test('list', () => expect(ep.list('joe'), '/myevents/by_id/joe'));
    test('event', () => expect(ep.event('joe', 1), '/myevents/by_id/joe/1'));
    test(
      'Issue 16: schedules',
      () => expect(
        ep.schedules('joe', 1),
        '/myevents/by_id/joe/1/schedules',
      ),
    );
    test(
      'enrollment',
      () =>
          expect(ep.enrollment('joe', 1), '/myevents/by_id/joe/1/enrollments'),
    );
    test(
      'acceptInvite',
      () => expect(
        ep.acceptInvite('joe', 1),
        '/myevents/by_id/joe/1/enrollments/accept',
      ),
    );
    test(
      'declineInvite',
      () => expect(
        ep.declineInvite('joe', 1),
        '/myevents/by_id/joe/1/enrollments/decline',
      ),
    );
    test(
      'requestToJoin',
      () => expect(
        ep.requestToJoin('joe', 1),
        '/myevents/by_id/joe/1/enrollments/request',
      ),
    );
    test(
      'withdraw',
      () => expect(
        ep.withdraw('joe', 1),
        '/myevents/by_id/joe/1/enrollments/withdraw',
      ),
    );
    test(
      'cancelWithdraw',
      () => expect(
        ep.cancelWithdraw('joe', 1),
        '/myevents/by_id/joe/1/enrollments/cancel-withdraw',
      ),
    );
    test(
      'occurrences',
      () => expect(ep.occurrences('joe'), '/myevents/by_id/joe/occurrences'),
    );
    test('occurrence', () {
      expect(
        ep.occurrence('joe', 1, '1700000000000'),
        '/myevents/by_id/joe/1/occurrences/1700000000000',
      );
    });
    test('occurrenceAttendance', () {
      expect(
        ep.occurrenceAttendance('joe', 1, '1700000000000'),
        '/myevents/by_id/joe/1/occurrences/1700000000000/attendance',
      );
    });
    test(
      'attendance',
      () => expect(ep.attendance('joe'), '/myevents/by_id/joe/attendance'),
    );
    test('requestLeave', () {
      expect(
        ep.requestLeave('joe', 1, '1700000000000'),
        '/myevents/by_id/joe/1/occurrences/1700000000000/leave/request',
      );
    });
    test('cancelLeave', () {
      expect(
        ep.cancelLeave('joe', 1, '1700000000000'),
        '/myevents/by_id/joe/1/occurrences/1700000000000/leave/cancel',
      );
    });
  });
}
