import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 23: Broadcasts Test Suite.
///
/// Covers the admin-only broadcast surface (server #51):
/// - POST   /broadcasts                              createBroadcast
/// - GET    /broadcasts                              listBroadcasts
/// - GET    /broadcasts/by_id/{id}                   getBroadcast (with counts)
/// - GET    /broadcasts/by_id/{id}/recipients        listRecipients
/// - DELETE /broadcasts/by_id/{id}                   revokeBroadcast
///
/// Recipients also see broadcasts in their regular /notifications feed; the
/// last test verifies that fan-out is observable client-side.
void main() {
  group('Section 23: Broadcasts', () {
    late SecureClient adminClient;
    late SecureClient aliceClient;

    const alice = 'test_alice_s23';
    const password = 'password123';

    // Every id produced by a successful createBroadcast in this file.
    // tearDownAll iterates and revokes each so the rows don't linger as
    // status=sent garbage on the test stack. Revoke also deletes the
    // fan-out notifications, so alice's feed doesn't accumulate
    // test_S23 entries across runs. The row itself remains with
    // status=revoked for audit — the server has no hard-delete.
    final createdBroadcastIds = <int>{};

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);

      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );

      await adminClient.auth.login(sudoUsername, sudoPassword);
      final adminUser = await adminClient.auth.getCurrentUser();
      expect(adminUser.username, sudoUsername);

      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: alice,
        email: '$alice@test.com',
        password: password,
        firstName: 'Alice S23',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      aliceClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await aliceClient.auth.login(alice, password);
      final aliceUser = await aliceClient.auth.getCurrentUser();
      expect(aliceUser.username, alice);
    });

    tearDownAll(() async {
      for (final id in createdBroadcastIds) {
        try {
          await adminClient.broadcasts.revokeBroadcast(id);
        } on ServerException {
          // Already revoked by the 23.04 test, or otherwise unreachable.
          // Either way the cleanup goal — drop the fan-out — has been
          // met; swallow so a single hiccup doesn't fail tearDown.
        }
      }
    });

    /// Wrap [BroadcastSource.createBroadcast] so every successfully created
    /// row is tracked for [tearDownAll] revocation. Use this instead of
    /// `adminClient.broadcasts.createBroadcast` inside this file.
    Future<Broadcast> createTrackedBroadcast({
      required AudienceSelector audienceSelector,
      required Map<String, dynamic> payload,
    }) async {
      final created = await adminClient.broadcasts.createBroadcast(
        audienceSelector: audienceSelector,
        payload: payload,
      );
      createdBroadcastIds.add(created.id);
      return created;
    }

    Map<String, dynamic> payload(String title) => <String, dynamic>{
      'v': 1,
      'type': 'broadcast.message',
      'data': <String, dynamic>{'title': title},
    };

    // -------------------------------------------------------------------------
    // 23.01: Create + List
    // -------------------------------------------------------------------------

    group('23.01: Create & List', () {
      test(
        '23.01: createBroadcast returns the new row with fan-out count',
        () async {
          final created = await createTrackedBroadcast(
            audienceSelector: AudienceSelector.users(const [alice]),
            payload: payload('test_S23 hello alice'),
          );

          expect(created.id, isPositive);
          expect(created.status, BroadcastStatus.sent);
          expect(created.recipientCount, greaterThanOrEqualTo(1));
          expect(created.audienceSelector.kind, AudienceKind.users);
          expect(created.audienceSelector.usernames, contains(alice));
          expect(created.payload['v'], 1);
          // List-row shape: read/unread counts are not populated here.
          expect(created.readCount, isNull);
          expect(created.unreadCount, isNull);

          // Listing surfaces it.
          final list = await adminClient.broadcasts.listBroadcasts(limit: 50);
          expect(
            list.items.any((b) => b.id == created.id),
            isTrue,
            reason: 'listBroadcasts should include the just-created row',
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // 23.02: Detail view exposes read/unread counters
    // -------------------------------------------------------------------------

    group('23.02: Detail', () {
      test(
        '23.02: getBroadcast populates readCount + unreadCount',
        () async {
          final created = await createTrackedBroadcast(
            audienceSelector: AudienceSelector.users(const [alice]),
            payload: payload('test_S23 detail'),
          );

          final detail = await adminClient.broadcasts.getBroadcast(created.id);
          expect(detail.id, created.id);
          expect(detail.readCount, isNotNull);
          expect(detail.unreadCount, isNotNull);
          expect(
            detail.readCount! + detail.unreadCount!,
            detail.recipientCount,
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // 23.03: Recipients listing with read/unread filter
    // -------------------------------------------------------------------------

    group('23.03: Recipients', () {
      test(
        '23.03a: listRecipients returns one row per fanned-out user',
        () async {
          final created = await createTrackedBroadcast(
            audienceSelector: AudienceSelector.users(const [alice]),
            payload: payload('test_S23 recipients'),
          );

          final recipients = await adminClient.broadcasts.listRecipients(
            created.id,
          );

          expect(recipients.items, isNotEmpty);
          expect(
            recipients.items.any((r) => r.username == alice),
            isTrue,
          );
          // Freshly fanned-out, alice has not opened anything yet.
          final aliceRow = recipients.items.firstWhere(
            (r) => r.username == alice,
          );
          expect(aliceRow.isRead, isFalse);
        },
      );

      test(
        '23.03b: statusFilter=unread excludes read recipients',
        () async {
          final created = await createTrackedBroadcast(
            audienceSelector: AudienceSelector.users(const [alice]),
            payload: payload('test_S23 unread filter'),
          );

          final unread = await adminClient.broadcasts.listRecipients(
            created.id,
            statusFilter: 'unread',
          );
          expect(
            unread.items.every((r) => !r.isRead),
            isTrue,
            reason: 'every row from statusFilter=unread must have isRead=false',
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // 23.04: Revoke
    // -------------------------------------------------------------------------

    group('23.04: Revoke', () {
      test(
        '23.04: revokeBroadcast flips status to revoked',
        () async {
          final created = await createTrackedBroadcast(
            audienceSelector: AudienceSelector.users(const [alice]),
            payload: payload('test_S23 revoke me'),
          );

          final revoked = await adminClient.broadcasts.revokeBroadcast(
            created.id,
          );

          expect(revoked.id, created.id);
          expect(revoked.status, BroadcastStatus.revoked);

          // A subsequent fetch should still report it as revoked.
          final detail = await adminClient.broadcasts.getBroadcast(created.id);
          expect(detail.status, BroadcastStatus.revoked);
        },
      );
    });

    // -------------------------------------------------------------------------
    // 23.05: Fan-out is observable in the recipient's /notifications feed
    // -------------------------------------------------------------------------

    group('23.05: Fan-out', () {
      test(
        '23.05: recipient sees the broadcast in /notifications with broadcastId',
        () async {
          // Make sure alice starts clean for a deterministic search.
          await aliceClient.notifications.markAllRead();

          final created = await createTrackedBroadcast(
            audienceSelector: AudienceSelector.users(const [alice]),
            payload: payload('test_S23 fanout marker'),
          );

          final feed = await aliceClient.notifications.getNotifications(
            limit: 50,
          );
          final fanout = feed.items.firstWhere(
            (n) => n.broadcastId == created.id,
            orElse: () => throw TestFailure(
              'expected a notification with broadcastId=${created.id} in '
              "alice's feed, got broadcastIds: "
              '${feed.items.map((n) => n.broadcastId).join(", ")}',
            ),
          );
          expect(fanout.username, alice);
          expect(fanout.payload['v'], 1);
        },
      );
    });
  });
}
