import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#519: the super admin cannot hold credit.
///
/// The super admin is a housekeeping account, not a member. Opening a credit
/// account for them is refused with 422 `SUPER_ADMIN_CANNOT_HOLD_CREDIT` and
/// no account exists afterwards. Opening is the only way credit is granted
/// into a user's name (a transfer opens its account for the same member), so
/// it is the one call to guard. An ordinary user still gets an account.
///
/// Runs on both stacks: with the credit system off the calls answer 503.
void main() {
  group('club_server#519: the super admin cannot hold credit', () {
    late SecureClient admin;
    late bool creditsOn;
    const memberName = 'test_i519_member';

    Future<CreditAccount> openFor(String membername) =>
        admin.credits.openAccount(
          membername: membername,
          credits: 4,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(60),
          reason: 'test_i519 grant',
        );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      creditsOn = (await stackCapabilities(admin)).creditSystem;
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: memberName,
        email: '$memberName@example.com',
        password: 'password123',
        phone: '+919000000519',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
        firstName: 'Test',
        lastName: memberName,
      );
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('with the credit system off, opening an account answers 503', () {
      if (skipIf(enabled: creditsOn, feature: 'credit system')) return;
      expect(
        openFor(sudoUsername),
        throwsModuleDisabled(SdkErrorCode.creditSystemDisabled),
      );
    });

    test('Issue 519: opening an account for the super admin answers 422 '
        'SUPER_ADMIN_CANNOT_HOLD_CREDIT and opens none', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;
      await expectLater(
        openFor(sudoUsername),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 422)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.superAdminCannotHoldCredit,
              ),
        ),
      );

      final accounts = await admin.credits.listAccounts(
        membername: sudoUsername,
      );
      expect(accounts.items, isEmpty);
    });

    test('Issue 519: an ordinary user still gets an account', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;
      final opened = await openFor(memberName);
      expect(opened.membername, memberName);
      expect(opened.balance, 4);

      final accounts = await admin.credits.listAccounts(
        membername: memberName,
      );
      expect(
        accounts.items.map((a) => a.accountId),
        contains(opened.accountId),
      );
    });
  });
}
