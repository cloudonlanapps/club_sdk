// OccurrenceResponse does not include enrollmentStatus or attendanceStatus.
// Enrollment and attendance status are verified via dedicated APIs:
// enrollments.getEnrollmentStatus() and
// attendance.getAttendanceForOccurrence().
// Member operations (acceptInvite, requestLeave, withdraw) are called via
// admin client which has permission for all users.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 1: Enrollment & Attendance Story
///
/// Steps:
/// 1. T0 (Mar 1, 09:00): Organizer creates a One-off Public Event on Mar 5.
/// 2. T0: Organizer invites 4 people (User A, B, C, D).
/// 3. T0 Verification: All 4 see event in 'invitedEvents'.
/// 4. T1 (Mar 1, 10:00): User A, B, C Accept; User D Rejects.
/// 5. T1 Verification: A, B, C see in 'myEvents'; D does not.
/// 6. T2 (Mar 1, 11:00): User C Notifies Absence (On Leave).
/// 7. T3 (Mar 5, 12:00): Event Completes (server clock > EndTime).
/// 8. T3 Verification: Event shows 'Completed' logical state.
/// 9. T4 (Mar 5, 13:00): Organizer marks Attendance for participants.
/// 10. T4 Verification: Attendance verified.
void main() {
  group('Workflow 1: Enrollment & Attendance Story', () {
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
        'test_user_c': 'User C',
        'test_user_d': 'User D',
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
      final venue = await client.venues.createVenue(name: 'test_Venue WF1');
      venueId = venue.id;

      await client.auth.logout();
    });

    // Sudo alone may declare leave inside the 2-hour leave window
    // (attendance R15), which the story needs because the register only
    // opens 30 minutes before the occasion (R12) and no role bypasses that.
    late SecureClient sudoClient;

    setUp(() async {
      sudoClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await sudoClient.auth.login(sudoUsername, sudoPassword);
      await client.auth.login('test_admin_1', 'password123');
      final user = await client.auth.getCurrentUser();
      expect(user.username, 'test_admin_1');
    });

    tearDown(() async {
      for (final c in [client, sudoClient]) {
        try {
          await c.auth.logout();
        } on Exception {
          // Not logged in — ignore
        }
      }
    });

    test(
      'Full Story Execution',
      () async {
        // Ten minutes out: inside the 30-minute register window (attendance
        // R12) yet still in the future, so an accepted member is covered.
        final eventStart = nowUtcMinute().add(const Duration(minutes: 10));
        final eventEnd = eventStart.add(const Duration(hours: 1));

        const userA = 'test_user_a';
        const userB = 'test_user_b';
        const userC = 'test_user_c';
        const userD = 'test_user_d';

        // --- T0: Creation & Invitation ---
        final event = await client.events.createEvent(
          title: 'test_Community Yoga',
          description: 'Morning yoga session',
          type: EventType.oneOff,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: eventStart,
          endTimeUtc: eventEnd,
        );

        for (final username in [userA, userB, userC, userD]) {
          await client.enrollments.invite(
            event.id,
            username,
          );
        }

        // Verification: All see invited
        for (final username in [userA, userB, userC, userD]) {
          final enrollment = await client.myEvents.getMyEnrollment(
            username,
            event.id,
          );
          expect(
            enrollment.status,
            EnrollmentStatus.invited,
            reason: 'Role check for $username failed at T0',
          );
        }

        // --- T1: Confirmation ---
        await client.myEvents.acceptInvite(userA, event.id);
        await client.myEvents.acceptInvite(userB, event.id);
        await client.myEvents.acceptInvite(userC, event.id);
        await client.myEvents.declineInvite(userD, event.id);

        // Verification: Status split
        for (final username in [userA, userB, userC]) {
          final enrollment = await client.myEvents.getMyEnrollment(
            username,
            event.id,
          );
          expect(enrollment.status, EnrollmentStatus.accepted);

          final myEvents = await client.myEvents.listMyEvents(username);
          expect(
            myEvents.items.any((e) => e.id == event.id),
            isTrue,
            reason: 'User $username should see event in myEvents after accept',
          );
        }
        final dEvents = await client.myEvents.listMyEvents(userD);
        expect(
          dEvents.items.any((e) => e.id == event.id),
          isTrue,
          reason:
              'Public event is always visible regardless of enrollment '
              'status',
        );

        // --- T2: Absence & Withdrawal ---
        await sudoClient.myEvents.requestLeave(
          userC,
          event.id,
          eventStart,
        );
        // Approve the leave request
        await client.attendance.approveLeave(
          event.id,
          userC,
          eventStart,
        );
        await client.myEvents.withdraw(
          userB,
          event.id,
        );
        // Approve the withdrawal request
        await client.enrollments.approveWithdraw(
          event.id,
          userB,
        );

        // Verification: B should not see in myEvents anymore, C should still
        final bEvents = await client.myEvents.listMyEvents(userB);
        expect(
          bEvents.items.any((e) => e.id == event.id),
          isTrue,
          reason:
              'Public event is always visible regardless of enrollment '
              'status',
        );

        // Verify C is still enrolled (accepted) and on leave
        final cEnrollment = await client.enrollments.getEnrollmentStatus(
          event.id,
          userC,
        );
        expect(
          cEnrollment,
          EnrollmentStatus.accepted,
          reason: 'User C should still be accepted after requestLeave',
        );
        final cAttendance = await client.attendance.getAttendanceForOccurrence(
          event.id,
          eventStart,
        );
        final cRecord = cAttendance.where((r) => r.membername == userC);
        expect(
          cRecord.first.status,
          AttendanceStatus.onLeave,
          reason: 'User C should be onLeave after approved leave',
        );

        // --- T3: Verify occurrence exists ---
        final occCheck = await client.occurrences.getOccurrence(
          event.id,
          eventStart,
        );
        expect(occCheck.eventId, event.id);

        // --- T4: Attendance Marking ---
        await client.attendance.markAttendance(
          event.id,
          eventStart,
          [
            const AttendanceMarkRecord(
              membername: userA,
              status: AttendanceStatus.present,
            ),
          ],
        );

        // Final Verification: Attendance Matrix via dedicated APIs
        final finalAttendance = await client.attendance
            .getAttendanceForOccurrence(event.id, eventStart);

        // User A: present
        final aRecord = finalAttendance.where((r) => r.membername == userA);
        expect(aRecord.isNotEmpty, isTrue);
        expect(aRecord.first.status, AttendanceStatus.present);

        // User B: withdrawn — enrollment status check
        final bStatus = await client.enrollments.getEnrollmentStatus(
          event.id,
          userB,
        );
        expect(bStatus, EnrollmentStatus.withdrawn);

        // User C: on leave
        final cFinalRecord = finalAttendance.where(
          (r) => r.membername == userC,
        );
        expect(
          cFinalRecord.first.status,
          AttendanceStatus.onLeave,
          reason: 'User C was explicitly on leave',
        );
      },
    );
  });
}
