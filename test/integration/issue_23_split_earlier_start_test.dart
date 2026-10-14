import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

const _weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

String _weeklyOn(DateTime start) =>
    'FREQ=WEEKLY;BYDAY=${_weekdays[start.weekday - 1]}';

/// Issue 23: a split that moves the start earlier keeps that day's
/// session (club_server#40, programme R24e), and a split at the current
/// schedule's first occurrence rewrites that schedule in place
/// (club_server#42, programme R26a).
void main() {
  group('Issue 23: a split with an earlier start', () {
    late SecureClient client;
    var seq = 0;
    final now = DateTime.now().toUtc();
    // Eight days ahead, so no weekly test programme shares a weekday with
    // the one that starts today; whole hours, so starts sit on slot
    // boundaries.
    final anchor = DateTime.utc(
      now.year,
      now.month,
      now.day,
      10,
    ).add(const Duration(days: 8));

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    /// A weekly programme on its own venue. Every one is organized by sudo,
    /// and programmes clash on organizer, so callers keep their hours apart.
    Future<Event> programme(String title, DateTime start) async {
      final venue = await client.venues.createVenue(
        name: 'test_Venue I23 ${++seq}',
      );
      return client.events.createEvent(
        title: title,
        description: '',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: _weeklyOn(start),
      );
    }

    Future<List<DateTime>> slots(Event event, DateTime around) async {
      final listed = await client.occurrences.listOccurrences(
        fromTimeUtc: around.subtract(const Duration(days: 1)),
        toTimeUtc: around.add(const Duration(days: 1)),
        eventType: EventType.programme,
      );
      return [
        for (final o in listed)
          if (o.eventId == event.id) o.originalStartTimeUtc,
      ];
    }

    test('Issue 23: an earlier start keeps the cutoff day session', () async {
      final event = await programme('test_I23 earlier', anchor);
      final cutoff = anchor.add(const Duration(days: 7));
      final earlier = cutoff.subtract(const Duration(hours: 1));

      await client.events.updateEventForAllFuture(
        event.id,
        version: event.version,
        effectiveDateTimeUtc: cutoff,
        startTimeUtc: earlier,
        endTimeUtc: earlier.add(const Duration(hours: 1)),
      );

      final schedules = await client.events.listSchedules(event.id);
      expect(schedules, hasLength(2));
      expect(schedules.first.effectiveUntilUtc, earlier);
      expect(schedules.last.effectiveFromUtc, earlier);
      final around = await slots(event, cutoff);
      expect(around, contains(earlier));
      expect(around, isNot(contains(cutoff)));
    });

    test(
      'Issue 23: a split at an unstarted programme first occurrence '
      'rewrites its one schedule',
      () async {
        final start = anchor.add(const Duration(hours: 4));
        final event = await programme('test_I23 unstarted', start);
        final earlier = start.subtract(const Duration(hours: 1));

        await client.events.updateEventForAllFuture(
          event.id,
          version: event.version,
          effectiveDateTimeUtc: start,
          startTimeUtc: earlier,
          endTimeUtc: earlier.add(const Duration(hours: 1)),
        );

        final schedules = await client.events.listSchedules(event.id);
        expect(schedules, hasLength(1));
        expect(schedules.single.effectiveFromUtc, earlier);
        expect(schedules.single.startTimeUtc, earlier);
        final around = await slots(event, start);
        expect(around, contains(earlier));
        expect(around, isNot(contains(start)));
      },
    );

    test(
      'Issue 23: an earlier start inside the 30-minute lead is refused',
      () async {
        final soon = DateTime.utc(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        ).add(const Duration(minutes: 45));
        final event = await programme('test_I23 too soon', soon);

        await expectLater(
          client.events.updateEventForAllFuture(
            event.id,
            version: event.version,
            effectiveDateTimeUtc: soon,
            startTimeUtc: soon.subtract(const Duration(hours: 1)),
            endTimeUtc: soon,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.cutoffTooSoon,
            ),
          ),
        );
        final schedules = await client.events.listSchedules(event.id);
        expect(schedules.single.startTimeUtc, soon);
      },
    );
  });
}
