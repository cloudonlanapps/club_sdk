import 'package:club_sdk_2/remote_store/endpoints/enrollment.dart';
import 'package:test/test.dart';

void main() {
  const ep = EnrollmentEndpoints();

  group('EnrollmentEndpoints', () {
    test(
      'invite',
      () => expect(ep.invite(1), '/events/by_id/1/enrollments/invite'),
    );
    test(
      'assign',
      () => expect(ep.assign(1), '/events/by_id/1/enrollments/assign'),
    );
    test(
      'assignTrial',
      () =>
          expect(ep.assignTrial(1), '/events/by_id/1/enrollments/assign-trial'),
    );
    test(
      'approve',
      () => expect(ep.approve(1), '/events/by_id/1/enrollments/approve'),
    );
    test(
      'reject',
      () => expect(ep.reject(1), '/events/by_id/1/enrollments/reject'),
    );
    test(
      'remove',
      () => expect(ep.remove(1), '/events/by_id/1/enrollments/remove'),
    );
    test(
      'approveWithdraw',
      () => expect(
        ep.approveWithdraw(1),
        '/events/by_id/1/enrollments/approve-withdraw',
      ),
    );
    test(
      'rejectWithdraw',
      () => expect(
        ep.rejectWithdraw(1),
        '/events/by_id/1/enrollments/reject-withdraw',
      ),
    );
    test('list', () => expect(ep.list(1), '/events/by_id/1/enrollments'));
  });
}
