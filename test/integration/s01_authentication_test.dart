import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 1: Authentication Test Suite.
///
/// Tests requirements from Section 1 (Authentication):
/// - 1.01: Register User
/// - 1.02: Login with Password
/// - 1.04: Logout
/// - 1.05: Request Password Reset
/// - 1.06: Get Current User
/// - 1.09: Refresh Token
/// - 1.10: Change Password
void main() {
  group('Section 1: Authentication', () {
    late SecureClient client;
    // Where a new sign-up lands: registered, or pending when the stack has
    // identity verification off (#2).
    late UserStatus signUpAs;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // Clean all test_ artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // Seed one user (test_alice) needed by login/logout/refresh/reset tests
      await client.auth.login(sudoUsername, sudoPassword);
      signUpAs = signUpStatus(await stackCapabilities(client));

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_alice',
        email: 'test_alice@test.com',
        password: 'password123',
        firstName: 'Alice Smith',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      await client.auth.logout();
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // Not logged in — ignore
      }
    });

    group('1.01: Register User', () {
      test('creates new account with required fields', () async {
        final user = await client.auth.register(
          username: 'test_new_user_101',
          email: 'test_newuser_101@test.com',
          password: 'securePass123',
          firstName: 'New User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        expect(user.username, 'test_new_user_101');
        expect(user.status, signUpAs);
      });

      test('username must be unique', () async {
        await client.auth.register(
          username: 'test_unique_user_101',
          email: 'test_unique1@test.com',
          password: 'securePass123',
          firstName: 'First User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        expect(
          () => client.auth.register(
            username: 'test_unique_user_101',
            email: 'test_unique2@test.com',
            password: 'securePass123',
            firstName: 'Second User',
            phone: '0000000000',
            dateOfBirthUtc: DateTime.utc(2000),
            gender: Gender.male,
          ),
          throwsA(anything),
        );
      });

      test('email must be unique', () async {
        await client.auth.register(
          username: 'test_email_user_101a',
          email: 'test_same_email_101@test.com',
          password: 'securePass123',
          firstName: 'First User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        expect(
          () => client.auth.register(
            username: 'test_email_user_101b',
            email: 'test_same_email_101@test.com',
            password: 'securePass123',
            firstName: 'Second User',
            phone: '0000000000',
            dateOfBirthUtc: DateTime.utc(2000),
            gender: Gender.male,
          ),
          throwsA(anything),
        );
      });

      test('creates account with optional phone and dateOfBirth', () async {
        final dob = DateTime.utc(2005, 6, 15);
        final user = await client.auth.register(
          username: 'test_optional_fields_101',
          email: 'test_optional_101@test.com',
          password: 'securePass123',
          firstName: 'Optional Fields User',
          phone: '+919876543210',
          dateOfBirthUtc: dob,
          gender: Gender.male,
        );

        expect(user.username, 'test_optional_fields_101');
        expect(user.status, signUpAs);
      });

      test('registered user can login (to call submitForReview)', () async {
        await client.auth.register(
          username: 'test_registered_user_101',
          email: 'test_registered_101@test.com',
          password: 'securePass123',
          firstName: 'Registered User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        final token = await client.auth.login(
          'test_registered_user_101',
          'securePass123',
        );
        expect(token.accessToken, isNotEmpty);

        final currentUser = await client.auth.getCurrentUser();
        expect(currentUser.status, signUpAs);
      });
    });

    group('1.02: Login with Password', () {
      test('returns AuthToken on success', () async {
        final token = await client.auth.login('test_alice', 'password123');

        expect(token, isNotNull);
        expect(token.accessToken, isNotEmpty);

        final user = await client.auth.getCurrentUser();
        expect(user.username, 'test_alice');
      });

      test('throws on invalid credentials', () async {
        expect(
          () => client.auth.login('test_alice', 'wrongpassword'),
          throwsA(anything),
        );
      });

      test('throws on non-existent user', () async {
        expect(
          () => client.auth.login('nonexistent_user', 'password123'),
          throwsA(anything),
        );
      });
    });

    group('1.04: Logout', () {
      test('invalidates current authentication', () async {
        await client.auth.login('test_alice', 'password123');
        await client.auth.logout();

        expect(
          client.auth.getCurrentUser,
          throwsA(anything),
        );
      });
    });

    group('1.05: Request Password Reset', () {
      // resetPassword is an immediate rotation server-side, not a "send a
      // link" call, so it must not target a user other tests log in as.
      // Pointing it at test_alice rotated her password out from under 1.06
      // and 1.09, which then failed with INVALID_CREDENTIALS depending only
      // on execution order.
      test('initiates reset flow for existing email', () async {
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: 'test_reset_105',
          email: 'test_reset_105@test.com',
          password: 'resetMe123',
          firstName: 'Reset Test User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.auth.resetPassword('test_reset_105@test.com');

        // The rotation must invalidate the old credential.
        await client.auth.logout();
        expect(
          () => client.auth.login('test_reset_105', 'resetMe123'),
          throwsA(anything),
        );
        await client.auth.login(sudoUsername, sudoPassword);
      });

      test('does not throw for unknown email', () async {
        await client.auth.resetPassword('unknown@test.com');
      });
    });

    group('1.06: Get Current User', () {
      test('returns authenticated user profile', () async {
        await client.auth.login('test_alice', 'password123');
        final user = await client.auth.getCurrentUser();

        expect(user.username, 'test_alice');
        expect(user.email, isNotNull);
      });

      test('throws when not authenticated', () async {
        expect(
          client.auth.getCurrentUser,
          throwsA(anything),
        );
      });
    });

    group('1.09: Refresh Token', () {
      test('returns new access token', () async {
        final initialToken = await client.auth.login(
          'test_alice',
          'password123',
        );

        final refreshTokenValue = initialToken.refreshToken;
        if (refreshTokenValue != null) {
          final newToken = await client.auth.refreshToken(refreshTokenValue);

          expect(newToken, isNotNull);
          expect(newToken.accessToken, isNotEmpty);

          final user = await client.auth.getCurrentUser();
          expect(user.username, 'test_alice');
        }
      });

      test('throws on invalid refresh token', () async {
        expect(
          () => client.auth.refreshToken('invalid_refresh_token'),
          throwsA(anything),
        );
      });
    });

    group('1.10: Change Password', () {
      test('updates password successfully', () async {
        // Register and approve a fresh user for password change test
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: 'test_change_pass_110',
          email: 'test_changepass_110@test.com',
          password: 'oldPassword123',
          firstName: 'Password Test User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.auth.logout();

        await client.auth.login('test_change_pass_110', 'oldPassword123');

        await client.auth.changePassword(
          currentPassword: 'oldPassword123',
          newPassword: 'newPassword456',
        );

        // The change revokes every token issued before it (#31), including
        // this session's: the old token no longer authenticates. The server
        // refuses logout with it too, but logout still signs the client out
        // locally (#45).
        final revoked = isA<ServerException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.code, 'code', 'INVALID_TOKEN');
        await expectLater(client.auth.getCurrentUser(), throwsA(revoked));
        await client.auth.logout();
        await expectLater(
          client.auth.getCurrentUser(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        // The old password is refused; the new one logs in.
        await expectLater(
          client.auth.login('test_change_pass_110', 'oldPassword123'),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having(
                  (e) => e.code,
                  'code',
                  SdkErrorCode.invalidCredentials,
                ),
          ),
        );
        final token = await client.auth.login(
          'test_change_pass_110',
          'newPassword456',
        );
        expect(token.accessToken, isNotEmpty);
        final user = await client.auth.getCurrentUser();
        expect(user.username, 'test_change_pass_110');
      });

      test('throws on incorrect current password', () async {
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: 'test_change_pass_110b',
          email: 'test_changepass_110b@test.com',
          password: 'correctPassword',
          firstName: 'Password Test User B',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.auth.logout();

        await client.auth.login('test_change_pass_110b', 'correctPassword');

        // Verify we are authenticated before testing the rejection
        final user = await client.auth.getCurrentUser();
        expect(user.username, 'test_change_pass_110b');

        expect(
          () => client.auth.changePassword(
            currentPassword: 'wrongPassword',
            newPassword: 'newPassword456',
          ),
          throwsA(isA<ServerException>()),
        );
      });

      test('throws when not authenticated', () async {
        expect(
          () => client.auth.changePassword(
            currentPassword: 'any',
            newPassword: 'any',
          ),
          throwsA(anything),
        );
      });
    });

    group('1.11: Check Username Availability', () {
      test('returns false for an already-registered username', () async {
        // test_alice was registered in setUpAll.
        final available = await client.auth.isUsernameAvailable('test_alice');
        expect(available, isFalse);
      });

      test('returns true for a novel username', () async {
        final available = await client.auth.isUsernameAvailable(
          'test_novel_username_111',
        );
        expect(available, isTrue);
      });

      test('works without authentication', () async {
        // Ensure we are logged out, then call the endpoint.
        try {
          await client.auth.logout();
        } on Exception {
          // already logged out
        }
        final available = await client.auth.isUsernameAvailable('test_alice');
        expect(available, isFalse);
      });
    });
  });
}
