import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 56 (club_server#72): every schedule or staff write runs the venue,
/// organizer and coach gates for every event type. A clash answers 409
/// `SCHEDULE_CONFLICT`, raised as [ScheduleConflictException] with the full
/// [ConflictReport], and nothing is written. The same call with
/// `acceptConflicts: true` is written.
void main() {
  group('Issue 56: schedule clashes are refused until accepted', () {
    late SecureClient sudo;
    late int rinkA;
    late int rinkB;

    const coachA = 'test_i56_coach_a';
    const coachB = 'test_i56_coach_b';

    // One-offs and camps take a day each, clear of one another. Programmes
    // repeat weekly, so they keep to an hour nothing else here uses.
    var nextDay = 200;
    const programmeHour = 5;

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      expect((await sudo.auth.getCurrentUser()).username, sudoUsername);

      for (final name in [coachA, coachB]) {
        await registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: 'password123',
          phone: '+919000000056',
          dateOfBirthUtc: DateTime.utc(1990),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
        await sudo.users.assignRole(name, 'coach');
      }

      rinkA = (await sudo.venues.createVenue(
        name: 'test_i56_rink_a',
        address: '56 Rink Road',
      )).id;
      rinkB = (await sudo.venues.createVenue(
        name: 'test_i56_rink_b',
        address: '57 Rink Road',
      )).id;
    });

    tearDownAll(() async {
      await sudo.auth.logout();
    });

    Future<Event> oneOff(
      String title,
      DateTime start, {
      required int venueId,
      required String organizer,
      List<String>? coaches,
      bool acceptConflicts = false,
    }) => sudo.events.createEvent(
      title: 'test_i56_$title',
      description: 'issue 56',
      type: EventType.oneOff,
      visibility: Visibility.public,
      venueId: venueId,
      startTimeUtc: start,
      endTimeUtc: start.add(const Duration(hours: 1)),
      organizerName: organizer,
      coachNames: coaches,
      acceptConflicts: acceptConflicts,
    );

    Future<List<String>> titlesOn(DateTime day) async {
      final page = await sudo.events.listEvents(
        fromTimeUtc: day.subtract(const Duration(hours: 12)),
        toTimeUtc: day.add(const Duration(hours: 12)),
        limit: 100,
      );
      return [for (final e in page.items) e.title];
    }

    Matcher conflictWith(int eventId, {required String gate}) =>
        isA<ScheduleConflictException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', SdkErrorCode.scheduleConflict)
            .having(
              (e) => switch (gate) {
                'venue' => e.report.venueConflicts,
                'organizer' => e.report.organizerConflicts,
                _ => e.report.coachConflicts,
              }.map((c) => c.eventId),
              '$gate conflicts',
              contains(eventId),
            );

    test(
      '56.01: a one-off at a booked venue is refused, then accepted',
      () async {
        final start = dayAt(nextDay++, hour: 15);
        final booked = await oneOff(
          'booked',
          start,
          venueId: rinkA,
          organizer: coachA,
        );

        await expectLater(
          oneOff('clash', start, venueId: rinkA, organizer: coachB),
          throwsA(conflictWith(booked.id, gate: 'venue')),
        );
        expect(await titlesOn(start), isNot(contains('test_i56_clash')));

        final accepted = await oneOff(
          'clash',
          start,
          venueId: rinkA,
          organizer: coachB,
          acceptConflicts: true,
        );
        expect((await sudo.events.getEvent(accepted.id)).venueId, rinkA);
        expect(await titlesOn(start), contains('test_i56_clash'));
      },
    );

    test(
      '56.02: the report names the clash with its occurrence pair',
      () async {
        final start = dayAt(nextDay++, hour: 15);
        final booked = await oneOff(
          'pairs',
          start,
          venueId: rinkA,
          organizer: coachA,
        );

        try {
          await oneOff(
            'pairs_clash',
            start.add(const Duration(minutes: 30)),
            venueId: rinkA,
            organizer: coachB,
          );
          fail('expected a ScheduleConflictException');
        } on ScheduleConflictException catch (e) {
          final item = e.report.venueConflicts.single;
          expect(item.eventId, booked.id);
          expect(item.eventTitle, 'test_i56_pairs');
          expect(item.eventType, EventType.oneOff.name);
          final pair = item.occurrences.single;
          expect(pair.otherStartUtc, start);
          expect(pair.targetStartUtc, start.add(const Duration(minutes: 30)));
          expect(e.report.organizerConflicts, isEmpty);
          expect(e.report.coachConflicts, isEmpty);
        }
      },
    );

    test('56.03: a coach-only clash is refused with the coach conflict, '
        'then accepted', () async {
      final start = dayAt(nextDay++, hour: 15);
      final coached = await oneOff(
        'coached',
        start,
        venueId: rinkA,
        organizer: sudoUsername,
        coaches: [coachA],
      );

      try {
        await oneOff(
          'coach_clash',
          start,
          venueId: rinkB,
          organizer: coachB,
          coaches: [coachA],
        );
        fail('expected a ScheduleConflictException');
      } on ScheduleConflictException catch (e) {
        expect(e.report.venueConflicts, isEmpty);
        expect(e.report.organizerConflicts, isEmpty);
        expect(e.report.coachConflicts.single.eventId, coached.id);
      }
      expect(await titlesOn(start), isNot(contains('test_i56_coach_clash')));

      final accepted = await oneOff(
        'coach_clash',
        start,
        venueId: rinkB,
        organizer: coachB,
        coaches: [coachA],
        acceptConflicts: true,
      );
      expect((await sudo.events.getEvent(accepted.id)).coachNames, [coachA]);
    });

    test(
      '56.04: a camp whose organizer is busy is refused, then accepted',
      () async {
        final start = dayAt(nextDay, hour: 15);
        nextDay += 3;
        final busy = await oneOff(
          'organizer_busy',
          start.add(const Duration(days: 1)),
          venueId: rinkA,
          organizer: coachA,
        );

        Future<Event> camp({bool accept = false}) => sudo.events.createEvent(
          title: 'test_i56_camp',
          description: 'issue 56',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: rinkB,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: 'FREQ=DAILY;COUNT=3',
          organizerName: coachA,
          acceptConflicts: accept,
        );

        await expectLater(
          camp(),
          throwsA(conflictWith(busy.id, gate: 'organizer')),
        );
        expect(await titlesOn(start), isNot(contains('test_i56_camp')));

        final accepted = await camp(accept: true);
        expect((await sudo.events.getEvent(accepted.id)).type, EventType.camp);
      },
    );

    test(
      '56.05: adding a busy coach on update is refused, then accepted',
      () async {
        final start = dayAt(nextDay++, hour: 15);
        final coached = await oneOff(
          'coach_busy',
          start,
          venueId: rinkA,
          organizer: sudoUsername,
          coaches: [coachA],
        );
        final other = await oneOff(
          'restaff',
          start,
          venueId: rinkB,
          organizer: coachB,
        );

        await expectLater(
          sudo.events.updateEvent(
            other.id,
            version: other.version,
            coachNames: () => [coachA],
          ),
          throwsA(conflictWith(coached.id, gate: 'coach')),
        );
        final unchanged = await sudo.events.getEvent(other.id);
        expect(unchanged.coachNames ?? const <String>[], isEmpty);
        expect(unchanged.version, other.version);

        await sudo.events.updateEvent(
          other.id,
          version: other.version,
          coachNames: () => [coachA],
          acceptConflicts: true,
        );
        expect((await sudo.events.getEvent(other.id)).coachNames, [coachA]);
      },
    );

    test('56.06: an in-place reschedule onto a clash is refused, then '
        'accepted', () async {
      final start = dayAt(nextDay++, hour: 15);
      final booked = await oneOff(
        'stay',
        start,
        venueId: rinkA,
        organizer: coachA,
      );
      final mover = await oneOff(
        'mover',
        start.subtract(const Duration(hours: 3)),
        venueId: rinkA,
        organizer: coachB,
      );

      await expectLater(
        sudo.events.rescheduleEvent(
          mover.id,
          version: mover.version,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        ),
        throwsA(conflictWith(booked.id, gate: 'venue')),
      );
      expect(
        (await sudo.events.getEvent(mover.id)).startTimeUtc,
        mover.startTimeUtc,
      );

      await sudo.events.rescheduleEvent(
        mover.id,
        version: mover.version,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        acceptConflicts: true,
      );
      expect((await sudo.events.getEvent(mover.id)).startTimeUtc, start);
    });

    test('56.07: reinstating a one-off onto a clash is refused, then '
        'accepted', () async {
      final start = dayAt(nextDay++, hour: 15);
      final dropped = await oneOff(
        'dropped',
        start,
        venueId: rinkA,
        organizer: coachB,
      );
      await sudo.events.drop(
        dropped.id,
        version: await occurrenceVersion(sudo, dropped.id, start),
        reason: 'make room',
      );
      // Its slot is free while it is dropped.
      final taken = await oneOff(
        'taker',
        start,
        venueId: rinkA,
        organizer: coachA,
      );

      await expectLater(
        sudo.events.reinstate(
          dropped.id,
          version: await occurrenceVersion(sudo, dropped.id, start),
        ),
        throwsA(conflictWith(taken.id, gate: 'venue')),
      );
      expect(
        (await sudo.occurrences.getOccurrence(dropped.id, start)).status,
        OccurrenceStatus.cancelled,
      );

      await sudo.events.reinstate(
        dropped.id,
        version: await occurrenceVersion(sudo, dropped.id, start),
        acceptConflicts: true,
      );
      expect(
        (await sudo.occurrences.getOccurrence(dropped.id, start)).status,
        OccurrenceStatus.scheduled,
      );
    });

    test('56.08: moving one occurrence onto a clash is refused, then '
        'accepted', () async {
      final start = dayAt(nextDay, hour: 15);
      nextDay += 2;
      final booked = await oneOff(
        'occ_booked',
        start.add(const Duration(days: 1)),
        venueId: rinkA,
        organizer: coachA,
      );
      final camp = await sudo.events.createEvent(
        title: 'test_i56_occ_camp',
        description: 'issue 56',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: rinkA,
        startTimeUtc: start.subtract(const Duration(hours: 4)),
        endTimeUtc: start.subtract(const Duration(hours: 3)),
        rrule: 'FREQ=DAILY;COUNT=2',
        organizerName: coachB,
      );
      final day2 = start.add(const Duration(days: 1, hours: -4));
      final onto = start.add(const Duration(days: 1));

      await expectLater(
        sudo.occurrences.rescheduleOccurrence(
          camp.id,
          day2,
          version: await occurrenceVersion(sudo, camp.id, day2),
          newStartTimeUtc: onto,
        ),
        throwsA(conflictWith(booked.id, gate: 'venue')),
      );
      final stayed = await sudo.occurrences.getOccurrence(camp.id, day2);
      expect(stayed.actualStartTimeUtc, day2);
      expect(stayed.isRescheduled, isFalse);

      await sudo.occurrences.rescheduleOccurrence(
        camp.id,
        day2,
        version: stayed.version,
        newStartTimeUtc: onto,
        acceptConflicts: true,
      );
      final moved = await sudo.occurrences.getOccurrence(camp.id, day2);
      expect(moved.actualStartTimeUtc, onto);
    });

    test('56.09: a programme split onto a booked venue is refused, then '
        'accepted', () async {
      final start = dayAt(nextDay++, hour: programmeHour);
      Future<Event> programme(String title, int venueId, String organizer) =>
          sudo.events.createEvent(
            title: 'test_i56_$title',
            description: 'issue 56',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
            rrule: weeklyOn(start),
            organizerName: organizer,
          );
      final occupied = await programme('occupied', rinkA, coachA);
      final mover = await programme('split_mover', rinkB, coachB);
      final effective = start.add(const Duration(days: 7));

      await expectLater(
        sudo.events.updateEventForAllFuture(
          mover.id,
          version: mover.version,
          effectiveDateTimeUtc: effective,
          venueId: rinkA,
        ),
        throwsA(conflictWith(occupied.id, gate: 'venue')),
      );
      final kept = await sudo.events.listSchedules(mover.id);
      expect(kept, hasLength(1));
      expect(kept.single.venueId, rinkB);

      await sudo.events.updateEventForAllFuture(
        mover.id,
        version: mover.version,
        effectiveDateTimeUtc: effective,
        venueId: rinkA,
        acceptConflicts: true,
      );
      final split = await sudo.events.listSchedules(mover.id);
      expect(split, hasLength(2));
      expect(split.last.venueId, rinkA);
    });
  });
}
