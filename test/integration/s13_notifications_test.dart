import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 13: Notifications Test Suite.
///
/// Tests requirements from Section 13 (Notifications):
/// - 13.01: Create Notification
/// - 13.02: List Notifications
/// - 13.03: Mark Notification Read
/// - 13.04: Mark All Read
/// - 13.05: Get Unread Count
/// - 13.06: Delete Notification
/// - 13.07: Get Notification Preferences
/// - 13.08: Update Notification Preferences
/// - 13.09: Fire-and-Forget Delivery
///
/// Coverage against NotificationSource interface:
/// - getNotifications: 13.02
/// - markRead: 13.03
/// - markAllRead: 13.04
/// - getPreferences: 13.07
/// - updatePreferences: 13.08
/// - getUnreadCount: 13.05
/// - createNotification: 13.01
/// - deleteNotification: 13.06
void main() {
  group('Section 13: Notifications', () {
    late SecureClient adminClient;
    late SecureClient aliceClient;

    const alice = 'test_alice_s13';
    const password = 'password123';

    Map<String, dynamic> payload(String title, {String? body}) =>
        <String, dynamic>{
          'v': 1,
          'type': 'test.generic',
          'data': <String, dynamic>{
            'title': title,
            'body': ?body,
          },
        };

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean test artifacts
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to seed data
      await adminClient.auth.login(sudoUsername, sudoPassword);
      final adminUser = await adminClient.auth.getCurrentUser();
      expect(adminUser.username, sudoUsername);

      // 3. Register and approve alice
      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: alice,
        email: '$alice@test.com',
        password: password,
        firstName: 'Alice S13',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // 4. Create alice client
      aliceClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await aliceClient.auth.login(alice, password);
      final aliceUser = await aliceClient.auth.getCurrentUser();
      expect(aliceUser.username, alice);
    });

    // =========================================================================
    // 13.01: Create Notification
    // =========================================================================

    group('13.01: Create Notification', () {
      test(
        '13.01: Create Notification - creates notification for user',
        () async {
          final notification = await adminClient.notifications
              .createNotification(
                username: alice,
                type: 'test.generic',
                channel: 'inApp',
                payload: payload(
                  'test_Test Notification',
                  body: 'This is a test notification body',
                ),
              );

          expect(notification.id, isPositive);
          expect(notification.type, 'test.generic');
          expect(notification.username, alice);
          expect(notification.isRead, isFalse);
          expect(notification.payload['v'], 1);
          expect(notification.payload['type'], 'test.generic');
          expect(
            (notification.payload['data'] as Map?)?['title'],
            'test_Test Notification',
          );
          expect(
            (notification.payload['data'] as Map?)?['body'],
            'This is a test notification body',
          );
          // Plain (non-actionable) notification — pending-action fields null.
          expect(notification.pendingActionType, isNull);
          expect(notification.pendingActionId, isNull);
          expect(notification.broadcastId, isNull);
        },
      );
    });

    // =========================================================================
    // 13.02: List Notifications
    // =========================================================================

    group('13.02: List Notifications', () {
      test('13.02a: List Notifications - returns paginated list', () async {
        await adminClient.notifications.createNotification(
          username: alice,
          type: 'test.generic',
          channel: 'inApp',
          payload: payload('test_List Test 1', body: 'Body 1'),
        );
        await adminClient.notifications.createNotification(
          username: alice,
          type: 'test.generic',
          channel: 'inApp',
          payload: payload('test_List Test 2', body: 'Body 2'),
        );

        final notifications = await aliceClient.notifications.getNotifications(
          limit: 10,
        );
        expect(notifications.items, isA<List<AppNotification>>());
        expect(notifications.items.length, greaterThanOrEqualTo(2));
        // Every row from the server now carries a payload envelope.
        for (final n in notifications.items) {
          expect(n.payload, isNotEmpty);
        }
      });

      test('13.02b: List Notifications - filters unread only', () async {
        final unread = await aliceClient.notifications.getNotifications(
          unreadOnly: true,
        );

        for (final notif in unread.items) {
          expect(notif.isRead, isFalse);
        }
      });
    });

    // =========================================================================
    // 13.03: Mark Notification Read
    // =========================================================================

    group('13.03: Mark Notification Read', () {
      test('13.03: Mark Notification Read - marks as read', () async {
        final notification = await adminClient.notifications.createNotification(
          username: alice,
          type: 'test.generic',
          channel: 'inApp',
          payload: payload('test_Mark Read Test', body: 'Will be marked read'),
        );

        await aliceClient.notifications.markRead(notification.id);

        final unread = await aliceClient.notifications.getNotifications(
          unreadOnly: true,
        );
        expect(
          unread.items.any((n) => n.id == notification.id),
          isFalse,
        );
      });
    });

    // =========================================================================
    // 13.04: Mark All Read
    // =========================================================================

    group('13.04: Mark All Read', () {
      test('13.04: Mark All Read - marks all as read', () async {
        await adminClient.notifications.createNotification(
          username: alice,
          type: 'test.generic',
          channel: 'inApp',
          payload: payload('test_Mark All 1'),
        );
        await adminClient.notifications.createNotification(
          username: alice,
          type: 'test.generic',
          channel: 'inApp',
          payload: payload('test_Mark All 2'),
        );

        await aliceClient.notifications.markAllRead();

        final unread = await aliceClient.notifications.getNotifications(
          unreadOnly: true,
        );
        expect(unread.items, isEmpty);
      });
    });

    // =========================================================================
    // 13.05: Get Unread Count
    // =========================================================================

    group('13.05: Get Unread Count', () {
      test('13.05: Get Unread Count - returns count of unread', () async {
        await aliceClient.notifications.markAllRead();

        await adminClient.notifications.createNotification(
          username: alice,
          type: 'test.generic',
          channel: 'inApp',
          payload: payload('test_Unread Count Test'),
        );

        final count = await aliceClient.notifications.getUnreadCount();
        expect(count, greaterThanOrEqualTo(1));
      });
    });

    // =========================================================================
    // 13.06: Delete Notification
    // =========================================================================

    group('13.06: Delete Notification', () {
      test(
        '13.06: Delete Notification - deletes notification',
        () async {
          final notification = await adminClient.notifications
              .createNotification(
                username: alice,
                type: 'test.generic',
                channel: 'inApp',
                payload: payload(
                  'test_Delete Test',
                  body: 'This notification will be deleted',
                ),
              );

          // Server requires admin role for delete
          await adminClient.notifications.deleteNotification(notification.id);

          final notifications = await aliceClient.notifications
              .getNotifications();
          expect(
            notifications.items.any((n) => n.id == notification.id),
            isFalse,
          );
        },
      );
    });

    // =========================================================================
    // 13.07: Get Notification Preferences
    // =========================================================================

    group('13.07: Get Notification Preferences', () {
      test(
        '13.07: a freshly approved user has server-default preferences '
        '(email on, push on, sms off)',
        () async {
          final prefs = await aliceClient.notifications.getPreferences();
          expect(
            prefs.emailEnabled,
            isTrue,
            reason: 'email channel defaults to on per server contract',
          );
          expect(
            prefs.pushEnabled,
            isTrue,
            reason: 'push channel defaults to on per server contract',
          );
          expect(
            prefs.smsEnabled,
            isFalse,
            reason: 'sms channel defaults to off per server contract',
          );
        },
      );
    });

    // =========================================================================
    // 13.08: Update Notification Preferences
    // =========================================================================
    //
    // The server uses PATCH semantics: only the channels included in the body
    // are touched. The tests below verify that and the three-channel shape.

    group('13.08: Update Notification Preferences', () {
      tearDown(() async {
        // Restore defaults so each test starts from a known baseline.
        await aliceClient.notifications.updatePreferences(
          emailEnabled: true,
          pushEnabled: true,
          smsEnabled: false,
        );
      });

      test(
        '13.08a: toggling email leaves push and sms untouched',
        () async {
          final updated = await aliceClient.notifications.updatePreferences(
            emailEnabled: false,
          );
          expect(updated.emailEnabled, isFalse);
          expect(updated.pushEnabled, isTrue);
          expect(updated.smsEnabled, isFalse);

          // Re-read to confirm the server actually persisted it.
          final fetched = await aliceClient.notifications.getPreferences();
          expect(fetched.emailEnabled, isFalse);
          expect(fetched.pushEnabled, isTrue);
          expect(fetched.smsEnabled, isFalse);
        },
      );

      test(
        '13.08b: toggling push leaves email and sms untouched',
        () async {
          final updated = await aliceClient.notifications.updatePreferences(
            pushEnabled: false,
          );
          expect(updated.emailEnabled, isTrue);
          expect(updated.pushEnabled, isFalse);
          expect(updated.smsEnabled, isFalse);
        },
      );

      test(
        '13.08c: toggling sms leaves email and push untouched',
        () async {
          final updated = await aliceClient.notifications.updatePreferences(
            smsEnabled: true,
          );
          expect(updated.emailEnabled, isTrue);
          expect(updated.pushEnabled, isTrue);
          expect(updated.smsEnabled, isTrue);
        },
      );

      test(
        '13.08d: setting all three channels in one request round-trips',
        () async {
          final updated = await aliceClient.notifications.updatePreferences(
            emailEnabled: false,
            pushEnabled: false,
            smsEnabled: true,
          );
          expect(updated.emailEnabled, isFalse);
          expect(updated.pushEnabled, isFalse);
          expect(updated.smsEnabled, isTrue);

          // Empty PATCH must leave everything alone.
          final noop = await aliceClient.notifications.updatePreferences();
          expect(noop.emailEnabled, isFalse);
          expect(noop.pushEnabled, isFalse);
          expect(noop.smsEnabled, isTrue);
        },
      );
    });

    // =========================================================================
    // 13.10: List Pending Actions
    // =========================================================================
    //
    // Drives the trigger via the enrollment-invitation flow: when an admin
    // invites a member, the server auto-emits a notification with
    // `pending_action_type = enrollment_opportunity` linked to the new
    // enrollment row. `listPendingActions` returns it; once the member
    // responds (status leaves `invited`), the server auto-dismisses it.

    group('13.10: List Pending Actions', () {
      late int venueId;
      late int eventId;

      setUpAll(() async {
        // Admin creates a one-off event well in the future so the invite is
        // accepted by the conflict / past-event guards.
        await adminClient.auth.login(sudoUsername, sudoPassword);

        final venue = await adminClient.venues.createVenue(
          name: 'test_S13 Pending Venue',
          description: 'Test',
        );
        venueId = venue.id;

        final start = DateTime.now().toUtc().add(const Duration(days: 30));
        final event = await adminClient.events.createEvent(
          title: 'test_S13 Pending Event',
          description: 'For pending-actions test',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        eventId = event.id;
      });

      test(
        '13.10a: invitation surfaces as a pending action with linked '
        'enrollment id',
        () async {
          // Make sure alice's pending feed is empty for this event before we
          // create the trigger.
          final before = await aliceClient.notifications.listPendingActions();
          expect(
            before.items
                .where(
                  (n) =>
                      n.pendingActionType ==
                      PendingActionType.enrollmentOpportunity,
                )
                .any(
                  (n) =>
                      n.pendingActionId != null &&
                      n.type.startsWith('enrollment.'),
                ),
            isFalse,
            reason: 'alice should have no enrollment pending actions yet',
          );

          await adminClient.enrollments.invite(eventId, alice);

          // alice's enrollment now exists in `invited` state.
          final enrollment = await aliceClient.myEvents.getMyEnrollment(
            alice,
            eventId,
          );
          expect(enrollment.status, EnrollmentStatus.invited);

          final pending = await aliceClient.notifications.listPendingActions();
          final match = pending.items.firstWhere(
            (n) =>
                n.pendingActionType ==
                    PendingActionType.enrollmentOpportunity &&
                n.pendingActionId == enrollment.id,
            orElse: () => throw TestFailure(
              'expected a pending-action notification linked to enrollment '
              '${enrollment.id}, got: '
              '${pending.items.map((n) => "${n.type}/${n.pendingActionType}/"
                  "${n.pendingActionId}").join(", ")}',
            ),
          );

          expect(match.username, alice);
          expect(match.payload, isNotEmpty);
        },
      );

      test(
        '13.10b: notification auto-dismisses once the member accepts the '
        'invite',
        () async {
          // Pre-condition from 13.10a: invitation present.
          final enrollment = await aliceClient.myEvents.getMyEnrollment(
            alice,
            eventId,
          );
          expect(enrollment.status, EnrollmentStatus.invited);

          await aliceClient.myEvents.acceptInvite(alice, eventId);

          final accepted = await aliceClient.myEvents.getMyEnrollment(
            alice,
            eventId,
          );
          expect(accepted.status, EnrollmentStatus.accepted);

          final pending = await aliceClient.notifications.listPendingActions();
          final stillPresent = pending.items.any(
            (n) =>
                n.pendingActionType ==
                    PendingActionType.enrollmentOpportunity &&
                n.pendingActionId == enrollment.id,
          );
          expect(
            stillPresent,
            isFalse,
            reason:
                'enrollment-opportunity notification should auto-dismiss '
                'once the invite is accepted',
          );
        },
      );
    });

    // =========================================================================
    // 13.09: Fire-and-Forget Delivery
    // =========================================================================

    group('13.09: Fire-and-Forget Delivery', () {
      test(
        '13.09: Fire-and-Forget Delivery - non-blocking notification',
        skip:
            'club_server#56 — Notification delivery-channel dispatch is a '
            'placeholder',
        () async {},
      );
    });
  });
}
