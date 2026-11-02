import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/occurrence_reminders.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 45: once attendance is marked for a session, its
/// `attendance.pending_mark_reminder` is gone from **every** staff inbox,
/// not only the marker's (club_server#50, notifications R93b).
///
/// Two camps each open with a one-minute session, the member assigned to
/// both before it starts, so an enrollment covers each session: the scan
/// reminds staff only of such a session (club_server#148), and the API
/// cannot backdate an enrollment. A camp's days are a day apart, so the two
/// sessions are on two camps. Once both have ended, unmarked, the
/// scheduler's pending-mark scan reminds every admin and coach of both.
/// Sudo then marks one of them.
///
/// The pending-mark scan runs on the scheduler's first tick, five minutes
/// after the server starts, and then hourly; no API triggers it. On a fresh
/// stack (`just test-one`) the sessions end before that first scan and
/// setUpAll waits for it. On a stack that has been up longer, the tests are
/// skipped with the reason.
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

    late Event markedCamp;
    late Event unmarkedCamp;

    /// When both camps' first sessions start.
    late DateTime session;

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
      Event camp,
    ) => remindersFor(staff, pendingMarkReminder, camp.id, session);

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

      // Each camp's first day is a short session that starts once the
      // member is assigned and ends before the first scan; the second day
      // is tomorrow. Sudo organizes both at the same time.
      final pending = await pendingMarkSession(sudo);
      session = pending.start;
      Future<Event> camp(String name) async {
        final venueId = (await sudo.venues.createVenue(
          name: 'test_Venue I45 $name',
        )).id;
        final event = await sudo.events.createEvent(
          title: 'test_I45 $name camp',
          description: '',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: pending.start,
          endTimeUtc: pending.end,
          rrule: 'FREQ=DAILY;COUNT=2',
          acceptConflicts: true,
        );
        await sudo.enrollments.assign(event.id, memberName);
        expect(
          await sudo.enrollments.getEnrollmentStatus(event.id, memberName),
          EnrollmentStatus.assigned,
        );
        return event;
      }

      markedCamp = await camp('marked');
      unmarkedCamp = await camp('unmarked');
      assignedBefore(session);

      final firstScan = pending.scanDeadline;
      if (firstScan == null) return;
      for (final staff in [sudo, admin, coach]) {
        await waitForReminders(staff, pendingMarkReminder, [
          (markedCamp.id, session),
          (unmarkedCamp.id, session),
        ], deadline: firstScan);
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

    group('after sudo marks one session', () {
      setUpAll(() async {
        if (!pendingMarksSent) return;
        final report = await sudo.attendance.markAttendance(
          markedCamp.id,
          session,
          const [
            AttendanceMarkRecord(
              membername: memberName,
              status: AttendanceStatus.present,
            ),
          ],
        );
        expect(report.marked.map((m) => m.membername), [memberName]);
        final roster = await admin.attendance.getAttendanceForOccurrence(
          markedCamp.id,
          session,
        );
        expect(roster.map((r) => (r.membername, r.status)), [
          (memberName, AttendanceStatus.present),
        ]);
      });

      test("Issue 45: its reminder is gone from the marker's inbox", () async {
        if (scanMissed()) return;
        expect(await pendingMarkOf(sudo, markedCamp), isEmpty);
      });

      test(
        "Issue 45: its reminder is gone from another admin's inbox",
        () async {
          if (scanMissed()) return;
          expect(await pendingMarkOf(admin, markedCamp), isEmpty);
        },
      );

      test("Issue 45: its reminder is gone from a coach's inbox", () async {
        if (scanMissed()) return;
        expect(await pendingMarkOf(coach, markedCamp), isEmpty);
      });

      test('Issue 45: the reminder of the unmarked session stays with every '
          'staff member', () async {
        if (scanMissed()) return;
        for (final staff in [sudo, admin, coach]) {
          expect(await pendingMarkOf(staff, unmarkedCamp), hasLength(1));
        }
      });
    });
  });
}
