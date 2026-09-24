import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/test_client.dart';

/// Issue #376 — `reconsiderUser`, `reapply`, and `resolutionReason` on
/// `approveUser` / `blockUser`.
///
/// Maps 1:1 to server #122: the `user_review_requests` audit table plus the
/// reconsider/reapply workflow. Assertions that depend on
/// `UserPrivate.adminReviewNote` are deferred to issue #377, which adds the
/// SDK field; this file verifies the surface that is observable today
/// (status transitions, notification inbox, and exception types).
void main() {
  group('Issue 376: reconsider / reapply / resolutionReason', () {
    late SecureClient adminClient;
    const password = 'password123';

    var userCounter = 0;
    String nextUsername(String tag) {
      userCounter += 1;
      return 'test_376_${tag}_$userCounter';
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

    /// Counts admin `user_approval` notifications for [username] created
    /// strictly after [sinceId]. Server #122 cleans up the row on reconsider,
    /// so the count drops; the round-trip test asserts exactly 1 after
    /// the reconsider → reapply → submit cycle.
    Future<int> countUserApprovals(String username, int sinceId) async {
      final inbox = await adminClient.notifications.getNotifications(
        limit: 100,
      );
      return inbox.items
          .where(
            (n) =>
                n.id > sinceId &&
                n.pendingActionType == PendingActionType.userApproval &&
                n.pendingActionKey == username,
          )
          .length;
    }

    Future<int> currentMaxNotificationId() async {
      final inbox = await adminClient.notifications.getNotifications(
        limit: 100,
      );
      if (inbox.items.isEmpty) return 0;
      return inbox.items.map((n) => n.id).reduce((a, b) => a > b ? a : b);
    }

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await adminClient.auth.login(sudoUsername, sudoPassword);
    });

    tearDownAll(() async {
      try {
        await adminClient.auth.logout();
      } on Exception {
        /* ignore */
      }
    });

    // ── reconsiderUser ────────────────────────────────────────────────────

    test(
      'Issue 376: reconsiderUser flips pending -> registered and clears '
      'the prior user_approval notification',
      () async {
        final username = await registerFresh('reconsider');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);

        final beforeMaxId = await currentMaxNotificationId();
        await userClient.users.submitForReview();
        // After submit there should be exactly 1 user_approval for this user.
        expect(await countUserApprovals(username, beforeMaxId), 1);

        final result = await adminClient.users.reconsiderUser(
          username,
          'fix DOB',
        );
        expect(result.username, username);
        expect(result.status, UserStatus.registered);

        // Admin readback confirms status independent of the response.
        final readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.registered);

        // The previously emitted user_approval row must be gone (server #122).
        expect(await countUserApprovals(username, beforeMaxId), 0);
      },
    );

    test(
      'Issue 376: reconsiderUser supersedes a prior active row (repeat call '
      'succeeds; status stays registered)',
      () async {
        final username = await registerFresh('supersede');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();

        await adminClient.users.reconsiderUser(username, 'first');
        // Repeat reconsider requires the target to be pending; resubmit first.
        // Per server #122, only one active row exists at a time — the second
        // reconsider closes the first as 'superseded'. Test by re-submitting
        // and reconsidering again, observing status stays registered.
        await userClient.users.submitForReview();
        final second = await adminClient.users.reconsiderUser(
          username,
          'second',
        );
        expect(second.status, UserStatus.registered);
      },
    );

    test(
      'Issue 376: reconsiderUser returns 409 when target is not pending '
      '(registered)',
      () async {
        final username = await registerFresh('notpending');
        await expectLater(
          adminClient.users.reconsiderUser(username, 'nope'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              409,
            ),
          ),
        );
      },
    );

    test(
      'Issue 376: reconsiderUser returns 400 CANNOT_RECONSIDER_SELF when '
      'admin targets themselves',
      () async {
        await expectLater(
          adminClient.users.reconsiderUser(sudoUsername, 'self'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              400,
            ),
          ),
        );
      },
    );

    test(
      'Issue 376: reconsiderUser returns 404 when target does not exist',
      () async {
        await expectLater(
          adminClient.users.reconsiderUser(
            'test_376_doesnotexist_$userCounter',
            'gone',
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      },
    );

    // ── reapply ───────────────────────────────────────────────────────────

    test(
      'Issue 376: reapply succeeds for self when status is registered and an '
      'active review row exists; updated fields persist; '
      'status stays registered',
      () async {
        final username = await registerFresh('reapplyself');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();
        await adminClient.users.reconsiderUser(username, 'fix DOB');

        final newDob = DateTime.utc(1990, 1, 2);
        final updated = await userClient.users.reapply(
          username,
          firstName: 'NewFirst',
          lastName: 'NewLast',
          dateOfBirthUtc: newDob,
          gender: Gender.female,
          phone: '9999999999',
        );

        expect(updated.username, username);
        expect(updated.status, UserStatus.registered);
        expect(updated.firstName, 'NewFirst');
        expect(updated.lastName, 'NewLast');
        expect(updated.dateOfBirthUtc, newDob);
        expect(updated.gender, Gender.female);
        expect(updated.phone, '9999999999');

        // Independent admin readback (response and DB agree).
        final readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.registered);
        expect(readback.firstName, 'NewFirst');
        expect(readback.dateOfBirthUtc, newDob);
        expect(readback.gender, Gender.female);
      },
    );

    test(
      'Issue 376: reapply returns 403 when caller targets another user',
      () async {
        final ownerUsername = await registerFresh('reapplyowner');
        final otherUsername = await registerFresh('reapplyother');
        final ownerClient = await loginAs(ownerUsername);
        await attachIdentityDocument(ownerClient, ownerUsername);
        await ownerClient.users.submitForReview();
        await adminClient.users.reconsiderUser(ownerUsername, 'fix');

        await expectLater(
          ownerClient.users.reapply(otherUsername, firstName: 'X'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );

    test(
      'Issue 376: reapply returns 409 NO_ACTIVE_REVIEW_REQUEST when the '
      'caller is registered but no active review row exists',
      () async {
        final username = await registerFresh('reapplynoreview');
        final userClient = await loginAs(username);

        await expectLater(
          userClient.users.reapply(username, firstName: 'X'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              409,
            ),
          ),
        );
      },
    );

    test(
      'Issue 376: reapply returns 409 when caller status is not registered '
      '(pending)',
      () async {
        final username = await registerFresh('reapplypending');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();

        await expectLater(
          userClient.users.reapply(username, firstName: 'X'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              409,
            ),
          ),
        );
      },
    );

    // ── approveUser / blockUser resolutionReason ─────────────────────────

    test(
      'Issue 376: approveUser accepts resolutionReason and approves the '
      'pending target',
      () async {
        final username = await registerFresh('approvereason');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();

        final approved = await adminClient.users.approveUser(
          username,
          resolutionReason: 'docs OK',
        );
        expect(approved.status, UserStatus.active);
      },
    );

    test(
      'Issue 376: blockUser accepts resolutionReason and blocks the target',
      () async {
        final username = await registerFresh('blockreason');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();

        final blocked = await adminClient.users.blockUser(
          username,
          resolutionReason: 'spam',
        );
        expect(blocked.status, UserStatus.blocked);
      },
    );

    test(
      'Issue 376: approveUser without resolutionReason still behaves like the '
      'pre-#376 contract (regression)',
      () async {
        final username = await registerFresh('approvenoreason');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();

        final approved = await adminClient.users.approveUser(username);
        expect(approved.status, UserStatus.active);
      },
    );

    test(
      'Issue 376: blockUser without resolutionReason still behaves like the '
      'pre-#376 contract (regression)',
      () async {
        final username = await registerFresh('blocknoreason');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);
        await userClient.users.submitForReview();

        final blocked = await adminClient.users.blockUser(username);
        expect(blocked.status, UserStatus.blocked);
      },
    );

    // ── End-to-end round trip ────────────────────────────────────────────

    test(
      'Issue 376: register -> submit -> reconsider -> reapply -> submit yields '
      'exactly 1 user_approval at the end (not 2)',
      () async {
        final beforeMaxId = await currentMaxNotificationId();
        final username = await registerFresh('roundtrip');
        final userClient = await loginAs(username);
        await attachIdentityDocument(userClient, username);

        // 1. submit-for-review: emits 1 user_approval.
        await userClient.users.submitForReview();
        var readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.pending);
        expect(await countUserApprovals(username, beforeMaxId), 1);

        // 2. admin reconsider: target flips back to registered AND the prior
        //    user_approval row is purged (server #122 §2).
        await adminClient.users.reconsiderUser(username, 'fix DOB');
        readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.registered);
        expect(await countUserApprovals(username, beforeMaxId), 0);

        // 3. self reapply: status stays registered.
        await userClient.users.reapply(
          username,
          dateOfBirthUtc: DateTime.utc(1990, 1, 2),
        );
        readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.registered);

        // 4. submit again: exactly 1 user_approval again — NOT 2. This is the
        //    user-visible artefact of the cleanup; use a count, not contains.
        await userClient.users.submitForReview();
        readback = await adminClient.users.getUserPrivate(username);
        expect(readback.status, UserStatus.pending);
        expect(await countUserApprovals(username, beforeMaxId), 1);
      },
    );
  });
}
