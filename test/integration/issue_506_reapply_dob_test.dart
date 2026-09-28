import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// club_server#506: reapply checks the date of birth like registration and
/// profile updates do: one that is not a UTC midnight is refused with 422
/// and nothing changes; a midnight one is accepted.
///
/// Reapply exists only in the review lifecycle, which needs identity
/// verification on, so these cases skip on a stack with it off.
void main() {
  group('club_server#506: reapply date of birth', () {
    late SecureClient admin;
    late bool verificationOn;
    const password = 'password123';
    final original = DateTime.utc(1995, 6, 15);

    /// A registered user with an active review request, so that reapply is
    /// open to them: registered, document attached, submitted, and sent
    /// back by the admin. Returns their logged-in client.
    Future<SecureClient> reconsidered(String username) async {
      await admin.auth.register(
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: username,
        phone: '0000000506',
        dateOfBirthUtc: original,
        gender: Gender.male,
      );
      final user = await createRemoteSecureClient(baseUrl: baseUrl);
      await user.auth.login(username, password);
      await attachIdentityDocument(user, username);
      await user.users.submitForReview();
      await admin.users.reconsiderUser(username, 'check your date of birth');
      expect(
        (await user.auth.getCurrentUser()).status,
        UserStatus.registered,
      );
      return user;
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
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test(
      'a date of birth that is not a UTC midnight is refused with 422',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        const username = 'test_i506_offmidnight';
        final user = await reconsidered(username);
        await expectLater(
          user.users.reapply(
            username,
            dateOfBirthUtc: DateTime.utc(1996, 3, 10, 13, 30),
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              422,
            ),
          ),
        );
        expect((await user.auth.getCurrentUser()).dateOfBirthUtc, original);
      },
    );

    test('a UTC-midnight date of birth is accepted', () async {
      if (skipUnless(
        enabled: verificationOn,
        module: 'identity verification',
      )) {
        return;
      }
      const username = 'test_i506_midnight';
      final user = await reconsidered(username);
      final midnight = DateTime.utc(1996, 3, 10);
      final updated = await user.users.reapply(
        username,
        dateOfBirthUtc: midnight,
      );
      expect(updated.dateOfBirthUtc, midnight);
      expect((await user.auth.getCurrentUser()).dateOfBirthUtc, midnight);
    });
  });
}
