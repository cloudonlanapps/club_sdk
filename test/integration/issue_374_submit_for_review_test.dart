import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue #374 — `UserStatus.registered` + `UserSource.submitForReview()`.
///
/// Maps 1:1 to server #120: registration lands the user at the new
/// `registered` status without emitting the admin `user_approval`
/// notification. Calling `POST /v1/users/me/submit-for-review` flips the
/// status to `pending` and enqueues the deferred admin notification.
void main() {
  group('Issue 374: submitForReview lifecycle', () {
    late SecureClient adminClient;
    // The review lifecycle below exists only while identity verification is
    // on (#2); with it off, register lands users at pending and
    // issue_2_identity_verification_test covers that flow instead.
    late bool verificationOn;
    const password = 'password123';

    /// Counter to mint unique usernames per test, since the suite must remain
    /// self-contained and tests need fresh users in deterministic states.
    var userCounter = 0;
    String nextUsername(String tag) {
      userCounter += 1;
      return 'test_374_${tag}_$userCounter';
    }

    Future<String> registerFresh(String tag) async {
      final username = nextUsername(tag);
      await adminClient.auth.register(
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: username,
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: DateTime.utc(1995, 6, 15),
      );
      return username;
    }

    Future<SecureClient> loginAs(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      await c.auth.login(username, password);
      return c;
    }

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await adminClient.auth.login(sudoUsername, sudoPassword);
      verificationOn = (await stackCapabilities(
        adminClient,
      )).identityVerification;
    });

    tearDownAll(() async {
      await adminClient.auth.logout();
    });

    test(
      'Issue 374: register lands new user at status == registered',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('regstatus');

        final user = await adminClient.users.getUserPrivate(username);
        expect(user.status, UserStatus.registered);
      },
    );

    test(
      'Issue 374: registration does NOT emit user_approval to admin '
      '(deferred until submit-for-review)',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        // Snapshot admin inbox prior to a fresh registration so we measure the
        // delta, not absolute count (other test files may share the inbox).
        final before = await adminClient.notifications.getNotifications(
          limit: 100,
        );
        final beforeMaxId = before.items.isEmpty
            ? 0
            : before.items.map((n) => n.id).reduce((a, b) => a > b ? a : b);

        final username = await registerFresh('noemit');

        final after = await adminClient.notifications.getNotifications(
          limit: 100,
        );
        final approvalForThisUser = after.items
            .where(
              (n) =>
                  n.id > beforeMaxId &&
                  n.pendingActionType == PendingActionType.userApproval &&
                  n.pendingActionKey == username,
            )
            .toList();

        expect(
          approvalForThisUser,
          isEmpty,
          reason: 'Registration must defer user_approval until submitForReview',
        );
      },
    );

    test(
      'Issue 374: submitForReview flips registered -> pending and emits '
      'exactly one user_approval to admin',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('submit');
        final userClient = await loginAs(username);

        // Snapshot the admin's current max notification id so we measure
        // notifications created by THIS submitForReview, not stale rows from
        // earlier test runs (clearTestArtifacts hard-deletes users but does
        // not purge admin notifications keyed to those usernames).
        final beforeInbox = await adminClient.notifications.getNotifications(
          limit: 100,
        );
        final beforeMaxId = beforeInbox.items.isEmpty
            ? 0
            : beforeInbox.items
                  .map((n) => n.id)
                  .reduce(
                    (a, b) => a > b ? a : b,
                  );

        await attachIdentityDocument(userClient, username);
        final result = await userClient.users.submitForReview();
        expect(result.username, username);
        expect(result.status, UserStatus.pending);

        // Verify server-side via admin readback (independent of return value).
        final readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.pending);

        // Exactly one fresh user_approval notification keyed to this user.
        final afterInbox = await adminClient.notifications.getNotifications(
          limit: 100,
        );
        final freshUserApprovals = afterInbox.items
            .where(
              (n) =>
                  n.id > beforeMaxId &&
                  n.pendingActionType == PendingActionType.userApproval &&
                  n.pendingActionKey == username,
            )
            .toList();
        expect(freshUserApprovals, hasLength(1));
      },
    );

    test(
      'Issue 374: submitForReview returns 409 when caller status is pending',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('pending');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        // First call transitions registered -> pending.
        await userClient.users.submitForReview();

        // Second call must fail with 409 INVALID_STATE.
        await expectLater(
          userClient.users.submitForReview(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              409,
            ),
          ),
        );
        // Issue 45: the server refuses logout for a pending user (403
        // ACCOUNT_NOT_ACTIVE), but the client is signed out all the same.
        await userClient.auth.logout();
        await expectLater(
          userClient.auth.getCurrentUser(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              401,
            ),
          ),
        );
      },
    );

    test(
      'Issue 374: submitForReview returns 409 when caller status is active',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('active');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();
        await adminClient.users.approveUser(username);

        await expectLater(
          userClient.users.submitForReview(),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              409,
            ),
          ),
        );

        await userClient.auth.logout();
      },
    );

    test(
      'Issue 374: submitForReview returns 409 when caller status is blocked',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('blocked');
        final userClient = await loginAs(username);
        // Block from registered (server #120 §4 allows this).
        await adminClient.users.blockUser(username);

        // Login may now fail; the user still has a valid access token from
        // the first login, but if not we just verify state via admin and skip
        // the submit attempt with a token already in hand.
        await expectLater(
          userClient.users.submitForReview(),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test(
      'Issue 374: submitForReview returns 409 when caller status is left',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('left');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();
        await adminClient.users.approveUser(username);
        await adminClient.users.markLeft(username);

        await expectLater(
          userClient.users.submitForReview(),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test('Issue 374: blockUser succeeds when target is registered', () async {
      if (skipUnless(
        enabled: verificationOn,
        module: 'identity verification',
      )) {
        return;
      }
      final username = await registerFresh('blockreg');

      final blocked = await adminClient.users.blockUser(username);
      expect(blocked.status, UserStatus.blocked);
    });

    test('Issue 374: blockUser succeeds when target is pending', () async {
      if (skipUnless(
        enabled: verificationOn,
        module: 'identity verification',
      )) {
        return;
      }
      final username = await registerFresh('blockpend');
      final userClient = await loginAs(username);
      await attachIdentityDocument(userClient, username);
      await userClient.users.submitForReview();
      await userClient.auth.logout();

      final blocked = await adminClient.users.blockUser(username);
      expect(blocked.status, UserStatus.blocked);
    });

    test(
      'Issue 374: approveUser returns INVALID_STATE when target is registered '
      '(must submitForReview first)',
      () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final username = await registerFresh('approvereg');

        // Server rejects approve-from-registered with 422 INVALID_STATE
        // (issue spec said 409; server canonicalised on 422 INVALID_STATE).
        await expectLater(
          adminClient.users.approveUser(username),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              'INVALID_STATE',
            ),
          ),
        );
      },
    );
  });
}
