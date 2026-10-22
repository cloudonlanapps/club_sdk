import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

const _password = 'password123';
const _admin = 'test_admin_i54';

/// Issue 54 (club_server#62): an admin may not block, mark as left or
/// delete their own account. Each is refused with 422 `CANNOT_ACT_ON_SELF`
/// and the account is unchanged.
void main() {
  group('Issue 54: CANNOT_ACT_ON_SELF', () {
    late SecureClient sudo;
    late SecureClient admin;

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      await registerAndApprove(
        client: sudo,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: _admin,
        email: '$_admin@test.com',
        password: _password,
        firstName: 'I54',
        phone: '0000000054',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await sudo.users.assignRole(_admin, 'admin');

      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await admin.auth.login(_admin, _password);
      final me = await admin.auth.getCurrentUser();
      expect(me.username, _admin);
      expect(me.roles.isAdmin, isTrue);
    });

    tearDownAll(() async {
      for (final c in [admin, sudo]) {
        try {
          await c.auth.logout();
        } on Exception {
          /* ignore */
        }
      }
    });

    Matcher refusedOnSelf() => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', SdkErrorCode.cannotActOnSelf),
    );

    Future<void> expectUnchanged() async {
      final stored = await sudo.users.getUserInfo(_admin);
      expect(stored.status, UserStatus.active);
      expect(stored.deletedAtUtc, isNull);
    }

    test('Issue 54: an admin blocking themselves is CANNOT_ACT_ON_SELF and '
        'stays active', () async {
      await expectLater(admin.users.blockUser(_admin), refusedOnSelf());
      await expectUnchanged();
    });

    test('Issue 54: an admin marking themselves as left is '
        'CANNOT_ACT_ON_SELF and stays active', () async {
      await expectLater(admin.users.markLeft(_admin), refusedOnSelf());
      await expectUnchanged();
    });

    test('Issue 54: an admin deleting themselves is CANNOT_ACT_ON_SELF and '
        'is not deleted', () async {
      await expectLater(admin.users.deleteUser(_admin), refusedOnSelf());
      await expectUnchanged();
    });
  });
}
