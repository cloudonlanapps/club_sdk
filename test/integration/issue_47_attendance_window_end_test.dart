import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 47: the attendance edit window closes 15 days after an
/// occurrence's **effective end**, not its start (club_server#52,
/// attendance R13), and `canMarkAttendanceNow` agrees.
///
/// Each session here is a one-off created in the past, organized by a coach
/// (not a super-admin, who has no upper bound). The only sessions where the
/// two readings differ started more than 15 days ago and ended less than 15
/// days ago, so they run for hours.
///
/// The member cannot be enrolled in them: an enrollment is stamped with the
/// time it is made, so it never covers a session that has already happened
/// (camps R84–R85), and an ended event refuses new enrollments. A coach's
/// mark inside the window is therefore refused for the missing enrollment
/// (422 `INVALID_STATE`) once the window check has let it through; the
/// accepted mark the issue describes cannot be produced through the API.
void main() {
  group('Issue 47: the attendance edit window ends 15 days after the end', () {
    late SecureClient sudo;
    late SecureClient coach;
    late UserPrivate coachUser;
    final opened = <SecureClient>[];
    late int venueId;
    const coachName = 'test_i47_coach';
    const memberName = 'test_i47_member';
    const password = 'password123';
    var n = 0;

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

    /// A one-off organized by the coach that started [ago] before now and
    /// ran for [length].
    Future<Event> pastSession(Duration ago, Duration length) async {
      n += 1;
      final start = nowUtcMinute().subtract(ago);
      final event = await sudo.events.createEvent(
        title: 'test_I47 session $n',
        description: '',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        organizerName: coachName,
        startTimeUtc: start,
        endTimeUtc: start.add(length),
      );
      expect(event.organizerName, coachName);
      expect(event.startTimeUtc, start);
      return event;
    }

    Future<AttendanceMarkReport> coachMarks(Event e) =>
        coach.attendance.markAttendance(e.id, e.startTimeUtc, const [
          AttendanceMarkRecord(
            membername: memberName,
            status: AttendanceStatus.present,
          ),
        ]);

    Future<List<AttendanceRecord>> roster(Event e) =>
        sudo.attendance.getAttendanceForOccurrence(e.id, e.startTimeUtc);

    bool gateFor(Event e) => canMarkAttendanceNow(
      actingUser: coachUser,
      effectiveStartTimeUtc: e.startTimeUtc,
      effectiveEndTimeUtc: e.endTimeUtc,
    );

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
      venueId = (await sudo.venues.createVenue(name: 'test_Venue I47')).id;
      await register(coachName);
      await sudo.users.assignRole(coachName, 'coach');
      await register(memberName);
      coach = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(coach);
      await coach.auth.login(coachName, password);
      coachUser = await coach.auth.getCurrentUser();
      expect(coachUser.username, coachName);
      expect(coachUser.isSuperAdmin, isFalse);
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

    group('a session that started 15 days 2 hours ago and ran 6 hours', () {
      late Event session;

      setUpAll(() async {
        // start + 15 days was 2 hours ago; end + 15 days is 4 hours away.
        session = await pastSession(
          const Duration(days: 15, hours: 2),
          const Duration(hours: 6),
        );
      });

      test(
        'Issue 47: a coach marks it, and the roster shows the mark',
        () async {
          final report = await coachMarks(session);
          expect(report.marked.map((m) => m.membername), [memberName]);
          expect((await roster(session)).map((r) => (r.membername, r.status)), [
            (memberName, AttendanceStatus.present),
          ]);
        },
        skip:
            'club_sdk#47 — no enrollment can cover a session that started '
            'over 15 days ago: the server stamps enrolled_at with the time '
            'the enrollment is made, refuses enrolling in an ended event, and '
            'requires enrolled_at <= the occurrence for a past one (camps '
            'R85), so a non-super-admin mark is refused with INVALID_STATE. '
            "Only the server's own tests, which write the database, reach "
            'it.',
      );

      test(
        'Issue 47: the edit window lets the coach through; only the missing '
        'enrollment refuses the mark',
        () async {
          await expectLater(
            coachMarks(session),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'statusCode', 422)
                  .having((e) => e.code, 'code', SdkErrorCode.invalidState),
            ),
          );
          expect(await roster(session), isEmpty);
        },
      );

      test('Issue 47: canMarkAttendanceNow offers the mark', () {
        expect(gateFor(session), isTrue);
      });
    });

    group('a session whose end + 15 days was an hour ago', () {
      late Event session;

      setUpAll(() async {
        session = await pastSession(
          const Duration(days: 15, hours: 4),
          const Duration(hours: 3),
        );
      });

      test(
        "Issue 47: the coach's mark is refused with EDIT_WINDOW_CLOSED, and "
        'nothing is written',
        () async {
          await expectLater(
            coachMarks(session),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'statusCode', 422)
                  .having((e) => e.code, 'code', SdkErrorCode.editWindowClosed),
            ),
          );
          expect(await roster(session), isEmpty);
        },
      );

      test('Issue 47: canMarkAttendanceNow does not offer the mark', () {
        expect(gateFor(session), isFalse);
      });
    });
  });
}
