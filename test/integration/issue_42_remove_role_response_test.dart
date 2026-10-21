import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

const _password = 'password123';
const _admin = 'test_admin_i42';
const _target = 'test_target_i42';
const _member = 'test_member_i42';

/// Issue 42: removeRole returns the user the server's DELETE answers with,
/// and that user is the one stored.
void main() {
  group('Issue 42: removeRole returns the DELETE response', () {
    late SecureClient adminClient;
    late SecureClient memberClient;

    setUpAll(() async {
      final setup = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: setup,
        username: sudoUsername,
        password: sudoPassword,
      );
      await setup.auth.login(sudoUsername, sudoPassword);
      for (final username in [_admin, _target, _member]) {
        await registerAndApprove(
          client: setup,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: _password,
          firstName: 'I42',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
      }
      await setup.users.assignRole(_admin, 'admin');
      await setup.auth.logout();

      Future<SecureClient> loggedIn(String username) async {
        final c = await createRemoteSecureClient(baseUrl: baseUrl);
        await c.auth.login(username, _password);
        expect((await c.auth.getCurrentUser()).username, username);
        return c;
      }

      adminClient = await loggedIn(_admin);
      memberClient = await loggedIn(_member);
    });

    tearDownAll(() async {
      for (final c in [adminClient, memberClient]) {
        try {
          await c.auth.logout();
        } on Exception {
          /* ignore */
        }
      }
    });

    test('Issue 42: the returned user has the role removed and keeps the '
        'others', () async {
      await adminClient.users.assignRole(_target, 'coach');
      final withBoth = await adminClient.users.assignRole(_target, 'admin');
      expect(withBoth.roles.isCoach, isTrue);
      expect(withBoth.roles.isAdmin, isTrue);

      final updated = await adminClient.users.removeRole(_target, 'coach');

      expect(updated.username, _target);
      expect(updated.roles.isCoach, isFalse);
      expect(updated.roles.isAdmin, isTrue);

      final stored = await adminClient.users.getUserInfo(_target);
      expect(stored.roles.isCoach, isFalse);
      expect(stored.roles.isAdmin, isTrue);
    });

    test('Issue 42: removing a role the user does not have is '
        'ROLE_NOT_FOUND', () async {
      await expectLater(
        adminClient.users.removeRole(_member, 'coach'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', SdkErrorCode.roleNotFound),
        ),
      );
    });

    test('Issue 42: a member may not remove a role', () async {
      await adminClient.users.assignRole(_target, 'coach');
      await expectLater(
        memberClient.users.removeRole(_target, 'coach'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      final stored = await adminClient.users.getUserInfo(_target);
      expect(stored.roles.isCoach, isTrue);
    });
  });
}
