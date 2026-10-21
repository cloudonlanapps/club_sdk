import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 46: a camp already cancelled can be cancelled again from an
/// **earlier** day, which moves its cutoff earlier (club_server#51, camps
/// R5e). A second cancel at or after the current cutoff is still refused
/// with 400 `EVENT_ALREADY_CANCELLED`, and the cutoff stays where it was.
///
/// Every cancel here is made by a regular admin, not the super-admin, so no
/// bypass applies.
void main() {
  group('Issue 46: cancelling a cancelled camp again', () {
    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient member;
    final opened = <SecureClient>[];
    late int venueId;
    const adminName = 'test_i46_admin';
    const memberName = 'test_i46_member';
    const password = 'password123';
    const campDays = 7;
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

    Future<SecureClient> loggedIn(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(c);
      await c.auth.login(username, password);
      expect((await c.auth.getCurrentUser()).username, username);
      return c;
    }

    /// The camp's day [d] (1-based).
    DateTime day(Event camp, int d) =>
        camp.startTimeUtc.add(Duration(days: d - 1));

    /// A seven-day camp with the member assigned, cancelled from day
    /// [cancelledFrom] by the admin.
    Future<Event> cancelledCamp(int cancelledFrom) async {
      n += 1;
      // Each camp gets its own week, so none of them clash.
      final start = dayAt(2 + campDays * n);
      final camp = await admin.events.createEvent(
        title: 'test_I46 camp $n',
        description: '',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=$campDays',
      );
      await admin.enrollments.assign(camp.id, memberName);
      expect(
        await admin.enrollments.getEnrollmentStatus(camp.id, memberName),
        EnrollmentStatus.assigned,
      );
      final cancelled = await admin.events.cancelSeries(
        camp.id,
        version: (await admin.events.getEvent(camp.id)).version,
        reason: 'ice',
        effectiveDateTimeUtc: day(camp, cancelledFrom),
      );
      expect(cancelled.untilTimeUtc, day(camp, cancelledFrom));
      return cancelled;
    }

    /// Each day's status, in order.
    Future<List<OccurrenceStatus>> adminStatuses(Event camp) async => [
      for (var d = 1; d <= campDays; d++)
        (await admin.occurrences.getOccurrence(camp.id, day(camp, d))).status,
    ];

    Future<List<OccurrenceStatus>> memberStatuses(Event camp) async => [
      for (var d = 1; d <= campDays; d++)
        (await member.myEvents.getMyOccurrence(
          memberName,
          camp.id,
          day(camp, d),
        )).status,
    ];

    /// The days before [cutoffDay] scheduled, every day from it cancelled.
    List<OccurrenceStatus> cutAt(int cutoffDay) => [
      for (var d = 1; d < cutoffDay; d++) OccurrenceStatus.scheduled,
      for (var d = cutoffDay; d <= campDays; d++) OccurrenceStatus.cancelled,
    ];

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
      venueId = (await sudo.venues.createVenue(name: 'test_Venue I46')).id;
      await register(adminName);
      await sudo.users.assignRole(adminName, 'admin');
      await register(memberName);
      admin = await loggedIn(adminName);
      member = await loggedIn(memberName);
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

    group('from day 5, then from day 2', () {
      late Event camp;

      setUpAll(() async {
        final first = await cancelledCamp(5);
        expect(await adminStatuses(first), cutAt(5));
        camp = await admin.events.cancelSeries(
          first.id,
          version: first.version,
          reason: 'ice again',
          effectiveDateTimeUtc: day(first, 2),
        );
      });

      test('Issue 46: the cutoff moves to day 2', () async {
        expect(camp.untilTimeUtc, day(camp, 2));
        final read = await admin.events.getEvent(camp.id);
        expect(read.untilTimeUtc, day(camp, 2));
      });

      test(
        "Issue 46: days 2 to 4 read as cancelled in the admin's view",
        () async {
          expect(await adminStatuses(camp), cutAt(2));
        },
      );

      test(
        "Issue 46: days 2 to 4 read as cancelled in the member's view",
        () async {
          expect(await memberStatuses(camp), cutAt(2));
        },
      );
    });

    test('Issue 46: a second cancel from a day after the cutoff is refused '
        'with EVENT_ALREADY_CANCELLED, and the cutoff stays', () async {
      final camp = await cancelledCamp(3);

      await expectLater(
        admin.events.cancelSeries(
          camp.id,
          version: camp.version,
          reason: 'later',
          effectiveDateTimeUtc: day(camp, 5),
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventAlreadyCancelled,
              ),
        ),
      );

      final read = await admin.events.getEvent(camp.id);
      expect(read.untilTimeUtc, day(camp, 3));
      expect(await adminStatuses(camp), cutAt(3));
    });

    test('Issue 46: a second cancel from the cutoff day itself is refused '
        'with EVENT_ALREADY_CANCELLED', () async {
      final camp = await cancelledCamp(3);

      await expectLater(
        admin.events.cancelSeries(
          camp.id,
          version: camp.version,
          reason: 'same day',
          effectiveDateTimeUtc: day(camp, 3),
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventAlreadyCancelled,
              ),
        ),
      );

      final read = await admin.events.getEvent(camp.id);
      expect(read.untilTimeUtc, day(camp, 3));
    });
  });
}
