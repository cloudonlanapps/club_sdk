import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 22: MyEvents Test Suite.
///
/// Tests the `/myevents/{username}` endpoints via MyEventsSource.
/// These are member-facing operations for enrolled events, occurrences,
/// enrollments, attendance, and leave management.
///
/// Tests:
/// - 22.01: List My Events
/// - 22.02: Get My Event
/// - 22.03: Get My Event Chain
/// - 22.04: Get My Enrollment
/// - 22.05: List My Occurrences
/// - 22.06: Get My Occurrence
/// - 22.07: Get My Occurrence Attendance
/// - 22.08: Get My Attendance Stats
/// - 22.09: Accept Invite
/// - 22.10: Decline Invite
/// - 22.11: Request to Join
/// - 22.12: Withdraw
/// - 22.13: Cancel Withdraw Request
/// - 22.14: Request Leave
/// - 22.15: Cancel Leave Request
void main() {
  group('Section 22: MyEvents', () {
    late SecureClient adminClient;
    late SecureClient memberClient;

    late int venueId;
    late int programmeEventId;
    late DateTime programmeStart;

    // Relative so the one-offs stay inside the scheduling horizon (#16).
    final now = dayAt(0);

    const member = 'test_member_s22';
    const member2 = 'test_member2_s22';
    const member3 = 'test_member3_s22';
    const password = 'password123';

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean all test_ artifacts
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as admin
      await adminClient.auth.login(sudoUsername, sudoPassword);

      // 3. Create venue
      final v = await adminClient.venues.createVenue(
        name: 'test_Venue S22',
        address: 'S22 Street',
      );
      venueId = v.id;

      // 4. Register and approve members
      for (final username in [member, member2, member3]) {
        await registerAndApprove(
          client: adminClient,
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

      // Credit gates programme enrollment where the module is on (#38);
      // a no-op where it is off.
      await seedEnrolmentCreditIfGated(adminClient, [member, member2, member3]);

      // 5. Create a programme event for most tests
      programmeStart = now.add(const Duration(days: 30));
      final event = await adminClient.events.createEvent(
        title: 'test_Programme S22',
        description: 'Test programme for myevents',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: programmeStart,
        endTimeUtc: programmeStart.add(const Duration(hours: 1)),
        rrule: weeklyOn(programmeStart),
      );
      programmeEventId = event.id;

      // 6. Assign member to the programme
      await adminClient.enrollments.assign(
        programmeEventId,
        member,
      );

      // 7. Create member client
      memberClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await memberClient.auth.login(member, password);
    });

    tearDownAll(() async {
      try {
        await memberClient.auth.logout();
      } on Exception {
        // ignore
      }
      try {
        await adminClient.auth.logout();
      } on Exception {
        // ignore
      }
    });

    // =========================================================================
    // 22.01: List My Events
    // =========================================================================

    group('22.01: List My Events', () {
      test('returns enrolled events', () async {
        final result = await memberClient.myEvents.listMyEvents(member);

        expect(result.items, isNotEmpty);
        expect(
          result.items.any((e) => e.id == programmeEventId),
          isTrue,
        );
      });

      test('supports pagination', () async {
        final result = await memberClient.myEvents.listMyEvents(
          member,
          limit: 1,
          offset: 0,
        );

        expect(result.items.length, lessThanOrEqualTo(1));
        expect(result.limit, 1);
        expect(result.offset, 0);
      });

      test('supports time range filtering', () async {
        final result = await memberClient.myEvents.listMyEvents(
          member,
          fromTimeUtc: now,
          toTimeUtc: now.add(const Duration(days: 365)),
        );

        expect(result.items, isNotEmpty);
        expect(
          result.items.any((e) => e.id == programmeEventId),
          isTrue,
        );
      });
    });

    // =========================================================================
    // 22.02: Get My Event
    // =========================================================================

    group('22.02: Get My Event', () {
      test('returns event details', () async {
        final event = await memberClient.myEvents.getMyEvent(
          member,
          programmeEventId,
        );

        expect(event.id, programmeEventId);
        expect(event.title, 'test_Programme S22');
        expect(event.type, EventType.programme);
      });
    });

    // =========================================================================
    // 22.03: Get My Event Chain
    // =========================================================================

    group('22.03: Get My Event Chain', () {
      test('returns event chain', () async {
        // The chain is gone; a member reads the event's schedules (#16).
        final schedules = await memberClient.myEvents.listMyEventSchedules(
          member,
          programmeEventId,
        );

        expect(schedules, isNotEmpty);
        expect(schedules.every((s) => s.eventId == programmeEventId), isTrue);
        expect(schedules.last.isCurrent, isTrue);
      });
    });

    // =========================================================================
    // 22.04: Get My Enrollment
    // =========================================================================

    group('22.04: Get My Enrollment', () {
      test('returns enrollment details for assigned user', () async {
        final enrollment = await memberClient.myEvents.getMyEnrollment(
          member,
          programmeEventId,
        );

        expect(enrollment.membername, member);
        expect(enrollment.eventId, programmeEventId);
        expect(enrollment.status, EnrollmentStatus.assigned);
      });
    });

    // =========================================================================
    // 22.05: List My Occurrences
    // =========================================================================

    group('22.05: List My Occurrences', () {
      test('returns occurrences within date range', () async {
        final occurrences = await memberClient.myEvents.listMyOccurrences(
          member,
          fromTimeUtc: programmeStart,
          toTimeUtc: programmeStart.add(const Duration(days: 60)),
        );

        expect(occurrences, isNotEmpty);
        // Programme is weekly, so we should have multiple occurrences
        expect(occurrences.length, greaterThanOrEqualTo(2));
      });
    });

    // =========================================================================
    // 22.06: Get My Occurrence
    // =========================================================================

    group('22.06: Get My Occurrence', () {
      test('returns specific occurrence', () async {
        final occurrence = await memberClient.myEvents.getMyOccurrence(
          member,
          programmeEventId,
          programmeStart,
        );

        expect(occurrence.eventId, programmeEventId);
      });
    });

    // =========================================================================
    // 22.07: Get My Occurrence Attendance
    // =========================================================================

    group('22.07: Get My Occurrence Attendance', () {
      test('returns null when no attendance recorded', () async {
        final attendance = await memberClient.myEvents
            .getMyOccurrenceAttendance(
              member,
              programmeEventId,
              programmeStart,
            );

        expect(attendance, isNull);
      });

      test(
        'returns record after attendance is marked',
        () async {
          // Marking opens 30 minutes before an occurrence starts
          // (ATTENDANCE_NOT_YET_OPEN otherwise), so the record goes on a
          // second programme that starts in a few minutes, on its own
          // venue so it cannot clash with the main one.
          final soon = nowUtcMinute().add(const Duration(minutes: 10));
          final soonVenue = await adminClient.venues.createVenue(
            name: 'test_Venue S22 soon',
          );
          final soonEvent = await adminClient.events.createEvent(
            title: 'test_Programme S22 soon',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: soonVenue.id,
            startTimeUtc: soon,
            endTimeUtc: soon.add(const Duration(hours: 1)),
            rrule: weeklyOn(soon),
          );
          await adminClient.enrollments.assign(soonEvent.id, member);

          // Admin marks attendance
          await adminClient.attendance.markAttendance(
            soonEvent.id,
            soon,
            [
              const AttendanceMarkRecord(
                membername: member,
                status: AttendanceStatus.present,
              ),
            ],
          );

          final attendance = await memberClient.myEvents
              .getMyOccurrenceAttendance(
                member,
                soonEvent.id,
                soon,
              );

          expect(attendance, isNotNull);
          expect(attendance!.membername, member);
          expect(attendance.status, AttendanceStatus.present);
        },
      );
    });

    // =========================================================================
    // 22.08: Get My Attendance Stats
    // =========================================================================

    group('22.08: List My Attendance & Compute Stats', () {
      test(
        'returns raw attendance records',
        () async {
          // The record marked in 22.07 sits on the programme that starts
          // a few minutes from the run, so the range opens a day early.
          final records = await memberClient.myEvents.listMyAttendance(
            member,
            fromTimeUtc: now.subtract(const Duration(days: 1)),
            toTimeUtc: now.add(const Duration(days: 300)),
          );

          expect(records, isNotEmpty);
          expect(records.first.membername, member);
          expect(records.first.status, AttendanceStatus.present);
        },
      );

      test(
        'computes stats from raw records',
        () async {
          final records = await memberClient.myEvents.listMyAttendance(
            member,
            fromTimeUtc: now.subtract(const Duration(days: 1)),
            toTimeUtc: now.add(const Duration(days: 300)),
          );

          final stats = MyAttendanceStats.fromRecords(records);

          expect(stats.totalOccurrences, greaterThanOrEqualTo(0));
          expect(stats.presentCount, greaterThanOrEqualTo(1));
        },
      );
    });

    // =========================================================================
    // 22.09: Accept Invite
    // =========================================================================

    group('22.09: Accept Invite', () {
      test('member accepts invitation', () async {
        // Create a separate event to avoid TIME_CONFLICT
        final start = now.add(const Duration(days: 100));
        final event = await adminClient.events.createEvent(
          title: 'test_Accept Invite S22',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        await adminClient.enrollments.invite(
          event.id,
          member2,
        );

        final member2Client = await createRemoteSecureClient(baseUrl: baseUrl);
        await member2Client.auth.login(member2, password);

        await member2Client.myEvents.acceptInvite(member2, event.id);

        final status = await adminClient.enrollments.getEnrollmentStatus(
          event.id,
          member2,
        );
        expect(status, EnrollmentStatus.accepted);

        await member2Client.auth.logout();
      });
    });

    // =========================================================================
    // 22.10: Decline Invite
    // =========================================================================

    group('22.10: Decline Invite', () {
      test('member declines invitation', () async {
        final start = now.add(const Duration(days: 102));
        final event = await adminClient.events.createEvent(
          title: 'test_Decline Invite S22',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        await adminClient.enrollments.invite(
          event.id,
          member3,
        );

        final member3Client = await createRemoteSecureClient(baseUrl: baseUrl);
        await member3Client.auth.login(member3, password);

        await member3Client.myEvents.declineInvite(member3, event.id);

        final status = await adminClient.enrollments.getEnrollmentStatus(
          event.id,
          member3,
        );
        expect(status, EnrollmentStatus.declined);

        await member3Client.auth.logout();
      });
    });

    // =========================================================================
    // 22.11: Request to Join
    // =========================================================================

    group('22.11: Request to Join', () {
      test('member requests to join public event', () async {
        final start = now.add(const Duration(days: 104));
        final event = await adminClient.events.createEvent(
          title: 'test_Request Join S22',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        final member2Client = await createRemoteSecureClient(baseUrl: baseUrl);
        await member2Client.auth.login(member2, password);

        await member2Client.myEvents.requestToJoin(member2, event.id);

        final status = await adminClient.enrollments.getEnrollmentStatus(
          event.id,
          member2,
        );
        expect(status, EnrollmentStatus.requested);

        await member2Client.auth.logout();
      });
    });

    // =========================================================================
    // 22.12: Withdraw
    // =========================================================================

    group('22.12: Withdraw', () {
      test('member requests withdrawal with reason', () async {
        final start = now.add(const Duration(days: 106));
        final event = await adminClient.events.createEvent(
          title: 'test_Withdraw S22',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        await adminClient.enrollments.assign(
          event.id,
          member3,
        );

        final member3Client = await createRemoteSecureClient(baseUrl: baseUrl);
        await member3Client.auth.login(member3, password);

        await member3Client.myEvents.withdraw(
          member3,
          event.id,
          reason: 'Schedule conflict',
        );

        final status = await adminClient.enrollments.getEnrollmentStatus(
          event.id,
          member3,
        );
        expect(status, EnrollmentStatus.withdrawRequested);

        await member3Client.auth.logout();
      });
    });

    // =========================================================================
    // 22.13: Cancel Withdraw Request
    // =========================================================================

    group('22.13: Cancel Withdraw Request', () {
      test('member cancels pending withdrawal', () async {
        final start = now.add(const Duration(days: 108));
        final event = await adminClient.events.createEvent(
          title: 'test_Cancel Withdraw S22',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        await adminClient.enrollments.assign(
          event.id,
          member2,
        );

        final member2Client = await createRemoteSecureClient(baseUrl: baseUrl);
        await member2Client.auth.login(member2, password);

        // Withdraw then cancel
        await member2Client.myEvents.withdraw(member2, event.id);
        await member2Client.myEvents.cancelWithdrawRequest(
          member2,
          event.id,
        );

        // Status restored to previous (assigned)
        final status = await adminClient.enrollments.getEnrollmentStatus(
          event.id,
          member2,
        );
        expect(status, EnrollmentStatus.assigned);

        await member2Client.auth.logout();
      });
    });

    // =========================================================================
    // 22.14: Request Leave
    // =========================================================================

    group('22.14: Request Leave', () {
      test('member requests leave for future occurrence', () async {
        // Use the programme event — member is already assigned
        final futureOccurrence = programmeStart.add(
          const Duration(days: 7),
        ); // 2nd week

        await memberClient.myEvents.requestLeave(
          member,
          programmeEventId,
          futureOccurrence,
          reason: 'Medical appointment',
        );

        // Verify via admin — get attendance for that occurrence
        final records = await adminClient.attendance.getAttendanceForOccurrence(
          programmeEventId,
          futureOccurrence,
        );

        final memberRecord = records.where((r) => r.membername == member);
        expect(memberRecord, isNotEmpty);
        expect(
          memberRecord.first.status,
          AttendanceStatus.onLeaveRequested,
        );
      });
    });

    // =========================================================================
    // 22.15: Cancel Leave Request
    // =========================================================================

    group('22.15: Cancel Leave Request', () {
      test('member cancels pending leave request', () async {
        // Use the same occurrence from 22.14 — leave was requested
        final futureOccurrence = programmeStart.add(const Duration(days: 7));

        await memberClient.myEvents.cancelLeaveRequest(
          member,
          programmeEventId,
          futureOccurrence,
        );

        // Verify leave request is gone
        final records = await adminClient.attendance.getAttendanceForOccurrence(
          programmeEventId,
          futureOccurrence,
        );

        final memberRecord = records
            .where((r) => r.membername == member)
            .toList();
        // After cancel, the record should be deleted or status changed
        if (memberRecord.isNotEmpty) {
          expect(
            memberRecord.first.status,
            isNot(AttendanceStatus.onLeaveRequested),
          );
        }
      });
    });

    // =========================================================================
    // 22.16: Server-side eligibility filtering of /myevents
    // =========================================================================

    group('22.16: Eligibility filtering', () {
      test('public event the user is ineligible for is excluded', () async {
        // member is male (per setUpAll). Create a female-only public one-off
        // at a time that does not clash with the weekly programme.
        final start = now
            .add(const Duration(days: 200))
            .add(const Duration(hours: 8));
        final event = await adminClient.events.createEvent(
          title: 'test_FemaleOnly S22',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          gender: Gender.female,
        );

        final result = await memberClient.myEvents.listMyEvents(member);
        expect(
          result.items.any((e) => e.id == event.id),
          isFalse,
          reason: 'Ineligible public event must be filtered out by the server.',
        );
      });

      test('enrolled event remains visible after criteria tightened '
          '(grandfathered)', () async {
        // Use a dedicated member with no other enrollments so the join
        // does not trip the server's time-conflict check against the
        // weekly programme. Create a one-off with no criteria; assign
        // the male member; then tighten the event to female-only. The
        // enrollment must keep it visible in /myevents.
        const grandfatheredMember = 'test_grandfathered_s22';
        await registerAndApprove(
          client: adminClient,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: grandfatheredMember,
          email: '$grandfatheredMember@test.com',
          password: password,
          firstName: 'Grand S22',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        final start = now.add(const Duration(days: 300));
        final event = await adminClient.events.createEvent(
          title: 'test_Grandfathered S22',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        await adminClient.enrollments.assign(
          event.id,
          grandfatheredMember,
        );

        await adminClient.events.updateEvent(
          event.id,
          version: event.version,
          gender: () => Gender.female,
        );

        final gClient = await createRemoteSecureClient(baseUrl: baseUrl);
        await gClient.auth.login(grandfatheredMember, password);

        final result = await gClient.myEvents.listMyEvents(grandfatheredMember);
        expect(
          result.items.any((e) => e.id == event.id),
          isTrue,
          reason:
              'Grandfathered enrollment must keep the event visible even '
              'when current eligibility no longer matches.',
        );

        await gClient.auth.logout();
      });
    });
  });
}
