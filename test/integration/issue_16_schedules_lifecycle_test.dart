import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

const _weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

/// A programme rule anchored on [start]'s weekday, the only shape the server
/// accepts (`FREQ=WEEKLY;BYDAY=…`, club_server#384).
String weeklyOn(DateTime start) =>
    'FREQ=WEEKLY;BYDAY=${_weekdays[start.weekday - 1]}';

/// Issue 16: the schedule model and the per-type lifecycle verbs
/// (club_server#384 / #395).
void main() {
  group('Issue 16: schedules and lifecycle verbs', () {
    late SecureClient client;
    late int venueId;
    var venueSeq = 0;
    // Whole minutes: the server expands occurrence slots on whole seconds,
    // so a start carrying milliseconds is never "on a boundary".
    final now = DateTime.now().toUtc();
    final soonStart = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 10));
    final anchor = DateTime.utc(
      now.year,
      now.month,
      now.day,
      10,
    ).add(const Duration(days: 7));

    setUpAll(() async {
      client = await createTestClient();
      await client.auth.login(sudoUsername, sudoPassword);
      final venue = await client.venues.createVenue(name: 'test_Venue I16');
      venueId = venue.id;
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    /// Programmes clash with each other on venue and on organizer (409),
    /// and every test programme is organized by sudo, so each takes its own
    /// day and venue.
    Future<Event> programme(
      String title, {
      DateTime? start,
      String? organizerName,
    }) async {
      final s = start ?? anchor.add(Duration(hours: 2 * venueSeq));
      final venue = await client.venues.createVenue(
        name: 'test_Venue I16 ${++venueSeq}',
      );
      return client.events.createEvent(
        title: title,
        description: '',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: s,
        endTimeUtc: s.add(const Duration(hours: 1)),
        rrule: weeklyOn(s),
        organizerName: organizerName,
      );
    }

    Future<Event> oneOff(String title, {DateTime? start}) {
      final s = start ?? anchor;
      return client.events.createEvent(
        title: title,
        description: '',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: s,
        endTimeUtc: s.add(const Duration(hours: 1)),
      );
    }

    test(
      'Issue 16: a new event has one schedule and no chain fields',
      () async {
        final event = await programme('test_I16 one schedule');
        final schedules = await client.events.listSchedules(event.id);
        expect(schedules, hasLength(1));
        final s = schedules.single;
        expect(s.eventId, event.id);
        expect(s.isCurrent, isTrue);
        expect(s.rrule, weeklyOn(event.startTimeUtc));
        expect(s.startTimeUtc, event.startTimeUtc);
        expect(s.venueId, event.venueId);
        expect(event.toMap().containsKey('continuedAsEventId'), isFalse);
      },
    );

    test('Issue 16: a split keeps the id and adds a schedule', () async {
      final event = await programme('test_I16 split');
      final cutoff = event.startTimeUtc.add(const Duration(days: 14));
      final split = await client.events.updateEventForAllFuture(
        event.id,
        version: event.version,
        effectiveDateTimeUtc: cutoff,
        startTimeUtc: cutoff.add(const Duration(hours: 2)),
        endTimeUtc: cutoff.add(const Duration(hours: 3)),
        coachNames: () => ['test_coach_1'],
      );
      expect(split.id, event.id);
      expect(split.version, greaterThan(event.version));
      expect(split.coachNames, ['test_coach_1']);

      final schedules = await client.events.listSchedules(event.id);
      expect(schedules, hasLength(2));
      expect(schedules.first.effectiveUntilUtc, cutoff);
      expect(schedules.first.isCurrent, isFalse);
      expect(schedules.last.isCurrent, isTrue);
      expect(schedules.last.effectiveFromUtc, cutoff);
      expect(schedules.last.coachNames, ['test_coach_1']);
    });

    test(
      'Issue 16: a split off a session boundary or too soon is refused',
      () async {
        final event = await programme('test_I16 split guards');
        await expectLater(
          client.events.updateEventForAllFuture(
            event.id,
            version: event.version,
            effectiveDateTimeUtc: event.startTimeUtc.add(
              const Duration(days: 1),
            ),
            venueId: venueId,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.effectiveTimeNotSessionBoundary,
            ),
          ),
        );
        // Another organizer, so it cannot clash with the sudo-run programmes.
        final soon = await programme(
          'test_I16 split soon',
          start: soonStart,
          organizerName: 'test_coach_2',
        );
        await expectLater(
          client.events.updateEventForAllFuture(
            soon.id,
            version: soon.version,
            effectiveDateTimeUtc: soon.startTimeUtc,
            venueId: venueId,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.cutoffTooSoon,
            ),
          ),
        );
      },
    );

    test('Issue 16: correction takes eligibility, not coaches', () async {
      final event = await programme('test_I16 correction');
      final corrected = await client.events.correctionOnEvent(
        event.id,
        version: event.version,
        title: 'test_I16 corrected',
        gender: () => Gender.female,
        isFeatured: true,
      );
      expect(corrected.id, event.id);
      expect(corrected.title, 'test_I16 corrected');
      expect(corrected.gender, Gender.female);
      expect(corrected.isFeatured, isTrue);
    });

    test(
      'Issue 16: terminate, extend and extend-indefinitely a programme',
      () async {
        final event = await programme('test_I16 terminate');
        final cutoff = event.startTimeUtc.add(const Duration(days: 21));
        final terminated = await client.events.terminate(
          event.id,
          reason: 'season over',
          cutoffTimeUtc: cutoff,
        );
        expect(terminated.id, event.id);
        expect(terminated.untilTimeUtc, cutoff);
        expect(terminated.status, EventStatus.cancelled);
        // Still running until the cutoff.
        expect(isEventSeriesCancelled(terminated), isFalse);
        expect(isOccurrenceCancelled(terminated, cutoff), isTrue);
        expect(
          isOccurrenceCancelled(
            terminated,
            event.startTimeUtc.add(const Duration(days: 7)),
          ),
          isFalse,
        );

        final later = cutoff.add(const Duration(days: 7));
        final extended = await client.events.extend(
          event.id,
          cutoffTimeUtc: later,
          reason: 'one more week',
        );
        expect(extended.untilTimeUtc, later);

        final open = await client.events.extendIndefinitely(event.id);
        expect(open.untilTimeUtc, isNull);
        expect(open.status, EventStatus.active);
      },
    );

    test('Issue 16: cancel is refused on a programme and a one-off', () async {
      final p = await programme('test_I16 cancel programme');
      await expectLater(
        client.events.cancelSeries(
          p.id,
          reason: 'x',
          effectiveDateTimeUtc: p.startTimeUtc.add(const Duration(days: 7)),
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidEventType,
          ),
        ),
      );
      final o = await oneOff('test_I16 cancel one-off');
      await expectLater(
        client.events.cancelSeries(
          o.id,
          reason: 'x',
          effectiveDateTimeUtc: anchor,
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidState,
          ),
        ),
      );
    });

    test('Issue 16: drop and reinstate a one-off', () async {
      final event = await oneOff('test_I16 drop');
      final dropped = await client.events.drop(event.id, reason: 'no ice');
      expect(dropped.id, event.id);
      // A drop cancels the single occurrence; the event keeps no cutoff.
      expect(dropped.untilTimeUtc, isNull);
      final occ = await client.occurrences.getOccurrence(event.id, anchor);
      expect(occ.status, OccurrenceStatus.cancelled);
      expect(
        isOccurrenceCancelled(dropped, anchor, overrideStatus: occ.status),
        isTrue,
      );

      await expectLater(
        client.events.drop(event.id, reason: 'again'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.cancelledOccurrence,
          ),
        ),
      );

      final back = await client.events.reinstate(event.id);
      expect(back.id, event.id);
      final restored = await client.occurrences.getOccurrence(event.id, anchor);
      expect(restored.status, OccurrenceStatus.scheduled);
      final schedules = await client.events.listSchedules(event.id);
      expect(schedules, hasLength(1));
    });

    test('Issue 16: rule shape is enforced per type', () async {
      await expectLater(
        client.events.createEvent(
          title: 'test_I16 bad programme rule',
          description: '',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: anchor,
          endTimeUtc: anchor.add(const Duration(hours: 1)),
          rrule: 'FREQ=WEEKLY;COUNT=4',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidRruleForProgramme,
          ),
        ),
      );
      await expectLater(
        client.events.createEvent(
          title: 'test_I16 one-off with rule',
          description: '',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: anchor,
          endTimeUtc: anchor.add(const Duration(hours: 1)),
          rrule: 'FREQ=DAILY;COUNT=2',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidRruleForOneoff,
          ),
        ),
      );
    });

    test('Issue 16: a camp beyond the 52-week horizon is refused', () async {
      final far = anchor.add(const Duration(days: 400));
      await expectLater(
        client.events.createEvent(
          title: 'test_I16 far camp',
          description: '',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: far,
          endTimeUtc: far.add(const Duration(hours: 1)),
          rrule: 'FREQ=DAILY;COUNT=3',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.beyondSchedulingHorizon,
          ),
        ),
      );
    });

    test('Issue 16: check-conflict accepts a programme and reports', () async {
      final existing = await programme('test_I16 conflict base');
      final report = await client.events.checkConflict(
        type: EventType.programme,
        venueId: existing.venueId,
        startTimeUtc: existing.startTimeUtc,
        endTimeUtc: existing.endTimeUtc,
        rrule: weeklyOn(existing.startTimeUtc),
      );
      expect(report, isA<ConflictReport>());
      expect(
        report.venueConflicts.map((c) => c.eventId),
        contains(existing.id),
      );
    });

    test(
      'Issue 16: an enrolled member reads the schedules via myevents',
      () async {
        // A one-off: credit never applies to it, so assignment succeeds on
        // a stack with the credit system on as well as off.
        final event = await oneOff('test_I16 my schedules');
        await client.enrollments.assign(event.id, 'test_alice');
        final alice = await createRemoteSecureClient(baseUrl: baseUrl);
        await alice.auth.login('test_alice', 'password123');
        final schedules = await alice.myEvents.listMyEventSchedules(
          'test_alice',
          event.id,
        );
        expect(schedules, hasLength(1));
        expect(schedules.single.eventId, event.id);
        expect(schedules.single.rrule, isNull);
        await alice.auth.logout();
      },
    );
  });
}
