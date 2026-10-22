import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

const _password = 'password123';
const _target = 'test_target_i53';

/// Issue 53: deleteUser returns the soft-deleted user the server's DELETE
/// answers with.
void main() {
  group('Issue 53: deleteUser returns the DELETE response', () {
    late SecureClient admin;

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
        username: _target,
        email: '$_target@test.com',
        password: _password,
        firstName: 'I53',
        phone: '0000000053',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('Issue 53: soft-deleting a user returns that user with '
        'deletedAtUtc set', () async {
      final before = await admin.users.getUserInfo(_target);
      expect(before.deletedAtUtc, isNull);

      final deleted = await admin.users.deleteUser(_target);

      expect(deleted.username, _target);
      expect(deleted.deletedAtUtc, isNotNull);

      final listed = await admin.users.getDeletedUsers(searchTerm: _target);
      expect(listed.items.map((u) => u.username), contains(_target));
    });
  });
}
