import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#505: the username-availability check and registration agree.
///
/// A soft-deleted user still holds their username: registering it is
/// refused with 409, so the availability check reports it taken.
void main() {
  group('club_server#505: username of a soft-deleted user', () {
    late SecureClient admin;
    late SecureClient anonymous; // the check needs no token
    const deleted = 'test_i505_deleted';

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      anonymous = await createRemoteSecureClient(baseUrl: baseUrl);
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
        username: deleted,
        email: '$deleted@test.com',
        password: 'password123',
        firstName: deleted,
        phone: '0000000505',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.male,
      );
      expect(await anonymous.auth.isUsernameAvailable(deleted), isFalse);
      await admin.users.deleteUser(deleted);
      final gone = await admin.users.getDeletedUsers(searchTerm: deleted);
      expect(gone.items.map((u) => u.username), contains(deleted));
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('registering the username is refused with 409', () async {
      await expectLater(
        anonymous.auth.register(
          username: deleted,
          email: 'test_i505_other@test.com',
          password: 'password123',
          firstName: 'Other',
          phone: '0000000505',
          dateOfBirthUtc: DateTime.utc(1995),
          gender: Gender.female,
        ),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('the availability check reports the username taken', () async {
      expect(await anonymous.auth.isUsernameAvailable(deleted), isFalse);
    });

    test('an unused username is still reported available', () async {
      expect(
        await anonymous.auth.isUsernameAvailable('test_i505_unused'),
        isTrue,
      );
    });
  });
}
