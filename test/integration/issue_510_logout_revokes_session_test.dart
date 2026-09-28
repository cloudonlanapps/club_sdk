import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#510: logout revokes the session it is called with.
///
/// After logout, that session's access token and refresh token are both
/// refused (401); another session of the same user keeps working. Any
/// logged-in user may log out and change their own password whatever their
/// status, so a registered and a pending user can too.
void main() {
  group('club_server#510: logout', () {
    late SecureClient admin;
    late bool verificationOn;
    const password = 'password123';
    const member = 'test_i510_member';
    const registered = 'test_i510_registered';
    const pending = 'test_i510_pending';
    const registeredPw = 'test_i510_regpw';
    const pendingPw = 'test_i510_penpw';

    Future<({SecureClient client, AuthToken token})> session(
      String username, [
      String pw = password,
    ]) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      final token = await c.auth.login(username, pw);
      expect((await c.auth.getCurrentUser()).username, username);
      return (client: c, token: token);
    }

    Matcher refused(String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.code, 'code', code),
    );

    /// Both tokens of [token] are refused once its session has logged out.
    Future<void> expectRevoked(AuthToken token) async {
      final withAccess = await createRemoteSecureClient(
        baseUrl: baseUrl,
        authToken: token.accessToken,
      );
      await expectLater(
        withAccess.auth.getCurrentUser(),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      final bare = await createRemoteSecureClient(baseUrl: baseUrl);
      await expectLater(
        bare.auth.refreshToken(token.refreshToken!),
        refused(SdkErrorCode.invalidRefreshToken),
      );
    }

    Future<UserInfo> registerOnly(String username) => admin.auth.register(
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000510',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.male,
    );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      verificationOn = (await stackCapabilities(admin)).identityVerification;

      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: member,
        email: '$member@test.com',
        password: password,
        firstName: member,
        phone: '0000000510',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.male,
      );

      // With verification off, register lands at pending and no user is
      // ever registered; the registered cases skip there.
      final reg = await registerOnly(registered);
      expect(
        reg.status,
        verificationOn ? UserStatus.registered : UserStatus.pending,
      );

      final pen = await registerOnly(pending);
      await submitForReviewIfRequired(
        client: admin,
        registered: pen,
        password: password,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
      );
      expect(
        (await admin.users.getUserInfo(pending)).status,
        UserStatus.pending,
      );
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    group('an active member', () {
      test(
        'logging out refuses the access and refresh token of that session',
        () async {
          final s = await session(member);
          await s.client.auth.logout();
          await expectRevoked(s.token);
        },
      );

      test(
        'logging out leaves another session of the same user working',
        () async {
          final kept = await session(member);
          final ended = await session(member);
          await ended.client.auth.logout();

          expect((await kept.client.auth.getCurrentUser()).username, member);
          final bare = await createRemoteSecureClient(baseUrl: baseUrl);
          final refreshed = await bare.auth.refreshToken(
            kept.token.refreshToken!,
          );
          expect(refreshed.accessToken, isNotEmpty);
          await kept.client.auth.logout();
        },
      );
    });

    group('a registered user', () {
      test('can log out, and the session is revoked', () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final s = await session(registered);
        expect(
          (await s.client.auth.getCurrentUser()).status,
          UserStatus.registered,
        );
        await s.client.auth.logout();
        await expectRevoked(s.token);
      });

      test('can change their own password', () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final s = await session(registered);
        await s.client.auth.changePassword(
          currentPassword: password,
          newPassword: registeredPw,
        );
        final fresh = await session(registered, registeredPw);
        expect(
          (await fresh.client.auth.getCurrentUser()).status,
          UserStatus.registered,
        );
      });
    });

    group('a pending user', () {
      test('can log out, and the session is revoked', () async {
        final s = await session(pending);
        expect(
          (await s.client.auth.getCurrentUser()).status,
          UserStatus.pending,
        );
        await s.client.auth.logout();
        await expectRevoked(s.token);
      });

      test('can change their own password', () async {
        final s = await session(pending);
        await s.client.auth.changePassword(
          currentPassword: password,
          newPassword: pendingPw,
        );
        final fresh = await session(pending, pendingPw);
        expect(
          (await fresh.client.auth.getCurrentUser()).status,
          UserStatus.pending,
        );
      });
    });
  });
}
