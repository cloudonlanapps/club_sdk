import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Issue 26: the server refuses unknown body fields with 422
/// (club_server#325). `createUser` used to send `first_name`, which the
/// server does not declare, so every admin create carrying a name failed.
void main() {
  group('Issue 26: user name fields round-trip', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createTestClient();
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    test('Issue 26: createUser sets firstName and reads it back', () async {
      final created = await client.users.createUser(
        username: 'test_issue26_named',
        email: 'test_issue26_named@example.com',
        passwordHash: 'password123',
        phone: '9000000026',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.female,
        firstName: 'Twenty',
        middleName: 'Six',
        lastName: 'Issue',
      );
      expect(created.firstName, 'Twenty');
      expect(created.middleName, 'Six');
      expect(created.lastName, 'Issue');

      final fetched = await client.users.getUserPrivate('test_issue26_named');
      expect(fetched.firstName, 'Twenty');
      expect(fetched.lastName, 'Issue');
    });

    test('Issue 26: updateUser changes the name fields', () async {
      final updated = await client.users.updateUser(
        'test_issue26_named',
        firstName: () => 'Renamed',
        middleName: () => null,
      );
      expect(updated.firstName, 'Renamed');
      expect(updated.middleName, isNull);
      expect(updated.lastName, 'Issue');
    });
  });
}
