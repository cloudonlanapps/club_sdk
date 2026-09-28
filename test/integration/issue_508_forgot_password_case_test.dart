import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#508: the forgotten-password lookup ignores the case of the
/// address, as email uniqueness does.
///
/// The response is always 204 so a caller cannot probe for accounts; the
/// outcome is visible only in the super admin's audit row
/// (`password_reset_requested`, `details.accountExists`).
void main() {
  group('club_server#508: forgotten-password lookup', () {
    late SecureClient admin;
    late SecureClient anonymous;
    const username = 'test_i508_user';
    const email = 'test_i508_user@test.com';
    const action = 'password_reset_requested';

    Future<List<AuditLogRow>> resetRows() async =>
        (await admin.auditLog.list(action: action, limit: 50)).rows;

    /// Requests a reset for [typed] and returns whether the one audit row it
    /// wrote found an account. The server may normalise the address it
    /// records (the domain's case), so the row is the one newer than the
    /// request rather than one matched by text.
    Future<bool?> accountExistsFor(String typed) async {
      final before = (await resetRows()).fold<int>(
        0,
        (m, r) => r.id > m ? r.id : m,
      );
      await anonymous.auth.resetPassword(typed);
      final rows = (await resetRows()).where((r) => r.id > before).toList();
      expect(rows, hasLength(1));
      expect(
        (rows.single.details!['email'] as String).toLowerCase(),
        typed.toLowerCase(),
      );
      return rows.single.details!['accountExists'] as bool?;
    }

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
        username: username,
        email: email,
        password: 'password123',
        firstName: username,
        phone: '0000000508',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.male,
      );
      expect((await admin.users.getUserPrivate(username)).email, email);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('the address as stored finds the account', () async {
      expect(await accountExistsFor(email), isTrue);
    });

    test('the address in different capitals finds the account', () async {
      expect(await accountExistsFor('Test_I508_User@TEST.com'), isTrue);
    });

    test('an unknown address finds none', () async {
      expect(await accountExistsFor('test_i508_nobody@test.com'), isFalse);
    });
  });
}
