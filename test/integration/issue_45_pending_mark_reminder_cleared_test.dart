import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_reminders.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 45: once attendance is marked for a session, its
/// `attendance.pending_mark_reminder` is gone from **every** staff inbox,
/// not only the marker's (club_server#50, notifications R93b).
///
/// A camp has two days that ended in the past, both unmarked, and one ahead.
/// The scheduler's pending-mark scan reminds every admin and coach of both
/// past days. Sudo then marks the first day. Sudo is the marker because a
/// past day can be marked only by a super-admin here: an enrollment made
/// now does not cover a day that has already happened (camps R85), and the
/// API cannot backdate one.
///
/// The pending-mark scan runs on the scheduler's first tick, five minutes
/// after the server starts, and then hourly; no API triggers it. On a fresh
/// stack (`just test-one`) setUpAll waits for that first scan. On a stack
/// that has been up longer, the tests are skipped with the reason.
void main() {
  const testFile = 'issue_45_pending_mark_reminder_cleared_test.dart';

  group('Issue 45: pending-mark reminders once a session is marked', () {
    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient coach;
    final opened = <SecureClient>[];
    const adminName = 'test_i45_admin';
    const coachName = 'test_i45_coach';
    const memberName = 'test_i45_member';
    const password = 'password123';

    late Event camp;
    late DateTime markedDay;
    late DateTime unmarkedDay;

    /// Whether the scan reminded the staff; when not,
    /// [pendingMarkScanSkip] says why.
    var pendingMarksSent = false;

    Future<void> register(String username) => registerAndApprove(
      client: sudo,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      phone: '0000000000',
      dateOfBirthUtc: DateTime.utc(2000),
      gender: Gender.male,
      firstName: username,
    );

    Future<SecureClient> loggedIn(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(c);
      await c.auth.login(username, password);
      expect((await c.auth.getCurrentUser()).username, username);
      return c;
    }

    Future<List<AppNotification>> pendingMarkOf(
      SecureClient staff,
      DateTime day,
    ) => remindersFor(staff, pendingMarkReminder, camp.id, day);

    /// Marks the test skipped, and answers true, when the scan was missed.
    bool scanMissed() {
      if (pendingMarksSent) return false;
      markTestSkipped(pendingMarkScanSkip(45, testFile));
      return true;
    }

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(sudo);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      expect((await sudo.auth.getCurrentUser()).username, sudoUsername);
      await register(adminName);
      await sudo.users.assignRole(adminName, 'admin');
      await register(coachName);
      await sudo.users.assignRole(coachName, 'coach');
      await register(memberName);
      admin = await loggedIn(adminName);
      coach = await loggedIn(coachName);

      // Days ended 45 and 21 hours ago, and one 3 hours ahead, so the camp
      // is still running and the member can be assigned.
      final ahead = nowUtcMinute().add(const Duration(hours: 3));
      markedDay = ahead.subtract(const Duration(days: 2));
      unmarkedDay = ahead.subtract(const Duration(days: 1));
      final venueId = (await sudo.venues.createVenue(
        name: 'test_Venue I45',
      )).id;
      camp = await sudo.events.createEvent(
        title: 'test_I45 camp',
        description: '',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: markedDay,
        endTimeUtc: markedDay.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=3',
      );
      await sudo.enrollments.assign(camp.id, memberName);
      expect(
        await sudo.enrollments.getEnrollmentStatus(camp.id, memberName),
        EnrollmentStatus.assigned,
      );

      final firstScan = await firstPendingMarkScanDeadline(sudo);
      if (firstScan == null) return;
      for (final staff in [sudo, admin, coach]) {
        await waitForReminders(
          staff,
          pendingMarkReminder,
          [(camp.id, markedDay), (camp.id, unmarkedDay)],
          deadline: firstScan,
        );
      }
      pendingMarksSent = true;
    });

    tearDownAll(() async {
      for (final c in opened) {
        try {
          await c.auth.logout();
        } on Exception {
          /* already out */
        }
      }
    });

    group('after sudo marks the first day', () {
      setUpAll(() async {
        if (!pendingMarksSent) return;
        final report = await sudo.attendance.markAttendance(
          camp.id,
          markedDay,
          const [
            AttendanceMarkRecord(
              membername: memberName,
              status: AttendanceStatus.present,
            ),
          ],
        );
        expect(report.marked.map((m) => m.membername), [memberName]);
        final roster = await admin.attendance.getAttendanceForOccurrence(
          camp.id,
          markedDay,
        );
        expect(roster.map((r) => (r.membername, r.status)), [
          (memberName, AttendanceStatus.present),
        ]);
      });

      test("Issue 45: its reminder is gone from the marker's inbox", () async {
        if (scanMissed()) return;
        expect(await pendingMarkOf(sudo, markedDay), isEmpty);
      });

      test(
        "Issue 45: its reminder is gone from another admin's inbox",
        () async {
          if (scanMissed()) return;
          expect(await pendingMarkOf(admin, markedDay), isEmpty);
        },
      );

      test("Issue 45: its reminder is gone from a coach's inbox", () async {
        if (scanMissed()) return;
        expect(await pendingMarkOf(coach, markedDay), isEmpty);
      });

      test('Issue 45: the reminder of the unmarked day stays with every staff '
          'member', () async {
        if (scanMissed()) return;
        for (final staff in [sudo, admin, coach]) {
          expect(await pendingMarkOf(staff, unmarkedDay), hasLength(1));
        }
      });
    });
  });
}
