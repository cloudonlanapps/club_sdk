import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 2: identity-document verification is optional per deployment
/// (club_server#428), and `Capabilities.identityVerification` says which.
///
/// `sdk_test.conf` leaves it on (the default) and `sdk_test_modules.conf`
/// turns it off, so `just test` covers the first half of this file and
/// `just test-modules` the second; each case skips itself on the other
/// stack rather than passing without asserting.
void main() {
  group('Issue 2: identity verification', () {
    late SecureClient admin;
    late bool verificationOn;
    final opened = <SecureClient>[];
    const password = 'password123';
    var n = 0;

    Future<UserInfo> registerFresh(String tag) async {
      n += 1;
      final username = 'test_i2_${tag}_$n';
      return admin.auth.register(
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: username,
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: DateTime.utc(1995, 6, 15),
      );
    }

    Future<SecureClient> loginAs(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(c);
      await c.auth.login(username, password);
      return c;
    }

    /// The highest notification id in the admin's inbox, so a case measures
    /// only what it caused.
    Future<int> inboxHighWater() async {
      final inbox = await admin.notifications.getNotifications(limit: 100);
      return inbox.items.fold<int>(0, (m, e) => e.id > m ? e.id : m);
    }

    Future<List<AppNotification>> approvalsFor(
      String username, {
      required int after,
    }) async {
      final inbox = await admin.notifications.getNotifications(limit: 100);
      return inbox.items
          .where(
            (e) =>
                e.id > after &&
                e.pendingActionType == PendingActionType.userApproval &&
                e.pendingActionKey == username,
          )
          .toList();
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(admin);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      verificationOn = (await stackCapabilities(admin)).identityVerification;
    });

    tearDownAll(() async {
      for (final c in opened) {
        try {
          await c.auth.logout();
        } on Exception {
          /* already out, or never active */
        }
      }
    });

    test('capabilities agree with where register lands a user', () async {
      final user = await registerFresh('agree');
      expect(
        user.status,
        verificationOn ? UserStatus.registered : UserStatus.pending,
      );
      final readback = await admin.users.getUserPrivate(user.username);
      expect(readback.status, user.status);
    });

    group('on', () {
      test('register lands the user at registered, with no admin '
          'approval yet', () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final before = await inboxHighWater();
        final user = await registerFresh('on_reg');
        expect(user.status, UserStatus.registered);
        expect(await approvalsFor(user.username, after: before), isEmpty);
      });

      test('submitForReview without an identity document is refused with '
          'IDENTITY_DOCUMENT_REQUIRED', () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final user = await registerFresh('on_nodoc');
        final self = await loginAs(user.username);
        await expectLater(
          self.users.submitForReview(),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'status', 422)
                .having((e) => e.code, 'code', 'IDENTITY_DOCUMENT_REQUIRED'),
          ),
        );
        final readback = await admin.users.getUserPrivate(user.username);
        expect(readback.status, UserStatus.registered);
      });

      test(
        'with a document, submitForReview takes the user to pending',
        () async {
          if (skipUnless(
            enabled: verificationOn,
            module: 'identity verification',
          )) {
            return;
          }
          final user = await registerFresh('on_doc');
          final self = await loginAs(user.username);
          await attachIdentityDocument(self, user.username);
          final submitted = await self.users.submitForReview();
          expect(submitted.status, UserStatus.pending);
          final readback = await admin.users.getUserPrivate(user.username);
          expect(readback.status, UserStatus.pending);
        },
      );
    });

    group('off', () {
      test('register lands the user at pending and notifies the admins at '
          'once', () async {
        if (skipIf(enabled: verificationOn, feature: 'identity verification')) {
          return;
        }
        final before = await inboxHighWater();
        final user = await registerFresh('off_reg');
        expect(user.status, UserStatus.pending);

        final readback = await admin.users.getUserPrivate(user.username);
        expect(readback.status, UserStatus.pending);
        expect(await approvalsFor(user.username, after: before), hasLength(1));
      });

      test(
        'submitForReview is refused with 409 for a user already pending',
        () async {
          if (skipIf(
            enabled: verificationOn,
            feature: 'identity verification',
          )) {
            return;
          }
          final user = await registerFresh('off_resubmit');
          final self = await loginAs(user.username);
          await expectLater(
            self.users.submitForReview(),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'status', 409)
                  .having((e) => e.code, 'code', 'INVALID_STATE'),
            ),
          );
          final readback = await admin.users.getUserPrivate(user.username);
          expect(readback.status, UserStatus.pending);
        },
      );

      test('an admin approves a pending registrant directly, with no '
          'document', () async {
        if (skipIf(enabled: verificationOn, feature: 'identity verification')) {
          return;
        }
        final user = await registerFresh('off_approve');
        final approved = await admin.users.approveUser(user.username);
        expect(approved.status, UserStatus.active);
        final readback = await admin.users.getUserPrivate(user.username);
        expect(readback.status, UserStatus.active);
      });

      test(
        'after a reconsider, the user resubmits without a document',
        () async {
          if (skipIf(
            enabled: verificationOn,
            feature: 'identity verification',
          )) {
            return;
          }
          final user = await registerFresh('off_reconsider');
          final sentBack = await admin.users.reconsiderUser(
            user.username,
            'check your name',
          );
          expect(sentBack.status, UserStatus.registered);

          final self = await loginAs(user.username);
          final resubmitted = await self.users.submitForReview();
          expect(resubmitted.status, UserStatus.pending);
          final readback = await admin.users.getUserPrivate(user.username);
          expect(readback.status, UserStatus.pending);
        },
      );
    });
  });
}
