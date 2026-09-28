import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#514: `super_admin` is not a role. Super admin is the
/// `isSuperAdmin` flag and changes only by transfer, so the role endpoints
/// refuse `super_admin` with 422 on both assign and remove, and the user's
/// roles are unchanged. The SDK's `Role` enum no longer offers it, so these
/// cases send the raw string.
void main() {
  group('club_server#514: super_admin as a role value', () {
    late SecureClient admin;
    const member = 'test_i514_member';
    const coach = 'test_i514_coach';

    Matcher throws422() => throwsA(
      isA<ServerException>().having((e) => e.statusCode, 'statusCode', 422),
    );

    Future<void> register(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: 'password123',
      firstName: username,
      phone: '0000000514',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.female,
    );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      await register(member);
      await register(coach);
      await admin.users.assignRole(coach, 'coach');
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('assigning super_admin is refused with 422', () async {
      await expectLater(
        admin.users.assignRole(member, 'super_admin'),
        throws422(),
      );
      final readback = await admin.users.getUserInfo(member);
      expect(readback.roles.rawRoles, isEmpty);
      expect(readback.isSuperAdmin, isFalse);
    });

    test(
      'assigning super_admin to a coach leaves the coach role alone',
      () async {
        await expectLater(
          admin.users.assignRole(coach, 'super_admin'),
          throws422(),
        );
        final readback = await admin.users.getUserInfo(coach);
        expect(readback.roles.rawRoles, [Role.coach]);
        expect(readback.isSuperAdmin, isFalse);
      },
    );

    test('removing super_admin is refused with 422', () async {
      await expectLater(
        admin.users.removeRole(coach, 'super_admin'),
        throws422(),
      );
      final readback = await admin.users.getUserInfo(coach);
      expect(readback.roles.rawRoles, [Role.coach]);
    });

    test('removing super_admin from the super admin is refused and they stay '
        'super admin', () async {
      await expectLater(
        admin.users.removeRole(sudoUsername, 'super_admin'),
        throws422(),
      );
      final me = await admin.auth.getCurrentUser();
      expect(me.isSuperAdmin, isTrue);
    });
  });
}
