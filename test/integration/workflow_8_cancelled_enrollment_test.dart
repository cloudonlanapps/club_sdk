import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 8: Enrollment for Cancelled Events
///
/// Steps:
/// 1. T0: Organizer creates a programme event.
/// 2. T0: Organizer invites User A.
/// 3. T1: Organizer cancels the event series.
/// 4. T2: User A attempts to accept the invite for the cancelled event.
/// 5. T2 Verification: User A should receive an error.
void main() {
  group('Workflow 8: Enrollment for Cancelled Events', () {
    late SecureClient client;
    late int venueId;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      await client.auth.login(sudoUsername, sudoPassword);

      // Register and approve admin user
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_admin_1',
        email: 'test_admin_1@test.com',
        password: 'password123',
        firstName: 'Admin One',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_admin_1', 'admin');

      // Register and approve member users
      for (final entry in {
        'test_user_a': 'User A',
        'test_user_b': 'User B',
      }.entries) {
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: entry.key,
          email: '${entry.key}@test.com',
          password: 'password123',
          firstName: entry.value,
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        // `member` is not a role (#27): a user with no roles is a member.
      }

      // Create venue
      final venue = await client.venues.createVenue(name: 'test_Venue WF8');
      venueId = venue.id;

      // Credit gates programme enrollment where the module is on
      // (#38); a no-op where it is off.
      await seedEnrolmentCreditIfGated(client, ['test_user_a', 'test_user_b']);

      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login('test_admin_1', 'password123');
      final user = await client.auth.getCurrentUser();
      expect(user.username, 'test_admin_1');
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // Not logged in — ignore
      }
    });

    test(
      'Accepting invite for cancelled event should fail',
      () async {
        final eventStart = dayAt(35);
        const userA = 'test_user_a';

        // 1. Create programme event
        final event = await client.events.createEvent(
          title: 'test_Cancelled Event Test',
          description: 'Testing enrollment after cancellation',
          type: EventType.programme,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: eventStart,
          endTimeUtc: eventStart.add(const Duration(hours: 1)),
          rrule: weeklyOn(eventStart),
        );

        // 2. Invite User A
        await client.enrollments.invite(
          event.id,
          userA,
        );

        // 3. Terminate the programme (cancel is camp-only, #16) at its first
        //    occurrence, the earliest cutoff the server accepts, so no live
        //    occurrence is left (programme R1).
        await client.events.terminate(
          event.id,
          reason: 'Change of plans',
          cutoffTimeUtc: eventStart,
        );

        // 3a. Authenticated event read should reflect the cancelled status.
        final cancelledEvent = await client.events.getEvent(event.id);
        expect(cancelledEvent.status, EventStatus.cancelled);
        expect(cancelledEvent.untilTimeUtc, eventStart);

        // 4. User A attempts to accept invite — should fail
        expect(
          () => client.myEvents.acceptInvite(userA, event.id),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test(
      'Assigning member to cancelled event should fail',
      () async {
        final eventStart = dayAt(38, hour: 14);
        const userB = 'test_user_b';

        // Create programme event at a different time
        final event = await client.events.createEvent(
          title: 'test_Cancelled Event Assign Test',
          description: 'D',
          type: EventType.programme,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: eventStart,
          endTimeUtc: eventStart.add(const Duration(hours: 1)),
          rrule: weeklyOn(eventStart),
        );

        // Terminate the programme at its first occurrence (cancel is
        // camp-only, #16)
        await client.events.terminate(
          event.id,
          reason: 'No longer needed',
          cutoffTimeUtc: eventStart,
        );

        // Attempt to assign User B — should fail
        expect(
          () => client.enrollments.assign(
            event.id,
            userB,
          ),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });
}
