import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 3: a timetable is corrected in place, at any time, with no split
/// and no cutoff (club_server#423).
///
/// A programme's goes through `correctionOnEvent` — the latest schedule, or
/// the one `scheduleId` names; a camp's or one-off's goes through
/// `updateEvent`. Periods must sum to the occurrence length.
void main() {
  group('Issue 3: timetable correction', () {
    late SecureClient admin;
    late SecureClient member;
    late int venueId;
    final opened = <SecureClient>[];
    const memberName = 'test_i3_member';
    const memberPassword = 'password123';
    var n = 0;

    // Every event here runs an hour a day: these split it, the bad one
    // doesn't sum to it.
    const warmUpAndDrills = [
      EventSession(name: 'Warm-up', periodMinutes: 15),
      EventSession(name: 'Drills', periodMinutes: 45),
    ];
    const halves = [
      EventSession(name: 'First', periodMinutes: 30),
      EventSession(name: 'Second', periodMinutes: 30),
    ];
    const tooShort = [EventSession(name: 'Only', periodMinutes: 20)];

    Future<Event> create(
      EventType type,
      DateTime start, {
      String? rrule,
    }) async {
      n += 1;
      return admin.events.createEvent(
        title: 'test_I3 ${type.name} $n',
        description: '',
        type: type,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: rrule,
      );
    }

    /// A weekly programme whose first session was a week ago. Each gets its
    /// own hour: two programmes in the same slot clash, and that blocks.
    var programmeHour = 0;
    Future<Event> startedProgramme() {
      programmeHour += 1;
      final start = dayAt(-7, hour: programmeHour);
      return create(EventType.programme, start, rrule: weeklyOn(start));
    }

    Future<List<EventSchedule>> schedulesOf(int eventId) =>
        admin.events.listSchedules(eventId);

    Matcher serverError(int status, [String? code]) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'status', status)
          .having((e) => e.code, 'code', code ?? anything),
    );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(admin);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      venueId = (await admin.venues.createVenue(name: 'test_Venue I3')).id;
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: memberName,
        email: '$memberName@test.com',
        password: memberPassword,
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
        firstName: 'Member',
      );
      member = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(member);
      await member.auth.login(memberName, memberPassword);
      expect((await member.auth.getCurrentUser()).username, memberName);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
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

    group('programme (correctionOnEvent)', () {
      test('corrects the latest schedule in place after the programme has '
          'started', () async {
        final event = await startedProgramme();
        final before = await schedulesOf(event.id);
        expect(before, hasLength(1));

        final corrected = await admin.events.correctionOnEvent(
          event.id,
          version: event.version,
          sessions: () => warmUpAndDrills,
        );
        expect(corrected.id, event.id);

        final after = await schedulesOf(event.id);
        expect(after, hasLength(1), reason: 'a correction is not a split');
        expect(after.single.id, before.single.id);
        expect(after.single.sessions, warmUpAndDrills);
        expect(after.single.effectiveUntilUtc, isNull);
      });

      test('corrects only the schedule scheduleId names', () async {
        final event = await startedProgramme();
        final split = await admin.events.updateEventForAllFuture(
          event.id,
          version: event.version,
          effectiveDateTimeUtc: event.startTimeUtc.add(
            const Duration(days: 14),
          ),
          sessions: () => halves,
        );
        final schedules = await schedulesOf(event.id);
        expect(schedules, hasLength(2));
        final first = schedules.first;
        final latest = schedules.last;
        expect(latest.sessions, halves);

        await admin.events.correctionOnEvent(
          event.id,
          version: split.version,
          sessions: () => warmUpAndDrills,
          scheduleId: first.id,
        );

        final after = await schedulesOf(event.id);
        expect(after, hasLength(2));
        expect(after.first.id, first.id);
        expect(after.first.sessions, warmUpAndDrills);
        expect(after.last.sessions, halves, reason: 'latest left alone');
      });

      test(
        'without scheduleId, only the latest schedule is corrected',
        () async {
          final event = await startedProgramme();
          final split = await admin.events.updateEventForAllFuture(
            event.id,
            version: event.version,
            effectiveDateTimeUtc: event.startTimeUtc.add(
              const Duration(days: 14),
            ),
            sessions: () => halves,
          );

          await admin.events.correctionOnEvent(
            event.id,
            version: split.version,
            sessions: () => warmUpAndDrills,
          );

          final after = await schedulesOf(event.id);
          expect(after, hasLength(2));
          expect(after.first.sessions, isNull, reason: 'earlier left alone');
          expect(after.last.sessions, warmUpAndDrills);
        },
      );

      test('a sessions getter returning null clears the timetable', () async {
        final event = await startedProgramme();
        final withTimetable = await admin.events.correctionOnEvent(
          event.id,
          version: event.version,
          sessions: () => halves,
        );
        expect((await schedulesOf(event.id)).single.sessions, halves);

        await admin.events.correctionOnEvent(
          event.id,
          version: withTimetable.version,
          sessions: () => null,
        );
        expect((await schedulesOf(event.id)).single.sessions, isNull);
      });

      test('periods that do not sum to the occurrence length are refused '
          'with INVALID_SESSIONS_TOTAL, and nothing is written', () async {
        final event = await startedProgramme();
        await expectLater(
          admin.events.correctionOnEvent(
            event.id,
            version: event.version,
            sessions: () => tooShort,
          ),
          serverError(422, SdkErrorCode.invalidSessionsTotal),
        );
        expect((await schedulesOf(event.id)).single.sessions, isNull);
      });

      test(
        'a scheduleId from another event is 404 SCHEDULE_NOT_FOUND',
        () async {
          final event = await startedProgramme();
          final other = await startedProgramme();
          final othersSchedule = (await schedulesOf(other.id)).single;

          await expectLater(
            admin.events.correctionOnEvent(
              event.id,
              version: event.version,
              sessions: () => warmUpAndDrills,
              scheduleId: othersSchedule.id,
            ),
            serverError(404, SdkErrorCode.scheduleNotFound),
          );
          expect((await schedulesOf(event.id)).single.sessions, isNull);
          expect((await schedulesOf(other.id)).single.sessions, isNull);
        },
      );

      test('scheduleId without sessions is refused with 422', () async {
        final event = await startedProgramme();
        final schedule = (await schedulesOf(event.id)).single;
        await expectLater(
          admin.events.correctionOnEvent(
            event.id,
            version: event.version,
            scheduleId: schedule.id,
          ),
          serverError(422),
        );
      });

      test('a member cannot correct the timetable', () async {
        final event = await startedProgramme();
        await expectLater(
          member.events.correctionOnEvent(
            event.id,
            version: event.version,
            sessions: () => warmUpAndDrills,
          ),
          throwsA(isA<ServerException>()),
        );
        expect((await schedulesOf(event.id)).single.sessions, isNull);
      });
    });

    group('camp and one-off (updateEvent)', () {
      test("corrects a camp's timetable after the camp has started", () async {
        final camp = await create(
          EventType.camp,
          dayAt(-1),
          rrule: 'FREQ=DAILY;COUNT=5',
        );

        final updated = await admin.events.updateEvent(
          camp.id,
          version: camp.version,
          sessions: () => warmUpAndDrills,
        );
        expect(updated.version, camp.version + 1);
        expect((await schedulesOf(camp.id)).single.sessions, warmUpAndDrills);
      });

      test("corrects a one-off's timetable after it has started", () async {
        final oneOff = await create(EventType.oneOff, dayAt(-2));

        await admin.events.updateEvent(
          oneOff.id,
          version: oneOff.version,
          sessions: () => halves,
        );
        expect((await schedulesOf(oneOff.id)).single.sessions, halves);
      });

      test('a null sessions getter clears a camp timetable', () async {
        final camp = await create(
          EventType.camp,
          dayAt(-1),
          rrule: 'FREQ=DAILY;COUNT=5',
        );
        final withTimetable = await admin.events.updateEvent(
          camp.id,
          version: camp.version,
          sessions: () => halves,
        );
        await admin.events.updateEvent(
          camp.id,
          version: withTimetable.version,
          sessions: () => null,
        );
        expect((await schedulesOf(camp.id)).single.sessions, isNull);
      });

      test('periods that do not sum to the window are refused with '
          'INVALID_SESSIONS_TOTAL', () async {
        final camp = await create(
          EventType.camp,
          dayAt(-1),
          rrule: 'FREQ=DAILY;COUNT=5',
        );
        await expectLater(
          admin.events.updateEvent(
            camp.id,
            version: camp.version,
            sessions: () => tooShort,
          ),
          serverError(422, SdkErrorCode.invalidSessionsTotal),
        );
        expect((await schedulesOf(camp.id)).single.sessions, isNull);

        final oneOff = await create(EventType.oneOff, dayAt(-2));
        await expectLater(
          admin.events.updateEvent(
            oneOff.id,
            version: oneOff.version,
            sessions: () => tooShort,
          ),
          serverError(422, SdkErrorCode.invalidSessionsTotal),
        );
      });
    });
  });
}
