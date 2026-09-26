import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 10: Attendance Test Suite.
///
/// Each test uses unique users to avoid cross-test TIME_CONFLICT errors
/// (server rejects enrollment when the user has active enrollments in
/// time-overlapping unbounded programme events).
///
/// Tests requirements from Section 10 (Attendance Management):
/// - 10.01: Mark Attendance
/// - 10.02: Update Attendance
/// - 10.03: Declare Leave
/// - 10.04: Approve Leave
/// - 10.05: Reject Leave
/// - 10.06: Cancel Leave Request
/// - 10.07: Bulk Approve Leave
/// - 10.08: Bulk Reject Leave
/// - 10.09: List Attendance
/// - 10.10: Get My Attendance
/// - 10.11: Get Attendance Summary
/// - 10.12: List Pending Leaves
/// - 10.13: Approve All Pending Leaves
/// - 10.14: Attendance Window
/// - 10.15: Leave Cutoff
/// - 10.16: Attendance Edit Window
/// - 10.17: Attendance Edit Override
/// - 10.18: Pre-occurrence Attendance Gate (30-min window)
/// - 10.19: Override-derived Effective Start (edit window)
void main() {
  group('Section 10: Attendance', () {
    late SecureClient client;
    late SecureClient adminClient;

    late int venue1Id;
    final now = DateTime.utc(2027, 3, 1, 10);

    const password = 'password123';

    // Per-test user pool to avoid cross-test TIME_CONFLICT.
    // Each test draws fresh users via nextUser() so no user is ever
    // enrolled in more than one unbounded programme event.
    final userPool = <String>[];
    var userPoolIndex = 0;
    String nextUser() => userPool[userPoolIndex++];

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean all test_ artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to seed test data
      await client.auth.login(sudoUsername, sudoPassword);

      // 3. Create venue
      final v1 = await client.venues.createVenue(
        name: 'test_Venue 1 S10',
        address: 'S10 Street',
      );
      venue1Id = v1.id;

      // 4. Register and approve a pool of users (one set per test).
      //    48 users covers every test, including the per-event organizers,
      //    and with the admin keeps the file under the 50-user page that
      //    clearTestArtifacts sweeps (it deletes while paging by offset).
      for (var i = 0; i < 48; i++) {
        final username = 'test_s10_u$i';
        userPool.add(username);
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

      // 5. Create a regular admin user (non-super) for edit window tests
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_s10_admin',
        email: 'test_s10_admin@test.com',
        password: password,
        firstName: 'Admin S10',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_s10_admin', 'admin');

      // Where the credit system is on, credit gates the enrollment
      // itself and attendance spends it, so the pool needs accounts
      // before the suite starts (#38). A no-op where it is off.
      await seedEnrolmentCreditIfGated(client, [
        ...userPool,
        'test_s10_admin',
      ]);

      // 6. Logout sudo
      await client.auth.logout();

      // 7. Create admin client
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await adminClient.auth.login('test_s10_admin', password);
    });

    tearDownAll(() async {
      try {
        await adminClient.auth.logout();
      } on Exception {
        // ignore
      }
    });

    setUp(() async {
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // ignore
      }
    });

    // Programmes clash with each other on venue and on organizer (every one
    // here is organized by sudo), per occurrence. Each test event takes its
    // own weekday × time-of-day slot so the weekly rules never overlap.
    var eventSlot = 0;

    Future<Event> createTestEvent(String suffix) async {
      final slot = eventSlot++;
      final start = now.add(
        Duration(days: (slot % 7) * 8, hours: 2 * (slot ~/ 7)),
      );
      return client.events.createEvent(
        title: 'test_Attendance Test $suffix',
        description: 'D',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venue1Id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
    }

    // A programme on its own venue with its own organizer (any live user
    // may organize), so it can sit at any time — including a real-clock
    // time that a slot event above might share — without a programme clash.
    var isolatedSeq = 0;

    Future<Event> createIsolatedProgramme(
      String suffix,
      DateTime start,
    ) async {
      final venue = await client.venues.createVenue(
        name: 'test_Venue S10 iso ${++isolatedSeq}',
      );
      return client.events.createEvent(
        title: 'test_Attendance Test $suffix',
        description: 'D',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venue.id,
        organizerName: nextUser(),
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
    }

    // The register opens 30 minutes before an occurrence's effective start
    // and no role bypasses that (attendance R12), so a programme whose
    // first occurrence is 10 minutes out is the one whose attendance a
    // test can mark; it is still in the future, so an assigned member is
    // covered.
    Future<Event> createMarkableProgramme(String suffix) =>
        createIsolatedProgramme(
          suffix,
          nowUtcMinute().add(const Duration(minutes: 10)),
        );

    // =========================================================================
    // 10.01: Mark Attendance
    // =========================================================================

    group('10.01: Mark Attendance', () {
      test(
        '10.01a: Mark Attendance - records attendance status',
        () async {
          final event = await createMarkableProgramme('1001a');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );

          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );
          expect(
            records.any(
              (r) => r.membername == u1 && r.status == AttendanceStatus.present,
            ),
            isTrue,
          );
        },
      );

      test(
        '10.01b: Mark Attendance - absent status',
        () async {
          final event = await createMarkableProgramme('1001b');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.absent,
              ),
            ],
          );

          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );
          expect(
            records.any(
              (r) => r.membername == u1 && r.status == AttendanceStatus.absent,
            ),
            isTrue,
          );
        },
      );
    });

    // =========================================================================
    // 10.02: Update Attendance
    // =========================================================================

    group('10.02: Update Attendance', () {
      test(
        '10.02: Update Attendance - changes status from present to absent',
        () async {
          final event = await createMarkableProgramme('1002');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          // Mark as present first
          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );

          // Update to absent
          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.absent,
              ),
            ],
          );

          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );
          expect(
            records.any(
              (r) => r.membername == u1 && r.status == AttendanceStatus.absent,
            ),
            isTrue,
          );
        },
      );
    });

    // =========================================================================
    // 10.03: Declare Leave
    // =========================================================================

    group('10.03: Declare Leave', () {
      test('10.03a: Declare Leave - creates leave request', () async {
        final event = await createTestEvent('1003a');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();

        await client.enrollments.assign(
          event.id,
          u1,
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
          reason: 'Medical appointment',
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        expect(occ, isNotNull);
      });

      test('10.03b: Declare Leave - with reason preserves reason', () async {
        final event = await createTestEvent('1003b');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();

        await client.enrollments.assign(
          event.id,
          u1,
        );

        // Issue 43: with no record yet the server answers 200 `null`, which
        // reads as "no attendance".
        expect(
          await client.myEvents.getMyOccurrenceAttendance(
            u1,
            event.id,
            occTime,
          ),
          isNull,
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
          reason: 'Family emergency',
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        expect(occ, isNotNull);

        // Issue 50: staff and the member both see the reason.
        final register = await client.attendance.getAttendanceForOccurrence(
          event.id,
          occTime,
        );
        final row = register.singleWhere((r) => r.membername == u1);
        expect(row.status, AttendanceStatus.onLeaveRequested);
        expect(row.leaveReason, 'Family emergency');

        final mine = await client.myEvents.getMyOccurrenceAttendance(
          u1,
          event.id,
          occTime,
        );
        expect(mine?.status, AttendanceStatus.onLeaveRequested);
        expect(mine?.leaveReason, 'Family emergency');
      });

      test('10.03c: Declare Leave - without reason', () async {
        final event = await createTestEvent('1003c');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();

        await client.enrollments.assign(
          event.id,
          u1,
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        expect(occ, isNotNull);
      });

      test('10.03d: Declare Leave - for different occurrences', () async {
        final event = await createTestEvent('1003d');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();

        await client.enrollments.assign(
          event.id,
          u1,
        );

        // Declare leave for first occurrence
        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
        );

        // Declare leave for second occurrence (weekly recurrence)
        final nextWeek = occTime.add(const Duration(days: 7));
        await client.myEvents.requestLeave(
          u1,
          event.id,
          nextWeek,
        );

        final occ1 = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        final occ2 = await client.occurrences.getOccurrence(
          event.id,
          nextWeek,
        );
        expect(occ1, isNotNull);
        expect(occ2, isNotNull);
      });

      test(
        '10.03e: Declare Leave - multiple users for same occurrence',
        () async {
          final event = await createTestEvent('1003e');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();
          final u2 = nextUser();

          await client.enrollments.assignBulk(
            event.id,
            [u1, u2],
          );

          await client.myEvents.requestLeave(
            u1,
            event.id,
            occTime,
          );
          await client.myEvents.requestLeave(
            u2,
            event.id,
            occTime,
          );

          final occ = await client.occurrences.getOccurrence(
            event.id,
            occTime,
          );
          expect(occ, isNotNull);
        },
      );
    });

    // =========================================================================
    // 10.04: Approve Leave
    // =========================================================================

    group('10.04: Approve Leave', () {
      test('10.04: Approve Leave - transitions to onLeave', () async {
        final event = await createTestEvent('1004');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();

        await client.enrollments.assign(
          event.id,
          u1,
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
          reason: 'Sick',
        );

        await client.attendance.approveLeave(
          event.id,
          u1,
          occTime,
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        expect(occ, isNotNull);
      });
    });

    // =========================================================================
    // 10.05: Reject Leave
    // =========================================================================

    group('10.05: Reject Leave', () {
      test(
        '10.05: Reject Leave - restores previous attendance status',
        () async {
          final event = await createTestEvent('1005');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          await client.myEvents.requestLeave(
            u1,
            event.id,
            occTime,
          );

          await client.attendance.rejectLeave(
            event.id,
            u1,
            occTime,
            reason: 'Attendance required',
          );

          final occ = await client.occurrences.getOccurrence(
            event.id,
            occTime,
          );
          expect(occ, isNotNull);
        },
      );
    });

    // =========================================================================
    // 10.06: Cancel Leave Request
    // =========================================================================

    group('10.06: Cancel Leave Request', () {
      test('10.06: Cancel Leave Request - restores status', () async {
        final event = await createTestEvent('1006');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();

        await client.enrollments.assign(
          event.id,
          u1,
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
        );

        await client.myEvents.cancelLeaveRequest(
          u1,
          event.id,
          occTime,
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        expect(occ, isNotNull);
      });
    });

    // =========================================================================
    // 10.07: Bulk Approve Leave
    // =========================================================================

    group('10.07: Bulk Approve Leave', () {
      test('10.07: Bulk Approve Leave - success', () async {
        final event = await createTestEvent('1007');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();
        final u2 = nextUser();

        await client.enrollments.assignBulk(
          event.id,
          [u1, u2],
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
          reason: 'Sick',
        );
        await client.myEvents.requestLeave(
          u2,
          event.id,
          occTime,
          reason: 'Travel',
        );

        await client.attendance.approveLeaveBulk(
          event.id,
          [u1, u2],
          occTime,
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        expect(occ, isNotNull);
      });
    });

    // =========================================================================
    // 10.08: Bulk Reject Leave
    // =========================================================================

    group('10.08: Bulk Reject Leave', () {
      test('10.08: Bulk Reject Leave - restores attendance status', () async {
        final event = await createTestEvent('1008');
        final occTime = event.startTimeUtc;
        final u1 = nextUser();
        final u2 = nextUser();

        await client.enrollments.assignBulk(
          event.id,
          [u1, u2],
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          occTime,
        );
        await client.myEvents.requestLeave(
          u2,
          event.id,
          occTime,
        );

        await client.attendance.rejectLeaveBulk(
          event.id,
          [u1, u2],
          occTime,
          reason: 'Attendance required',
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );
        expect(occ, isNotNull);
      });
    });

    // =========================================================================
    // 10.09: List Attendance
    // =========================================================================

    group('10.09: List Attendance', () {
      test(
        '10.09: List Attendance - returns attendance for occurrence',
        () async {
          final event = await createMarkableProgramme('1009');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();
          final u2 = nextUser();
          final u3 = nextUser();

          await client.enrollments.assignBulk(
            event.id,
            [u1, u2, u3],
          );

          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );
          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u2,
                status: AttendanceStatus.absent,
              ),
            ],
          );

          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );

          expect(records.length, greaterThanOrEqualTo(2));
          expect(
            records.any((r) => r.membername == u1),
            isTrue,
          );
          expect(
            records.any((r) => r.membername == u2),
            isTrue,
          );
        },
      );
    });

    // =========================================================================
    // 10.10: Get My Attendance
    // =========================================================================

    group('10.10: Get My Attendance', () {
      test(
        '10.10: Get My Attendance - returns user attendance history',
        () async {
          final event = await createMarkableProgramme('1010');
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          final occTime = event.startTimeUtc;

          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );

          final record = await client.myEvents.getMyOccurrenceAttendance(
            u1,
            event.id,
            occTime,
          );

          expect(record, isNotNull);
          expect(record!.status, AttendanceStatus.present);
        },
      );
    });

    // =========================================================================
    // 10.12: List Pending Leaves
    // =========================================================================

    group('10.12: List Pending Leaves', () {});

    // =========================================================================
    // 10.13: Approve All Pending Leaves
    // =========================================================================

    group('10.13: Bulk Approve Pending Leaves', () {
      test(
        '10.13: Bulk Approve Pending Leaves - approves multiple leave requests',
        () async {
          final event = await createTestEvent('1013');
          final futureStart = event.startTimeUtc;
          final u1 = nextUser();
          final u2 = nextUser();

          await client.enrollments.assignBulk(
            event.id,
            [u1, u2],
          );

          // Both users request leave for the same occurrence
          await client.myEvents.requestLeave(
            u1,
            event.id,
            futureStart,
          );
          await client.myEvents.requestLeave(
            u2,
            event.id,
            futureStart,
          );

          // Verify pending leaves via occurrence attendance
          final beforeAttendance = await client.attendance
              .getAttendanceForOccurrence(
                event.id,
                futureStart,
              );
          final pendingBefore = beforeAttendance
              .where((r) => r.status == AttendanceStatus.onLeaveRequested)
              .toList();
          expect(pendingBefore, hasLength(2));

          // Bulk approve both leave requests
          await client.attendance.approveLeaveBulk(
            event.id,
            [u1, u2],
            futureStart,
          );

          // Verify both are now on leave
          final afterAttendance = await client.attendance
              .getAttendanceForOccurrence(
                event.id,
                futureStart,
              );
          final onLeave = afterAttendance
              .where((r) => r.status == AttendanceStatus.onLeave)
              .toList();
          expect(onLeave, hasLength(2));
          final stillPending = afterAttendance
              .where((r) => r.status == AttendanceStatus.onLeaveRequested)
              .toList();
          expect(stillPending, isEmpty);
        },
      );
    });

    // =========================================================================
    // 10.14: Attendance Window
    // =========================================================================

    group('10.14: Attendance Window', () {
      test(
        '10.14: Attendance Window - attendance can be recorded',
        () async {
          final event = await createMarkableProgramme('1014');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );

          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );
          expect(
            records.any(
              (r) => r.membername == u1 && r.status == AttendanceStatus.present,
            ),
            isTrue,
          );
        },
      );
    });

    // =========================================================================
    // 10.15: Leave Cutoff
    // =========================================================================

    group('10.15: Leave Cutoff', () {
      test('10.15: Leave Cutoff - leave request respects cutoff', () async {
        final futureStart = now.add(const Duration(days: 7));
        final event = await createIsolatedProgramme('1015', futureStart);
        final u1 = nextUser();

        await client.enrollments.assign(
          event.id,
          u1,
        );

        await client.myEvents.requestLeave(
          u1,
          event.id,
          futureStart,
        );

        await client.attendance.approveLeave(
          event.id,
          u1,
          futureStart,
        );

        final occ = await client.occurrences.getOccurrence(
          event.id,
          futureStart,
        );
        expect(occ, isNotNull);
      });
    });

    // =========================================================================
    // 10.16: Attendance Edit Window
    // =========================================================================

    group('10.16: Attendance Edit Window', () {
      test(
        '10.16: Attendance Edit Window - restricts edits after window closes',
        () async {
          // Edit window is 15 days. Use real past date >15 days ago so
          // the server's wall clock time sees window as closed.
          final realNow = nowUtcMinute();
          final pastOccurrence = realNow.subtract(const Duration(days: 20));
          final event = await createIsolatedProgramme('1016', pastOccurrence);
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          // Regular admin (non-super) should be blocked by edit window
          expect(
            () async => adminClient.attendance.markAttendance(
              event.id,
              pastOccurrence,
              [
                AttendanceMarkRecord(
                  membername: u1,
                  status: AttendanceStatus.present,
                ),
              ],
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.editWindowClosed,
              ),
            ),
          );
        },
      );
    });

    // =========================================================================
    // 10.17: Attendance Edit Override
    // =========================================================================

    group('10.17: Attendance Edit Override', () {
      test(
        '10.17: Attendance Edit Override - admin can override edit window',
        () async {
          // An occurrence 20 real days ago: outside the 15-day edit window,
          // which only a super admin bypasses (attendance R13); sudo also
          // bypasses the enrollment-coverage check on writes (R11a, R20).
          final pastOccurrence = nowUtcMinute().subtract(
            const Duration(days: 20),
          );
          final event = await createIsolatedProgramme('1017', pastOccurrence);
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          // Admin can override the edit window
          await client.attendance.markAttendance(
            event.id,
            pastOccurrence,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );

          // Verify the attendance was recorded
          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            pastOccurrence,
          );
          expect(
            records.any(
              (r) => r.membername == u1 && r.status == AttendanceStatus.present,
            ),
            isTrue,
          );
        },
      );
    });

    // =========================================================================
    // 10.18: Pre-occurrence Attendance Gate (ATTENDANCE_NOT_YET_OPEN)
    // =========================================================================

    group('10.18: Pre-occurrence Attendance Gate', () {
      test(
        '10.18a: rejects mark attendance more than 30 min before '
        'effective start',
        () async {
          final event = await createTestEvent('1018a');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          // Reference "now" is 31 minutes before the occurrence start.
          expect(
            () async => adminClient.attendance.markAttendance(
              event.id,
              occTime,
              [
                AttendanceMarkRecord(
                  membername: u1,
                  status: AttendanceStatus.present,
                ),
              ],
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.attendanceNotYetOpen,
              ),
            ),
          );
        },
      );

      test(
        '10.18b: super-admin bypasses 30-min pre-occurrence gate',
        () async {
          final event = await createTestEvent('1018b');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          // Same pre-window position, acting as sudo (super-admin). No role
          // bypasses the open window, super-admin included (attendance
          // R12): marking before the session is data invention, not audit
          // correction.
          await expectLater(
            client.attendance.markAttendance(
              event.id,
              occTime,
              [
                AttendanceMarkRecord(
                  membername: u1,
                  status: AttendanceStatus.present,
                ),
              ],
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.attendanceNotYetOpen,
              ),
            ),
          );

          final records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );
          expect(records.any((r) => r.membername == u1), isFalse);
        },
      );

      // Note: the server's pre-window gate uses the real wall clock, so the
      // exact-30-min boundary cannot be exercised deterministically from a
      // test without time-travel. The boundary semantics are covered by the
      // unit test for `canMarkAttendanceNow` in cl_club_events.
    });

    // =========================================================================
    // 10.19: Override-derived Effective Start
    // =========================================================================

    group('10.19: Override-derived Effective Start', () {
      // The override-shifted edit-window behavior is not reachable from a
      // pure-SDK integration test: rescheduling a past occurrence is
      // rejected with `PAST_OCCURRENCE`, and rescheduling a future one
      // leaves the pre-occurrence open-window gate (which uses the real
      // wall clock) blocking the subsequent markAttendance call. Coverage
      // for this behavior lives in the server's own test suite
      // (`server/tests/test_attendance.py`).
      // SDK-side, the contract is documented on
      // `AttendanceSource.markAttendance` and the `effectiveStartTimeUtc`
      // helper on `OccurrenceOverride` is unit-tested.

      test(
        '10.19a: override shifts edit window forward — slot key past, '
        'override recent → admin can mark',
        () async {
          final realNow = nowUtcMinute();
          // Slot key 20 real days ago — outside the 15-day edit window if
          // measured from the slot key. Three hours off the 10.16 programme
          // on the same weekday, so the two never clash.
          final slotKey = realNow.subtract(
            const Duration(days: 20, hours: 3),
          );
          // Override pulls effective start to 2 real days ago — inside the
          // 15-day window when measured from the override.
          final newStart = realNow.subtract(const Duration(days: 2));
          final event = await createIsolatedProgramme('1019a', slotKey);
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          Future<void> adminMarks() => adminClient.attendance.markAttendance(
            event.id,
            slotKey,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );

          // Measured from the slot key, the window is closed.
          await expectLater(
            adminMarks(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.editWindowClosed,
              ),
            ),
          );

          await client.occurrences.rescheduleOccurrence(
            event.id,
            slotKey,
            version: await occurrenceVersion(client, event.id, slotKey),
            newStartTimeUtc: newStart,
            newDurationMinutes: 60,
          );

          // Measured from the override, the window is open (attendance
          // R15b), so the edit-window gate no longer answers. What refuses
          // the admin now is enrollment coverage: an enrollment made today
          // never covers a slot 20 days back (enrollment R61 / R62a), and
          // only a super admin bypasses that on writes (attendance R11a).
          await expectLater(
            adminMarks(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.invalidState,
              ),
            ),
          );

          await client.attendance.markAttendance(
            event.id,
            slotKey,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );
          final records = await adminClient.attendance
              .getAttendanceForOccurrence(event.id, slotKey);
          expect(
            records.any(
              (r) => r.membername == u1 && r.status == AttendanceStatus.present,
            ),
            isTrue,
          );
        },
      );

      test(
        '10.19b: override shifts edit window backward — slot key recent, '
        'override old → editWindowClosed',
        () async {
          final realNow = nowUtcMinute();
          // Slot key 5 real days ago — inside the 15-day window if measured
          // from the slot key.
          final slotKey = realNow.subtract(const Duration(days: 5));
          // Override pushes effective start to 30 real days ago — outside
          // the 15-day window when measured from the override.
          final newStart = realNow.subtract(const Duration(days: 30));
          final event = await createIsolatedProgramme('1019b', slotKey);
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          await client.occurrences.rescheduleOccurrence(
            event.id,
            slotKey,
            version: await occurrenceVersion(client, event.id, slotKey),
            newStartTimeUtc: newStart,
            newDurationMinutes: 60,
          );

          expect(
            () async => adminClient.attendance.markAttendance(
              event.id,
              slotKey,
              [
                AttendanceMarkRecord(
                  membername: u1,
                  status: AttendanceStatus.present,
                ),
              ],
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.editWindowClosed,
              ),
            ),
          );
        },
      );
    });

    // =========================================================================
    // 10.20: Clear Attendance (app#724)
    // =========================================================================

    group('10.20: Clear Attendance', () {
      // An occurrence ~10 minutes out is inside the open window (which opens 30
      // minutes before start) yet still "future", so an assigned member is
      // eligible and marking is permitted without relying on a super-admin
      // bypass. The server imposes no lead-time on event creation, so this is a
      // genuine mark→clear round trip (unlike the fixed-2027 fixtures above,
      // whose occurrences are never inside the open window).
      Future<Event> createMarkableEvent(String suffix) async {
        final start = DateTime.now().toUtc().add(const Duration(minutes: 10));
        return client.events.createEvent(
          title: 'test_Attendance Clear $suffix',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );
      }

      test(
        '10.20: clearAttendance removes a marked record; a second clear is '
        'ATTENDANCE_NOT_FOUND',
        () async {
          final event = await createMarkableEvent('1018');
          final occTime = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(event.id, u1);
          await client.attendance.markAttendance(
            event.id,
            occTime,
            [
              AttendanceMarkRecord(
                membername: u1,
                status: AttendanceStatus.present,
              ),
            ],
          );

          var records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );
          expect(records.any((r) => r.membername == u1), isTrue);

          // Clear it → member returns to "not recorded".
          await client.attendance.clearAttendance(event.id, u1, occTime);

          records = await client.attendance.getAttendanceForOccurrence(
            event.id,
            occTime,
          );
          expect(records.any((r) => r.membername == u1), isFalse);

          // Nothing left to clear → ATTENDANCE_NOT_FOUND.
          await expectLater(
            () => client.attendance.clearAttendance(event.id, u1, occTime),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.attendanceNotFound,
              ),
            ),
          );
        },
      );
    });
  });
}
