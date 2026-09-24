// OccurrenceResponse does not include enrollmentStatus or attendanceStatus.
// Enrollment and attendance status are verified via dedicated APIs.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 2: Cancellation Flow Story
///
/// Steps:
/// 1. T0 (Mar 1, 09:00): Organizer creates a One-off Public Event.
/// 2. T0: Organizer invites 4 people (A, B, C, D).
/// 3. T1 (Mar 1, 10:00): A, B, C Accept; D Rejects.
/// 4. T2 (Mar 1, 11:00): C Notifies Leave.
/// 5. T3 (Mar 2, 09:00): Organizer terminates the programme at its first
///    occurrence (a programme is ended by `terminate`, never `cancel`, #16).
/// 6. T3 Verification: All users (A, B, C, D) see the event as 'Cancelled'.
void main() {
  group('Workflow 2: Cancellation Flow Story', () {
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
      }

      // Create venue
      final venue = await client.venues.createVenue(name: 'test_Venue WF2');
      venueId = venue.id;

      // Credit gates programme enrollment where the module is on
      // (#38); a no-op where it is off.
      await seedEnrolmentCreditIfGated(client, [
        'test_user_a',
        'test_user_b',
        'test_user_c',
        'test_user_d',
      ]);

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
      'Full Cancellation Execution',
      () async {
        final eventStart = DateTime.utc(2027, 3, 5, 10);
        final eventEnd = DateTime.utc(2027, 3, 5, 11);

        const userA = 'test_user_a';
        const userB = 'test_user_b';
        const userC = 'test_user_c';
        const userD = 'test_user_d';

        // --- setup T0 & T1 ---
        final event = await client.events.createEvent(
          title: 'test_Team Workshop',
          description: 'Design sprint',
          type: EventType.programme,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: eventStart,
          endTimeUtc: eventEnd,
          rrule: weeklyOn(eventStart),
        );

        for (final u in [userA, userB, userC, userD]) {
          await client.enrollments.invite(
            event.id,
            u,
          );
        }

        // Verification T0: Users see the event as 'invited'
        for (final u in [userA, userB, userC, userD]) {
          final enrollment = await client.myEvents.getMyEnrollment(
            u,
            event.id,
          );
          expect(enrollment.status, EnrollmentStatus.invited);
        }

        await client.myEvents.acceptInvite(userA, event.id);
        await client.myEvents.acceptInvite(userB, event.id);
        await client.myEvents.acceptInvite(userC, event.id);
        await client.myEvents.declineInvite(userD, event.id);

        // --- T2: C Notifies Leave ---
        await client.myEvents.requestLeave(
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
        // Verification T2: C is still accepted and on leave
        final cStatus = await client.enrollments.getEnrollmentStatus(
          event.id,
          userC,
        );
        expect(cStatus, EnrollmentStatus.accepted);
        final cAttendance = await client.attendance.getAttendanceForOccurrence(
          event.id,
          eventStart,
        );
        final cRecord = cAttendance.where((r) => r.membername == userC);
        expect(cRecord.first.status, AttendanceStatus.onLeave);

        // --- T3: Cancellation (terminate at the first occurrence) ---
        await client.events.terminate(
          event.id,
          reason: 'Internal reschedule',
          cutoffTimeUtc: eventStart,
        );

        // Verification T3: Event is cancelled
        final cancelledEvent = await client.events.getEvent(event.id);
        expect(cancelledEvent.status, EventStatus.cancelled);

        // Cancellation is an event-level fact (#108): enrollment rows are left
        // unchanged so the relationship survives a later undo. Availability is
        // derived from the event's untilTimeUtc / occurrence status, not from
        // enrollment state. A, B, C therefore stay 'accepted'.
        for (final u in [userA, userB, userC]) {
          final status = await client.enrollments.getEnrollmentStatus(
            event.id,
            u,
          );
          expect(
            status,
            EnrollmentStatus.accepted,
            reason: '$u enrollment must be untouched by event cancellation',
          );
        }
      },
    );

    test(
      'Synthesized occurrences after until_time are cancelled with reason',
      () async {
        // Create a weekly programme so terminate has multiple slots to
        // cover. Then terminate the series and list occurrences across a window
        // that extends past until_time — those slots must come back as
        // cancelled with a non-empty cancelReason.
        final firstStart = DateTime.utc(2027, 4, 5, 10);
        final firstEnd = firstStart.add(const Duration(hours: 1));

        final event = await client.events.createEvent(
          title: 'test_Until-time Synthesis',
          description: 'Series for until_time synthesis check',
          type: EventType.programme,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: firstStart,
          endTimeUtc: firstEnd,
          rrule: weeklyOn(firstStart),
        );

        await client.events.terminate(
          event.id,
          reason: 'Synthesis test',
          cutoffTimeUtc: firstStart,
        );

        // Window covers four weekly slots, all after the cancellation cutoff.
        final occurrences = await client.occurrences.listOccurrences(
          fromTimeUtc: firstStart,
          toTimeUtc: firstStart.add(const Duration(days: 28)),
        );
        final mine = occurrences.where((o) => o.eventId == event.id).toList();
        expect(
          mine,
          isNotEmpty,
          reason: 'cancelled series should still synthesize occurrences',
        );

        for (final occ in mine) {
          expect(
            occ.status,
            OccurrenceStatus.cancelled,
            reason:
                'occurrence at ${occ.actualStartTimeUtc} should be '
                'cancelled',
          );
          expect(
            occ.cancelReason,
            isNotNull,
            reason: 'cancelled occurrence must carry a cancelReason',
          );
          expect(occ.cancelReason, isNotEmpty);
        }
      },
    );
  });
}
