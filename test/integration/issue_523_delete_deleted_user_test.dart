import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#523: soft-deleting a user who is already soft-deleted
/// answers 422 `ALREADY_DELETED`, not the 404 an unknown user gets.
void main() {
  group('club_server#523: deleting a deleted user', () {
    late SecureClient admin;
    const username = 'test_i523_user';

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: username,
        email: '$username@test.com',
        password: 'password123',
        firstName: username,
        phone: '0000000523',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.male,
      );
      await admin.users.deleteUser(username);
      final deleted = await admin.users.getDeletedUsers(searchTerm: username);
      expect(deleted.items.map((u) => u.username), contains(username));
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('a second soft delete is refused with 422 ALREADY_DELETED', () async {
      await expectLater(
        admin.users.deleteUser(username),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.code, 'code', SdkErrorCode.alreadyDeleted),
        ),
      );
      final deleted = await admin.users.getDeletedUsers(searchTerm: username);
      expect(deleted.items.map((u) => u.username), contains(username));
    });

    test('an unknown username is still 404 USER_NOT_FOUND', () async {
      await expectLater(
        admin.users.deleteUser('test_i523_nobody'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', SdkErrorCode.userNotFound),
        ),
      );
    });
  });
}
