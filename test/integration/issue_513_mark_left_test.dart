import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#513: only an active user can be marked as left, and only by
/// an admin. Marking a registered, pending or blocked user is refused with
/// 422 `INVALID_STATE` and their status is unchanged, so reactivation can
/// never make active a user who was not approved.
void main() {
  group('club_server#513: markLeft', () {
    late SecureClient admin;
    late SecureClient member;
    late bool verificationOn;
    const password = 'password123';
    const registered = 'test_i513_registered';
    const pending = 'test_i513_pending';
    const blocked = 'test_i513_blocked';
    const active = 'test_i513_active';
    const other = 'test_i513_other';
    const memberName = 'test_i513_member';

    Future<void> approved(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000513',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.male,
    );

    Future<UserInfo> registerOnly(String username) => admin.auth.register(
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000513',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.male,
    );

    Future<void> expectRefused(String username, UserStatus status) async {
      await expectLater(
        admin.users.markLeft(username),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.code, 'code', SdkErrorCode.invalidState),
        ),
      );
      expect((await admin.users.getUserInfo(username)).status, status);
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      verificationOn = (await stackCapabilities(admin)).identityVerification;

      if (verificationOn) await registerOnly(registered);
      final pen = await registerOnly(pending);
      await submitForReviewIfRequired(
        client: admin,
        registered: pen,
        password: password,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
      );
      await approved(blocked);
      await admin.users.blockUser(blocked);
      await approved(active);
      await approved(other);
      await approved(memberName);

      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login(memberName, password);
      expect((await member.auth.getCurrentUser()).username, memberName);
    });

    tearDownAll(() async {
      await member.auth.logout();
      await admin.auth.logout();
    });

    test('a registered user is refused with 422', () async {
      if (skipUnless(
        enabled: verificationOn,
        module: 'identity verification',
      )) {
        return;
      }
      await expectRefused(registered, UserStatus.registered);
    });

    test('a pending user is refused with 422', () async {
      await expectRefused(pending, UserStatus.pending);
    });

    test('a blocked user is refused with 422', () async {
      await expectRefused(blocked, UserStatus.blocked);
    });

    test('an active user is marked as left', () async {
      final left = await admin.users.markLeft(active);
      expect(left.status, UserStatus.left);
      expect((await admin.users.getUserInfo(active)).status, UserStatus.left);
    });

    test('a non-admin is refused with 403', () async {
      await expectLater(
        member.users.markLeft(other),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
      expect((await admin.users.getUserInfo(other)).status, UserStatus.active);
    });
  });
}
