import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#507: login refuses a user who has left, as it refuses a
/// blocked one: 401 `ACCOUNT_LEFT` (the code the token check already uses),
/// and the client holds no token afterwards.
void main() {
  group('club_server#507: login of a user who has left', () {
    late SecureClient admin;
    const password = 'password123';
    const left = 'test_i507_left';
    const blocked = 'test_i507_blocked';

    Future<void> register(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000507',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.male,
    );

    Matcher refused(String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.code, 'code', code),
    );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      await register(left);
      await register(blocked);
      expect((await admin.users.markLeft(left)).status, UserStatus.left);
      expect(
        (await admin.users.blockUser(blocked)).status,
        UserStatus.blocked,
      );
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test(
      'a left user is refused with 401 ACCOUNT_LEFT and holds no token',
      () async {
        final store = RemoteStore(baseUrl: baseUrl);
        final client = await createRemoteSecureClient(
          baseUrl: baseUrl,
          store: store,
        );
        await expectLater(
          client.auth.login(left, password),
          refused(SdkErrorCode.accountLeft),
        );
        expect(store.authToken, isNull);
      },
    );

    test('a blocked user is still refused with 401 ACCOUNT_BLOCKED', () async {
      final store = RemoteStore(baseUrl: baseUrl);
      final client = await createRemoteSecureClient(
        baseUrl: baseUrl,
        store: store,
      );
      await expectLater(
        client.auth.login(blocked, password),
        refused(SdkErrorCode.accountBlocked),
      );
      expect(store.authToken, isNull);
    });

    test('once reactivated, the user logs in again', () async {
      await admin.users.reactivateUser(left);
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(left, password);
      expect((await client.auth.getCurrentUser()).username, left);
      await client.auth.logout();
      await admin.users.markLeft(left);
    });
  });
}
