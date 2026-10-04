// OccurrenceResponse does not include enrollmentStatus or attendanceStatus.
// Enrollment and attendance status are verified via dedicated APIs.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 3: The Programme Management Story
///
/// Focus: EventType.programme, Visibility.private, assign(), assignTrial(),
/// AttendanceStatus.late, OccurrenceStatus.rescheduled.
void main() {
  group('Workflow 3: The Programme Management Story', () {
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
        'test_p1': 'Player One',
        'test_p2': 'Player Two',
        'test_t1': 'Trial Player',
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
      final venue = await client.venues.createVenue(name: 'test_Venue WF3');
      venueId = venue.id;

      // Credit gates programme enrollment where the module is on
      // (#38); a no-op where it is off.
      await seedEnrolmentCreditIfGated(client, [
        'test_p1',
        'test_p2',
        'test_t1',
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
      'Full Programme Management Execution',
      () async {
        // Attendance marking opens 30 minutes before an occurrence, so the
        // first session sits ten minutes ahead (whole minute: occurrence
        // slots are matched on whole seconds).
        final programmeStart = nowUtcMinute().add(const Duration(minutes: 10));
        final programmeEnd = programmeStart.add(const Duration(hours: 1));
        final rrule = weeklyOn(programmeStart);

        const player1 = 'test_p1';
        const player2 = 'test_p2';
        const trialPlayer = 'test_t1';

        // --- T0: Creation & Direct Assignment ---
        final event = await client.events.createEvent(
          title: 'test_Advanced Tennis Coaching',
          description: 'Elite training series',
          type: EventType.programme,
          venueId: venueId,
          visibility: Visibility.private,
          startTimeUtc: programmeStart,
          endTimeUtc: programmeEnd,
          rrule: rrule,
        );

        // Direct Assignment
        for (final username in [player1, player2]) {
          await client.enrollments.assign(
            event.id,
            username,
          );
        }

        // Assign Trial
        await client.enrollments.assignTrial(
          event.id,
          trialPlayer,
        );

        // Verification: Assigned users see event with correct statuses
        for (final username in [player1, player2]) {
          final myEvents = await client.myEvents.listMyEvents(username);
          expect(myEvents.items.any((e) => e.id == event.id), isTrue);

          final status = await client.enrollments.getEnrollmentStatus(
            event.id,
            username,
          );
          expect(status, EnrollmentStatus.assigned);
        }

        final trialStatus = await client.enrollments.getEnrollmentStatus(
          event.id,
          trialPlayer,
        );
        expect(
          trialStatus,
          EnrollmentStatus.assignedTrial,
          reason: 'Trial assignment should be visible',
        );

        // --- T1: Reschedule Occurrence ---
        final secondOccTime = programmeStart
            .add(const Duration(days: 7))
            .toUtc();
        await client.occurrences.rescheduleOccurrence(
          event.id,
          secondOccTime,
          version: await occurrenceVersion(client, event.id, secondOccTime),
          newStartTimeUtc: secondOccTime.add(const Duration(hours: 1)),
        );

        // Verification: Status check
        final occRescheduled = await client.occurrences.getOccurrence(
          event.id,
          secondOccTime,
        );
        expect(occRescheduled.status, OccurrenceStatus.rescheduled);
        expect(
          occRescheduled.actualStartTimeUtc,
          secondOccTime.add(const Duration(hours: 1)),
        );
        expect(occRescheduled.originalStartTimeUtc, secondOccTime);

        // --- T2: Late Attendance ---
        await client.attendance.markAttendance(
          event.id,
          programmeStart,
          [
            const AttendanceMarkRecord(
              membername: trialPlayer,
              status: AttendanceStatus.late,
            ),
          ],
        );

        // Verification: Attendance distribution via attendance API
        final attendance = await client.attendance.getAttendanceForOccurrence(
          event.id,
          programmeStart,
        );
        final trialRecord = attendance.where(
          (r) => r.membername == trialPlayer,
        );
        expect(trialRecord.isNotEmpty, isTrue);
        expect(trialRecord.first.status, AttendanceStatus.late);
      },
    );
  });
}
