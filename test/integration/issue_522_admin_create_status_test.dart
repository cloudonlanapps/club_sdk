import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// club_server#522: admin user creation creates `active` users only.
///
/// `createUser` no longer takes a status. The server's request field still
/// exists, so these cases post it raw through the [RemoteStore]: an unknown
/// value, and every status but `active`, is refused with 422 and no user is
/// created. With no status, or `active`, the user is active.
void main() {
  group('club_server#522: admin user creation', () {
    late RemoteStore store;
    late SecureClient admin;
    var next = 0;

    Future<Map<String, dynamic>> createRaw(String username, String? status) =>
        store.post(
          '/users',
          body: {
            'username': username,
            'email': '$username@test.com',
            'passwordHash': 'password123',
            'phone': '0000000522',
            'dateOfBirthUtc': DateTime.utc(1995).millisecondsSinceEpoch,
            'gender': Gender.male.serverValue,
            'firstName': username,
            'status': ?status,
          },
        );

    Matcher throws422() => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', SdkErrorCode.validationError),
    );

    Future<void> expectNoUser(String username) => expectLater(
      admin.users.getUserPrivate(username),
      throwsA(
        isA<ServerException>().having(
          (e) => e.code,
          'code',
          SdkErrorCode.userNotFound,
        ),
      ),
    );

    setUpAll(() async {
      store = RemoteStore(baseUrl: baseUrl);
      admin = await createRemoteSecureClient(baseUrl: baseUrl, store: store);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    for (final status in [
      'activ',
      'left',
      'blocked',
      'pending',
      'registered',
    ]) {
      test(
        'status "$status" is refused with 422 and no user is created',
        () async {
          final username = 'test_i522_${status}_${next++}';
          await expectLater(createRaw(username, status), throws422());
          await expectNoUser(username);
        },
      );
    }

    test('no status creates an active user', () async {
      final created = await admin.users.createUser(
        username: 'test_i522_default',
        email: 'test_i522_default@test.com',
        passwordHash: 'password123',
        phone: '0000000522',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.male,
        firstName: 'Default',
        lastName: 'Status',
      );
      expect(created.status, UserStatus.active);
      final readback = await admin.users.getUserPrivate('test_i522_default');
      expect(readback.status, UserStatus.active);
    });

    test('status "active" creates an active user', () async {
      await createRaw('test_i522_active', 'active');
      final readback = await admin.users.getUserPrivate('test_i522_active');
      expect(readback.status, UserStatus.active);
    });
  });
}
