import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 98: the staff occurrence list carries each session's attendance
/// counts (club_server#142).
///
/// `attendanceExpected` is the members whose enrollment covers the
/// occurrence; `attendanceMarked` is how many of them have a recorded
/// status. A single occurrence's response carries neither.
void main() {
  group('Issue 98: occurrence attendance counts', () {
    late SecureClient admin;
    late Event camp;
    late DateTime start;
    const members = ['test_i98_alice', 'test_i98_bob'];

    Future<Occurrence> listed() async {
      final items = await admin.occurrences.listOccurrences(
        fromTimeUtc: start.subtract(const Duration(minutes: 1)),
        toTimeUtc: start.add(const Duration(minutes: 1)),
      );
      return items.singleWhere(
        (o) => o.eventId == camp.id && o.originalStartTimeUtc == start,
      );
    }

    Future<void> markOne(String member, AttendanceStatus status) async {
      final report = await admin.attendance.markAttendance(camp.id, start, [
        AttendanceMarkRecord(membername: member, status: status),
      ]);
      expect(report.refused, isEmpty);
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      for (final name in members) {
        await registerAndApprove(
          client: admin,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@test.com',
          password: 'password123',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Member',
        );
      }
      final venue = await admin.venues.createVenue(name: 'test_Venue I98');
      // Soon enough that attendance can be marked, yet still ahead, so an
      // assigned member's enrollment covers it.
      start = nowUtcMinute().add(const Duration(minutes: 10));
      camp = await admin.events.createEvent(
        title: 'test_I98 camp',
        description: '',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=2',
      );
      await admin.enrollments.assignBulk(camp.id, members);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    test('Issue 98: nothing marked counts every covered member, none '
        'marked', () async {
      final occ = await listed();
      expect(occ.attendanceExpected, 2);
      expect(occ.attendanceMarked, 0);
    });

    test('Issue 98: marking one member counts one marked', () async {
      await markOne(members[0], AttendanceStatus.present);

      final occ = await listed();
      expect(occ.attendanceExpected, 2);
      expect(occ.attendanceMarked, 1);
    });

    test('Issue 98: marking every member counts all marked', () async {
      await markOne(members[1], AttendanceStatus.absent);

      final occ = await listed();
      expect(occ.attendanceExpected, 2);
      expect(occ.attendanceMarked, 2);
    });

    test('Issue 98: a single occurrence carries no counts', () async {
      final occ = await admin.occurrences.getOccurrence(camp.id, start);
      expect(occ.eventId, camp.id);
      expect(occ.attendanceExpected, isNull);
      expect(occ.attendanceMarked, isNull);
    });
  });
}
