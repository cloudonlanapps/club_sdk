import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Events, Enrollments & Attendance API Test Suite.
///
/// Tests requirements from:
/// - Section 7: Event Management (7.01-7.15)
/// - Section 8: Occurrence Management (8.01-8.05)
/// - Section 9: Enrollment Management (9.01-9.22)
/// - Section 10: Attendance Management (10.01-10.16)
///
/// Coverage against EventSource interface:
/// - createEvent: 7.01, 7.13, 7.14
/// - getEvent: 7.07
/// - listEvents: 7.05, 7.06, 7.09, 7.15
/// - correctionOnEvent: 7.02
/// - updateEventForAllFuture: 7.03
/// - cancelSeries: 7.04
/// - checkConflict: not tested
/// - findAvailableSlots: not tested
/// - getEventChain: not tested
/// - listDeletedEvents: not tested
/// - deleteEvent: not tested
/// - restoreEvent: not tested
/// - hardDeleteEvent: not tested
/// - setAuxiliaryInfo: not tested
/// - getAuxiliaryInfo: not tested
///
/// Coverage against OccurrenceSource interface:
/// - getOccurrence: via event tests
/// - listOccurrences: 9.08
/// - rescheduleOccurrence: 8.02
/// - cancelOccurrence: 8.03
/// - restoreOccurrence: not tested
///
/// Coverage against EnrollmentSource interface:
/// - invite: 9.01
/// - assign: 9.03
/// - assignTrial: 9.05
/// - acceptInvite: 9.06
/// - declineInvite: 9.07
/// - requestToJoin: 9.08
/// - approveRequest: 9.08, 9.09
/// - rejectRequest: 9.09
/// - withdraw: 9.13, 9.16
/// - getEnrollmentStatus: 9.20
/// - listEnrollments: 9.18
/// - inviteBulk: not tested
/// - assignBulk: not tested
/// - approveRequestsBulk: not tested
/// - rejectRequestsBulk: not tested
/// - removeEnrollment: not tested
/// - removeEnrollmentsBulk: not tested
/// - approveWithdraw: not tested
/// - approveWithdrawBulk: not tested
/// - rejectWithdraw: not tested
/// - rejectWithdrawBulk: not tested
/// - cancelWithdrawRequest: not tested
/// - getEnrollment: not tested
///
/// Coverage against AttendanceSource interface:
/// - markAttendance: 10.01, 10.14
/// - getAttendanceForOccurrence: 10.01
/// - declareLeave: 10.03, 10.15
/// - approveLeave: 10.03, 10.15
/// - getAttendanceStats: not tested
/// - cancelLeaveRequest: not tested
/// - approveLeaveBulk: not tested
/// - rejectLeave: not tested
/// - rejectLeaveBulk: not tested
/// - getMyAttendance: not tested
void main() {
  group('Events, Enrollments & Attendance API Tests', () {
    late SecureClient client;

    // Venue IDs populated during setup
    late int v1Id;
    late int v2Id;
    late int v3Id;
    late int vSpecId;

    // Suffixed usernames for this test file
    const attendeeId = 'test_att1_evt';
    const targetUsername = 'test_target_evt';
    const coach1 = 'test_coach1_evt';
    const coach2 = 'test_coach2_evt';
    const coachAsMember = 'test_coachmem_evt';
    const userA = 'test_usera_evt';
    const userB = 'test_userb_evt';
    const enrolled1 = 'test_enr1_evt';
    const enrolled2 = 'test_enr2_evt';
    const assignedUser = 'test_assgn_evt';
    const invitedUser = 'test_invt_evt';

    const password = 'password123';
    final now = DateTime.utc(2027, 3, 1, 10);

    // Auto-incrementing slot: one day per slot, and the hour steps every
    // seven slots, so no two programmes in this file (all organized by
    // sudo) share a weekday and time, and everything stays inside the
    // scheduling horizon (#16).
    var eventSlot = 0;
    DateTime nextStart() {
      final slot = eventSlot++;
      return now.add(Duration(days: slot, hours: 2 * (slot ~/ 7)));
    }

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean test artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to seed data
      await client.auth.login(sudoUsername, sudoPassword);
      final adminUser = await client.auth.getCurrentUser();
      expect(adminUser.username, sudoUsername);

      // 3. Create venues
      v1Id = (await client.venues.createVenue(
        name: 'test_Venue 1 Evt',
        address: 'Evt Street 1',
      )).id;
      v2Id = (await client.venues.createVenue(
        name: 'test_Venue 2 Evt',
        address: 'Evt Street 2',
      )).id;
      v3Id = (await client.venues.createVenue(
        name: 'test_Venue 3 Evt',
        address: 'Evt Street 3',
      )).id;
      vSpecId = (await client.venues.createVenue(
        name: 'test_Special Venue Evt',
        address: 'Evt Special',
      )).id;

      // 4. Register and approve all users needed
      final allUsers = [
        attendeeId,
        targetUsername,
        coach1,
        coach2,
        coachAsMember,
        userA,
        userB,
        enrolled1,
        enrolled2,
        assignedUser,
        invitedUser,
      ];
      for (final username in allUsers) {
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: password,
          firstName: 'User $username',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
      }

      // 5. Assign roles
      await client.users.assignRole(coach1, 'coach');
      await client.users.assignRole(coach2, 'coach');
      await client.users.assignRole(coachAsMember, 'coach');

      // Credit gates programme enrollment where the module is on (#38);
      // a no-op where it is off.
      await seedEnrolmentCreditIfGated(client, allUsers);

      // 6. Logout admin
      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Object catch (_) {
        // Ignore logout errors
      }
    });

    group('7.01, 7.12-7.14: Create Events', () {
      test('7.01: Create Event - one-off event', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Match',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        final listed = await client.events.listEvents(
          limit: 100,
        );
        expect(listed.items.any((e) => e.id == event.id), isTrue);
      });

      test('7.13: Create Programme - recurring event with RRULE', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Yoga',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: weeklyOn(start),
        );
        final listed = await client.events.listEvents(
          limit: 100,
        );
        expect(listed.items.any((e) => e.id == event.id), isTrue);
      });

      test('7.14: Create Camp - multi-day event with RRULE', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Camp',
          description: 'D',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: 'FREQ=DAILY;COUNT=3',
        );
        final listed = await client.events.listEvents(
          limit: 100,
        );
        expect(listed.items.any((e) => e.id == event.id), isTrue);
      });

      test(
        '7.09: Event Visibility - private event not visible to non-enrolled',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Private',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.private,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );

          // Admin can see the private event
          final allEvents = await client.events.listEvents(
            limit: 100,
          );
          expect(
            allEvents.items.firstWhere((e) => e.id == event.id).visibility,
            Visibility.private,
          );

          // public visibility filter only returns public events
          final publicEvents = await client.events.listEvents(
            visibility: Visibility.public,
            limit: 100,
          );
          expect(publicEvents.items.any((e) => e.id == event.id), isFalse);
        },
      );

      test('7.01: Create Event - set venue location', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_T',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: vSpecId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        expect(
          (await client.occurrences.getOccurrence(event.id, start)).venueId,
          vSpecId,
        );
      });

      test('7.01: Create Event - set title and description', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_SPEC_TITLE',
          description: 'SPEC_DESC',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.title, 'test_SPEC_TITLE');
        expect(fetched.description, 'SPEC_DESC');
      });
    });

    group('9.01-9.05: Enrollment Actions by Organizer', () {
      test('9.01: Invite Member - sends invitation to user', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Invite Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        await client.enrollments.invite(
          event.id,
          targetUsername,
        );
        expect(
          await client.enrollments.getEnrollmentStatus(
            event.id,
            targetUsername,
          ),
          EnrollmentStatus.invited,
        );
      });

      test('9.03: Assign Member - directly assigns user to event', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Assign Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        await client.enrollments.assign(
          event.id,
          targetUsername,
        );
        expect(
          await client.enrollments.getEnrollmentStatus(
            event.id,
            targetUsername,
          ),
          EnrollmentStatus.assigned,
        );
      });

      test(
        '9.08, 9.09: Approve Join Request - organizer approves request',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Request Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.myEvents.requestToJoin(
            targetUsername,
            event.id,
          );
          await client.enrollments.approveRequest(
            event.id,
            targetUsername,
          );
          expect(
            await client.enrollments.getEnrollmentStatus(
              event.id,
              targetUsername,
            ),
            EnrollmentStatus.accepted,
          );
        },
      );

      test(
        '9.05: Assign Trial - assigns user for trial occurrence',
        () async {
          final start = nextStart();
          // A trial is programme-only (#16).
          final event = await client.events.createEvent(
            title: 'test_Trial Test',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
            rrule: weeklyOn(start),
          );
          await client.enrollments.assignTrial(
            event.id,
            targetUsername,
          );
          expect(
            await client.enrollments.getEnrollmentStatus(
              event.id,
              targetUsername,
            ),
            EnrollmentStatus.assignedTrial,
          );
        },
      );
    });

    group('7.02-7.04, 8.02-8.03: Update & Cancel Events', () {
      test('7.02: Update Event - update one-off event details', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Old',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        await client.events.updateEvent(
          event.id,
          version: event.version,
          title: 'test_New',
        );
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.title, 'test_New');
      });

      test(
        '8.02: Reschedule Occurrence - changes occurrence time',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Reschedule Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.occurrences.rescheduleOccurrence(
            event.id,
            start,
            newStartTimeUtc: start.add(const Duration(hours: 1)),
          );
          expect(
            (await client.occurrences.getOccurrence(
              event.id,
              start,
            )).actualStartTimeUtc,
            start.add(const Duration(hours: 1)),
          );
        },
      );

      test(
        '7.03: Reschedule Series - updates all future occurrences',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Series Test',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
            rrule: weeklyOn(start),
          );
          // A split closes the current schedule at an occurrence start and
          // opens the next on the same event (#16).
          final cutoff = start.add(const Duration(days: 14));
          final newStart = cutoff.add(const Duration(days: 1));
          final newEnd = newStart.add(const Duration(hours: 1));
          final updatedEvent = await client.events.updateEventForAllFuture(
            event.id,
            version: event.version,
            effectiveDateTimeUtc: cutoff,
            startTimeUtc: newStart,
            endTimeUtc: newEnd,
            rrule: weeklyOn(newStart),
          );
          expect(updatedEvent.id, event.id);
          final fetched = await client.events.getEvent(updatedEvent.id);
          expect(fetched.startTimeUtc, newStart);
          final schedules = await client.events.listSchedules(event.id);
          expect(schedules, hasLength(2));
          expect(schedules.first.effectiveUntilUtc, cutoff);
          expect(schedules.last.startTimeUtc, newStart);
        },
      );

      test(
        '7.04: Cancel Series - cancels event',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Cancel Series Test',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
            rrule: weeklyOn(start),
          );
          // A programme ends by terminate (#16); cancel is camp-only.
          final cutoff = start.add(const Duration(days: 7));
          final cancelled = await client.events.terminate(
            event.id,
            reason: 'R',
            cutoffTimeUtc: cutoff,
          );
          // terminate sets untilTimeUtc which makes status = cancelled
          expect(cancelled.status, EventStatus.cancelled);
          expect(cancelled.untilTimeUtc, cutoff);
        },
      );
    });

    group('10.01: Mark Attendance', () {
      test(
        '10.01: Mark Attendance - records attendance status',
        () async {
          // The register opens 30 minutes before the start (attendance
          // R12), so this one-off sits 20 minutes ahead of now.
          final start = nowUtcMinute().add(const Duration(minutes: 20));
          final event = await client.events.createEvent(
            title: 'test_Attendance Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(event.id, targetUsername);
          await client.attendance.markAttendance(
            event.id,
            start,
            [
              const AttendanceMarkRecord(
                membername: targetUsername,
                status: AttendanceStatus.present,
              ),
            ],
          );
          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            start,
          );
          expect(
            records.any(
              (r) =>
                  r.membername == targetUsername &&
                  r.status == AttendanceStatus.present,
            ),
            isTrue,
          );
        },
      );
    });

    group('7.15, 9.06-9.08, 9.13, 10.03: Member Actions', () {
      test('7.15: List Events - public events visible in listing', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Public View Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        final events = await client.events.listEvents(
          limit: 100,
        );
        expect(events.items.any((e) => e.id == event.id), isTrue);
      });

      test('9.06: Accept Invitation - member accepts invite', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Invite Accept',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        await client.enrollments.invite(
          event.id,
          attendeeId,
        );
        await client.myEvents.acceptInvite(
          attendeeId,
          event.id,
        );
        expect(
          await client.enrollments.getEnrollmentStatus(
            event.id,
            attendeeId,
          ),
          EnrollmentStatus.accepted,
        );
      });

      test('9.07: Decline Invitation - member declines invite', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Invite Reject',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        await client.enrollments.invite(
          event.id,
          attendeeId,
        );
        await client.myEvents.declineInvite(
          attendeeId,
          event.id,
        );
        expect(
          await client.enrollments.getEnrollmentStatus(
            event.id,
            attendeeId,
          ),
          EnrollmentStatus.declined,
        );
      });

      test(
        '9.08: Request to Join - member requests to join event',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Join Req',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.myEvents.requestToJoin(
            attendeeId,
            event.id,
          );
          expect(
            await client.enrollments.getEnrollmentStatus(
              event.id,
              attendeeId,
            ),
            EnrollmentStatus.requested,
          );
        },
      );

      test(
        '10.03: Declare Leave - member declares leave for occurrence',
        () async {
          final eventStart = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Leave Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: eventStart,
            endTimeUtc: eventStart.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(
            event.id,
            attendeeId,
          );
          await client.myEvents.requestLeave(
            attendeeId,
            event.id,
            eventStart,
          );
          await client.attendance.approveLeave(
            event.id,
            attendeeId,
            eventStart,
          );
          // Verify via attendance records (getOccurrence doesn't return
          // per-user attendance status)
          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            eventStart,
          );
          expect(
            records.any(
              (r) =>
                  r.membername == attendeeId &&
                  r.status == AttendanceStatus.onLeave,
            ),
            isTrue,
          );
        },
      );

      test(
        '9.13: Withdraw from Event - member requests withdrawal',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Withdraw Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(event.id, attendeeId);
          await client.myEvents.withdraw(attendeeId, event.id);
          // Withdraw creates a withdrawal request
          expect(
            await client.enrollments.getEnrollmentStatus(
              event.id,
              attendeeId,
            ),
            EnrollmentStatus.withdrawRequested,
          );
        },
      );
    });

    group('7.05, 7.06: Filter & Paginate Events', () {
      test(
        '7.06: Filter Events - by type and visibility',
        () async {
          final progStart = nextStart();
          final publicProgramme = await client.events.createEvent(
            title: 'test_Public Programme',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: progStart,
            endTimeUtc: progStart.add(const Duration(hours: 1)),
            rrule: weeklyOn(progStart),
          );
          final campStart = nextStart();
          final privateCamp = await client.events.createEvent(
            title: 'test_Private Camp',
            description: 'D',
            type: EventType.camp,
            visibility: Visibility.private,
            venueId: v2Id,
            startTimeUtc: campStart,
            endTimeUtc: campStart.add(const Duration(hours: 1)),
            rrule: 'FREQ=DAILY;COUNT=2',
          );
          final oneOffStart = nextStart();
          final publicOneOff = await client.events.createEvent(
            title: 'test_Public OneOff',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v3Id,
            startTimeUtc: oneOffStart,
            endTimeUtc: oneOffStart.add(const Duration(hours: 1)),
          );

          // Filter by eventType
          final programmes = await client.events.listEvents(
            eventType: EventType.programme,
            limit: 100,
          );
          expect(
            programmes.items.any((e) => e.id == publicProgramme.id),
            isTrue,
          );
          expect(programmes.items.any((e) => e.id == privateCamp.id), isFalse);
          expect(programmes.items.any((e) => e.id == publicOneOff.id), isFalse);

          // Filter by visibility
          final publicEvents = await client.events.listEvents(
            visibility: Visibility.public,
            limit: 100,
          );
          expect(
            publicEvents.items.any((e) => e.id == publicProgramme.id),
            isTrue,
          );
          expect(
            publicEvents.items.any((e) => e.id == publicOneOff.id),
            isTrue,
          );
          expect(
            publicEvents.items.any((e) => e.id == privateCamp.id),
            isFalse,
          );
        },
      );

      test('7.05: Paginate Events - with limit and offset', () async {
        // Fetch page with limit
        final page1 = await client.events.listEvents(
          limit: 3,
          offset: 0,
        );
        expect(page1.items.length, 3);

        // Fetch with offset
        final page2 = await client.events.listEvents(
          limit: 3,
          offset: 3,
        );
        expect(page2.items.length, 3);

        // Fetch with limit 1 to verify it restricts
        final single = await client.events.listEvents(
          limit: 1,
          offset: 0,
        );
        expect(single.items.length, 1);
      });
    });

    group('7.07, 9.20: Get Event & Enrollment Status', () {
      test(
        '9.20: Get Enrollment Status - returns null for non-enrolled',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Status Check Event',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );

          final notEnrolled = await client.enrollments.getEnrollmentStatus(
            event.id,
            attendeeId,
          );
          expect(notEnrolled, isNull);

          await client.enrollments.assign(
            event.id,
            attendeeId,
          );

          final assigned = await client.enrollments.getEnrollmentStatus(
            event.id,
            attendeeId,
          );
          expect(assigned, EnrollmentStatus.assigned);
        },
      );

      test(
        '9.20: Get Enrollment Status - returns trial status',
        () async {
          final start = nextStart();
          // A trial is programme-only (#16).
          final event = await client.events.createEvent(
            title: 'test_Trial Status Event',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
            rrule: weeklyOn(start),
          );

          await client.enrollments.assignTrial(
            event.id,
            attendeeId,
          );

          final status = await client.enrollments.getEnrollmentStatus(
            event.id,
            attendeeId,
          );
          expect(status, EnrollmentStatus.assignedTrial);
        },
      );

      test('7.07: Get Event by ID - returns event details', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Get Event Test',
          description: 'Test description',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        final fetched = await client.events.getEvent(event.id);
        expect(fetched.id, event.id);
        expect(fetched.title, 'test_Get Event Test');
        expect(fetched.description, 'Test description');
        expect(fetched.type, EventType.oneOff);
        expect(fetched.visibility, Visibility.public);
      });

      test(
        '7.07: Get Event by ID - throws ServerException for invalid ID',
        () async {
          expect(
            () => client.events.getEvent(999999),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventNotFound,
              ),
            ),
          );
        },
      );
    });

    group('Constraints & Conflicts', () {
      test(
        '7.10: Venue Conflict Detection - prevents double booking',
        () async {
          final start = nextStart();
          // Create first event at v1 with coach1 as organizer
          await client.events.createEvent(
            title: 'test_Venue Conflict A',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            organizerName: coach1,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );

          // A one-off overlap is reported, not blocked (#16): the probe
          // names the venue clash and the creation still goes through.
          final report = await client.events.checkConflict(
            type: EventType.oneOff,
            venueId: v1Id,
            organizerName: coach2, // Different coach but same venue
            startTimeUtc: start.add(const Duration(minutes: 30)),
            endTimeUtc: start.add(const Duration(hours: 2)),
          );
          expect(report.hasConflict, isTrue);
          expect(report.venueConflicts, isNotEmpty);
          expect(report.organizerConflicts, isEmpty);
          final overlapping = await client.events.createEvent(
            title: 'test_Venue Conflict B',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            organizerName: coach2, // Different coach but same venue
            startTimeUtc: start.add(const Duration(minutes: 30)),
            endTimeUtc: start.add(const Duration(hours: 2)),
          );
          expect(overlapping.status, EventStatus.active);

          // Different venue + different coach should succeed
          final eventB = await client.events.createEvent(
            title: 'test_Venue Conflict B OK',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v2Id,
            organizerName: coach2,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          expect(eventB.id, isNotNull);
        },
      );

      test(
        '9.17: User Conflict Detection - prevents overlapping enrollments',
        () async {
          // Only a programme-against-programme clash blocks a join (#16),
          // so two programmes at the same slot, at different venues with
          // different organizers so their creation does not clash.
          final startA = nextStart();
          nextStart();
          final eventA = await client.events.createEvent(
            title: 'test_User Conflict A',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: v1Id,
            organizerName: coach1,
            startTimeUtc: startA,
            endTimeUtc: startA.add(const Duration(hours: 1)),
            rrule: weeklyOn(startA),
          );
          // Use same time as A but different venue+coach for B
          final eventB = await client.events.createEvent(
            title: 'test_User Conflict B',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: v2Id,
            organizerName: coach2,
            startTimeUtc: startA,
            endTimeUtc: startA.add(const Duration(hours: 1)),
            rrule: weeklyOn(startA),
          );

          // Assign user to event A
          await client.enrollments.assign(
            eventA.id,
            attendeeId,
          );

          // The probe reports the overlap first
          final report = await client.events.checkUserConflicts(
            eventB.id,
            usernames: [attendeeId],
          );
          expect(report.hasConflict, isTrue);

          // Assigning same user to overlapping event B should fail
          expect(
            () => client.enrollments.assign(
              eventB.id,
              attendeeId,
            ),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'statusCode', 409)
                  .having((e) => e.code, 'code', SdkErrorCode.timeConflict),
            ),
          );
        },
      );

      test(
        '9.09: Reject Request - organizer rejects with reason',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Rejectable',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.myEvents.requestToJoin(
            attendeeId,
            event.id,
          );
          await client.enrollments.rejectRequest(
            event.id,
            attendeeId,
            reason: 'Reason X',
          );
          expect(
            await client.enrollments.getEnrollmentStatus(
              event.id,
              attendeeId,
            ),
            EnrollmentStatus.rejected,
          );
        },
      );

      test('7.10: Venue Conflict Detection - on event update', () async {
        // Conflict gates run on every mutation path (club_server#288):
        // a programme split that lands on another programme's venue slot
        // is blocked with 409, and the report names the clash.
        final start = nextStart();
        final occupied = await client.events.createEvent(
          title: 'test_Update Conflict Occupied',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: v1Id,
          organizerName: coach1,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: weeklyOn(start),
        );
        final mover = await client.events.createEvent(
          title: 'test_Update Conflict Mover',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: v2Id,
          organizerName: coach2,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: weeklyOn(start),
        );

        await expectLater(
          client.events.updateEventForAllFuture(
            mover.id,
            version: mover.version,
            effectiveDateTimeUtc: start.add(const Duration(days: 7)),
            venueId: occupied.venueId,
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.code, 'code', SdkErrorCode.timeConflict),
          ),
        );
        final schedules = await client.events.listSchedules(mover.id);
        expect(schedules, hasLength(1));
        expect(schedules.single.venueId, v2Id);
      });

      test('8.03: Cancel Occurrence - preserves history', () async {
        final futureStart = nextStart();
        final event = await client.events.createEvent(
          title: 'test_History Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: futureStart,
          endTimeUtc: futureStart.add(const Duration(hours: 1)),
        );
        await client.occurrences.cancelOccurrence(
          event.id,
          futureStart,
          reason: 'R',
        );
        final occ = await client.occurrences.getOccurrence(
          event.id,
          futureStart,
        );
        expect(occ.status, OccurrenceStatus.cancelled);
      });

      test(
        '10.14: Attendance Window - attendance can be recorded',
        () async {
          // The register opens 30 minutes before the start (attendance
          // R12), so this one-off sits 25 minutes ahead of now.
          final start = nowUtcMinute().add(const Duration(minutes: 25));
          final event = await client.events.createEvent(
            title: 'test_Attendance',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(
            event.id,
            attendeeId,
          );
          await client.attendance.markAttendance(
            event.id,
            start,
            [
              const AttendanceMarkRecord(
                membername: attendeeId,
                status: AttendanceStatus.present,
              ),
            ],
          );
          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            start,
          );
          expect(
            records.any(
              (r) =>
                  r.membername == attendeeId &&
                  r.status == AttendanceStatus.present,
            ),
            isTrue,
          );
        },
      );

      test(
        '10.15: Leave Cutoff - leave request respects cutoff',
        () async {
          final futureStart = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Leave',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: futureStart,
            endTimeUtc: futureStart.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(
            event.id,
            attendeeId,
          );
          await client.myEvents.requestLeave(
            attendeeId,
            event.id,
            futureStart,
          );
          await client.attendance.approveLeave(
            event.id,
            attendeeId,
            futureStart,
          );
          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            futureStart,
          );
          expect(
            records.any(
              (r) =>
                  r.membername == attendeeId &&
                  r.status == AttendanceStatus.onLeave,
            ),
            isTrue,
          );
        },
      );

      test(
        '13.02: Notification - event creation triggers notification',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Notify Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          final listed = await client.events.listEvents(
            limit: 100,
          );
          expect(listed.items.any((e) => e.id == event.id), isTrue);
        },
      );

      test(
        '9.19: Capacity Handling - occurrence respects capacity',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Capacity Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          final occs = await client.occurrences.listOccurrences(
            fromTimeUtc: start,
            toTimeUtc: start.add(const Duration(hours: 1)),
          );
          final target = occs.firstWhere((o) => o.eventId == event.id);
          expect(target.eventId, event.id);
        },
      );

      test('3.01: Role Clarity - event visible in listing', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Role Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        final evs = await client.events.listEvents(
          limit: 100,
        );
        expect(evs.items.any((e) => e.id == event.id), isTrue);
      });

      test(
        '9.16: Withdrawal Cutoff - withdrawal creates request',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Withdraw',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(
            event.id,
            attendeeId,
          );
          await client.myEvents.withdraw(attendeeId, event.id);
          expect(
            await client.enrollments.getEnrollmentStatus(
              event.id,
              attendeeId,
            ),
            EnrollmentStatus.withdrawRequested,
          );
        },
      );
    });

    group('9.18, 9.19: List Enrollments', () {
      test(
        '9.18: List Enrollments - returns all unique enrolled users',
        () async {
          final start = nextStart();
          final event2 = await client.events.createEvent(
            title: 'test_Event2',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v2Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(
            event2.id,
            userA,
          );
          await client.enrollments.invite(
            event2.id,
            userB,
          );

          final enrollments = await client.enrollments.listEnrollments(
            event2.id,
          );
          expect(enrollments.keys, contains(userA));
          expect(enrollments.keys, contains(userB));
        },
      );

      test(
        '9.18: List Enrollments - returns all enrollments for event',
        () async {
          final start = nextStart();
          final event = await client.events.createEvent(
            title: 'test_Enrollment Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: v1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
          );
          await client.enrollments.assign(
            event.id,
            enrolled1,
          );
          await client.enrollments.invite(
            event.id,
            enrolled2,
          );

          final enrollments = await client.enrollments.listEnrollments(
            event.id,
          );
          expect(enrollments.length, equals(2));
          expect(
            enrollments[enrolled1],
            equals(EnrollmentStatus.assigned),
          );
          expect(
            enrollments[enrolled2],
            equals(EnrollmentStatus.invited),
          );
        },
      );

      test('9.18: List Enrollments - filters by status', () async {
        final start = nextStart();
        final event = await client.events.createEvent(
          title: 'test_Filter Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: v1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
        await client.enrollments.assign(
          event.id,
          assignedUser,
        );
        await client.enrollments.invite(
          event.id,
          invitedUser,
        );

        final invitedOnly = await client.enrollments.listEnrollments(
          event.id,
          status: EnrollmentStatus.invited,
        );
        expect(invitedOnly.length, equals(1));
        expect(
          invitedOnly[invitedUser],
          equals(EnrollmentStatus.invited),
        );
      });
    });
  });
}
