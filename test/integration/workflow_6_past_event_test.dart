// OccurrenceResponse does not include enrollmentStatus or attendanceStatus.
// Enrollment status is verified via enrollments.getEnrollmentStatus().
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 6: Past Event Interaction Edge Cases
///
/// Test 1 — Future event invite:
///   Organizer creates a future event, invites a user.
///   Expected: Enrollment status is 'invited'.
///
/// Test 2 — Enrollment operations on ended event:
///   Organizer creates a past (ended) event, then attempts invite and assign.
///   Expected: Server rejects both with ServerException.
void main() {
  group('Workflow 6: Past Event Interaction Case', () {
    late SecureClient client;
    late int venueId;
    const username = 'test_user_past';

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

      // Register and approve test user
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_user_past',
        email: 'test_user_past@test.com',
        password: 'password123',
        firstName: 'Past User',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      // `member` is not a role (#27): a user with no roles is a member.

      // Create venue
      final venue = await client.venues.createVenue(name: 'test_Venue WF6');
      venueId = venue.id;

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

    test('Invite to future event succeeds', () async {
      final now = DateTime.now().toUtc();
      final eventStart = now.add(const Duration(days: 30));

      final event = await client.events.createEvent(
        title: 'test_Future Event WF6',
        description: 'Upcoming event',
        type: EventType.oneOff,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: eventStart,
        endTimeUtc: eventStart.add(const Duration(hours: 1)),
      );

      await client.enrollments.invite(event.id, username);

      final status = await client.enrollments.getEnrollmentStatus(
        event.id,
        username,
      );
      expect(status, EnrollmentStatus.invited);
    });

    test('Invite to past ended event is rejected with INVALID_STATE', () async {
      final pastStart = DateTime.utc(2025, 1, 5, 10);

      final event = await client.events.createEvent(
        title: 'test_Past Event WF6 Invite',
        description: 'Already ended',
        type: EventType.oneOff,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: pastStart,
        endTimeUtc: pastStart.add(const Duration(hours: 1)),
      );

      await expectLater(
        () => client.enrollments.invite(event.id, username),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidState,
          ),
        ),
      );
    });

    test('Assign to past ended event is rejected with INVALID_STATE', () async {
      final pastStart = DateTime.utc(2025, 2, 5, 10);

      final event = await client.events.createEvent(
        title: 'test_Past Event WF6 Assign',
        description: 'Already ended',
        type: EventType.oneOff,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: pastStart,
        endTimeUtc: pastStart.add(const Duration(hours: 1)),
      );

      await expectLater(
        () => client.enrollments.assign(event.id, username),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidState,
          ),
        ),
      );
    });

    test(
      'AssignTrial to past ended event is rejected with INVALID_STATE',
      () async {
        final pastStart = DateTime.utc(2025, 3, 5, 10);

        final event = await client.events.createEvent(
          title: 'test_Past Event WF6 Trial',
          description: 'Already ended',
          type: EventType.oneOff,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: pastStart,
          endTimeUtc: pastStart.add(const Duration(hours: 1)),
        );

        // Assign-trial is programme-only (enrollment R31a; the code the
        // server sends is INVALID_EVENT_TYPE, see event_type_matrix.md), and
        // the type gate answers before the ended-event state gate.
        await expectLater(
          () => client.enrollments.assignTrial(event.id, username),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidEventType,
            ),
          ),
        );
      },
    );
  });
}
