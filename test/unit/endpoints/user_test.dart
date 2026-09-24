import 'package:club_sdk_2/remote_store/endpoints/user.dart';
import 'package:test/test.dart';

void main() {
  const ep = UserEndpoints();

  group('UserEndpoints', () {
    test('list', () => expect(ep.list, '/users'));
    test('deleted', () => expect(ep.deleted, '/users/deleted'));
    test('Issue 30: count', () => expect(ep.count, '/users/count'));
    test('user', () => expect(ep.user('alice'), '/users/by_id/alice'));
    test(
      'userPrivate',
      () => expect(ep.userPrivate('alice'), '/users/by_id/alice/private'),
    );
    test(
      'restore',
      () => expect(ep.restore('alice'), '/users/by_id/alice/restore'),
    );
    test(
      'approve',
      () => expect(ep.approve('alice'), '/users/by_id/alice/approve'),
    );
    test('block', () => expect(ep.block('alice'), '/users/by_id/alice/block'));
    test(
      'unblock',
      () => expect(ep.unblock('alice'), '/users/by_id/alice/unblock'),
    );
    test(
      'markLeft',
      () => expect(ep.markLeft('alice'), '/users/by_id/alice/mark-left'),
    );
    test(
      'reactivate',
      () => expect(ep.reactivate('alice'), '/users/by_id/alice/reactivate'),
    );
    test('roles', () => expect(ep.roles('alice'), '/users/by_id/alice/roles'));
    test(
      'removeRole',
      () => expect(
        ep.removeRole('alice', 'coach'),
        '/users/by_id/alice/roles/coach',
      ),
    );
    test(
      'transferSuperAdmin',
      () => expect(
        ep.transferSuperAdmin('alice'),
        '/users/by_id/alice/transfer-superadmin',
      ),
    );
    test(
      'hardDelete',
      () => expect(ep.hardDelete('alice'), '/users/by_id/alice/hard'),
    );
    test(
      'adminResetPassword',
      () =>
          expect(ep.adminResetPassword('alice'), '/admin/reset-password/alice'),
    );
  });
}
