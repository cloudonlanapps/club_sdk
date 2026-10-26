import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_reminders.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 44: an occurrence's reminders leave the inbox when it stops being
/// live (club_server#49, notifications R87a, R93a).
///
/// Cancelling an occurrence or dropping a one-off removes that occurrence's
/// `event.upcoming_reminder` and `attendance.pending_mark_reminder`; a camp
/// series cancel or a programme termination removes those at or after the
/// cutoff; deleting the event removes all of its own.
///
/// Every event here has its next occurrence a few hours ahead, so the
/// scheduler's next tick (at most five minutes away) reminds the member of
/// it; setUpAll waits for those reminders before anything is cancelled. The
/// camps and the programme also have an earlier occurrence that ended in the
/// past, whose pending-mark reminder to staff must stay. That reminder is
/// sent only by the first tick's scan, so those checks run only on a fresh
/// stack (`just test-one`) and are skipped, with the reason, otherwise.
void main() {
  const testFile = 'issue_44_cancelled_occurrence_reminders_test.dart';

  group('Issue 44: reminders of an occurrence that stops being live', () {
    late SecureClient admin;
    late SecureClient member;
    final opened = <SecureClient>[];
    const memberName = 'test_i44_member';
    const password = 'password123';

    late Event campOne;
    late Event campSeries;
    late Event oneOffDropped;
    late Event programme;
    late Event oneOffDeleted;
    late Event untouched;

    /// The occurrence of each event that is a few hours ahead.
    late DateTime campOneNext;
    late DateTime campSeriesNext;
    late DateTime programmeNext;

    /// Whether the pending-mark reminders of the earlier occurrences were
    /// sent; when not, [pendingMarkScanSkip] says why.
    var pendingMarksSent = false;

    Future<int> venue(String name) async =>
        (await admin.venues.createVenue(name: 'test_Venue I44 $name')).id;

    Future<Event> create({
      required String title,
      required EventType type,
      required DateTime start,
      String? rrule,
    }) async {
      final event = await admin.events.createEvent(
        title: 'test_I44 $title',
        description: '',
        type: type,
        visibility: Visibility.public,
        venueId: await venue(title),
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: rrule,
      );
      await admin.enrollments.assign(event.id, memberName);
      expect(
        await admin.enrollments.getEnrollmentStatus(event.id, memberName),
        EnrollmentStatus.assigned,
      );
      return event;
    }

    Future<List<AppNotification>> upcomingOf(Event e, DateTime t) =>
        remindersFor(member, upcomingReminder, e.id, t);

    Future<List<AppNotification>> pendingMarkOf(Event e, DateTime t) =>
        remindersFor(admin, pendingMarkReminder, e.id, t);

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(admin);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: memberName,
        email: '$memberName@test.com',
        password: password,
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
        firstName: 'Member',
      );
      // Where the credit system is on, the server credit-gates assign
      // (credit R35); a no-op where the module is off (#62).
      await seedEnrolmentCreditIfGated(admin, [memberName]);
      member = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(member);
      await member.auth.login(memberName, password);
      expect((await member.auth.getCurrentUser()).username, memberName);

      // Every next occurrence is 3–9 hours ahead: inside the 24-hour lead,
      // outside the 1-hour one, and far from every lead-time rule. Sudo
      // organizes them all, so they are 90 minutes apart.
      final base = nowUtcMinute().add(const Duration(hours: 3));
      const day = Duration(days: 1);
      campOneNext = base;
      campOne = await create(
        title: 'camp one occurrence',
        type: EventType.camp,
        start: campOneNext.subtract(day),
        rrule: 'FREQ=DAILY;COUNT=2',
      );
      campSeriesNext = base.add(const Duration(minutes: 90));
      campSeries = await create(
        title: 'camp series',
        type: EventType.camp,
        start: campSeriesNext.subtract(day),
        rrule: 'FREQ=DAILY;COUNT=2',
      );
      oneOffDropped = await create(
        title: 'one-off dropped',
        type: EventType.oneOff,
        start: base.add(const Duration(hours: 3)),
      );
      programmeNext = base.add(const Duration(hours: 4, minutes: 30));
      final programmeStart = programmeNext.subtract(const Duration(days: 7));
      programme = await create(
        title: 'programme',
        type: EventType.programme,
        start: programmeStart,
        rrule: weeklyOn(programmeStart),
      );
      oneOffDeleted = await create(
        title: 'one-off deleted',
        type: EventType.oneOff,
        start: base.add(const Duration(hours: 6)),
      );
      untouched = await create(
        title: 'one-off untouched',
        type: EventType.oneOff,
        start: base.add(const Duration(hours: 7, minutes: 30)),
      );

      final firstScan = await firstPendingMarkScanDeadline(admin);
      await waitForReminders(
        member,
        upcomingReminder,
        [
          (campOne.id, campOneNext),
          (campSeries.id, campSeriesNext),
          (oneOffDropped.id, oneOffDropped.startTimeUtc),
          (programme.id, programmeNext),
          (oneOffDeleted.id, oneOffDeleted.startTimeUtc),
          (untouched.id, untouched.startTimeUtc),
        ],
        deadline: DateTime.now().toUtc().add(tickWait),
      );
      if (firstScan != null) {
        await waitForReminders(
          admin,
          pendingMarkReminder,
          [
            (campOne.id, campOne.startTimeUtc),
            (campSeries.id, campSeries.startTimeUtc),
            (programme.id, programme.startTimeUtc),
          ],
          deadline: firstScan,
        );
        pendingMarksSent = true;
      }
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

    group('cancelling one camp occurrence', () {
      setUpAll(() async {
        await admin.occurrences.cancelOccurrence(
          campOne.id,
          campOneNext,
          version: await occurrenceVersion(admin, campOne.id, campOneNext),
          reason: 'ice',
        );
        final staffView = await admin.occurrences.getOccurrence(
          campOne.id,
          campOneNext,
        );
        expect(staffView.status, OccurrenceStatus.cancelled);
        final memberView = await member.myEvents.getMyOccurrence(
          memberName,
          campOne.id,
          campOneNext,
        );
        expect(memberView.status, OccurrenceStatus.cancelled);
      });

      test("Issue 44: removes its reminder from the member's inbox", () async {
        expect(await upcomingOf(campOne, campOneNext), isEmpty);
      });

      test("Issue 44: keeps the pending-mark reminder of the camp's earlier "
          'day', () async {
        if (!pendingMarksSent) {
          markTestSkipped(pendingMarkScanSkip(44, testFile));
          return;
        }
        expect(
          await pendingMarkOf(campOne, campOne.startTimeUtc),
          hasLength(1),
        );
      });
    });

    group('dropping a one-off', () {
      setUpAll(() async {
        final t = oneOffDropped.startTimeUtc;
        await admin.events.drop(
          oneOffDropped.id,
          version: await occurrenceVersion(admin, oneOffDropped.id, t),
          reason: 'rain',
        );
        final occ = await admin.occurrences.getOccurrence(oneOffDropped.id, t);
        expect(occ.status, OccurrenceStatus.cancelled);
      });

      test("Issue 44: removes its reminder from the member's inbox", () async {
        expect(
          await upcomingOf(oneOffDropped, oneOffDropped.startTimeUtc),
          isEmpty,
        );
      });
    });

    group('a camp series cancel', () {
      setUpAll(() async {
        final cancelled = await admin.events.cancelSeries(
          campSeries.id,
          version: (await admin.events.getEvent(campSeries.id)).version,
          reason: 'ice',
          effectiveDateTimeUtc: campSeriesNext,
        );
        expect(cancelled.untilTimeUtc, campSeriesNext);
        final occ = await admin.occurrences.getOccurrence(
          campSeries.id,
          campSeriesNext,
        );
        expect(occ.status, OccurrenceStatus.cancelled);
      });

      test(
        'Issue 44: removes the reminder of the occurrence at the cutoff',
        () async {
          expect(await upcomingOf(campSeries, campSeriesNext), isEmpty);
        },
      );

      test('Issue 44: keeps the pending-mark reminder of the day before the '
          'cutoff', () async {
        if (!pendingMarksSent) {
          markTestSkipped(pendingMarkScanSkip(44, testFile));
          return;
        }
        expect(
          await pendingMarkOf(campSeries, campSeries.startTimeUtc),
          hasLength(1),
        );
      });
    });

    group('a programme termination', () {
      setUpAll(() async {
        final terminated = await admin.events.terminate(
          programme.id,
          version: (await admin.events.getEvent(programme.id)).version,
          reason: 'season over',
          cutoffTimeUtc: programmeNext,
        );
        expect(terminated.untilTimeUtc, programmeNext);
        final occ = await admin.occurrences.getOccurrence(
          programme.id,
          programmeNext,
        );
        expect(occ.status, OccurrenceStatus.cancelled);
      });

      test(
        'Issue 44: removes the reminder of the occurrence at the cutoff',
        () async {
          expect(await upcomingOf(programme, programmeNext), isEmpty);
        },
      );

      test('Issue 44: keeps the pending-mark reminder of the week before the '
          'cutoff', () async {
        if (!pendingMarksSent) {
          markTestSkipped(pendingMarkScanSkip(44, testFile));
          return;
        }
        expect(
          await pendingMarkOf(programme, programme.startTimeUtc),
          hasLength(1),
        );
      });
    });

    group('deleting an event', () {
      setUpAll(() async {
        final deleted = await admin.events.deleteEvent(oneOffDeleted.id);
        expect(deleted.deletedAtUtc, isNotNull);
      });

      test("Issue 44: removes its reminder from the member's inbox", () async {
        expect(
          await upcomingOf(oneOffDeleted, oneOffDeleted.startTimeUtc),
          isEmpty,
        );
      });
    });

    test("Issue 44: an untouched event's reminder stays", () async {
      final occ = await admin.occurrences.getOccurrence(
        untouched.id,
        untouched.startTimeUtc,
      );
      expect(occ.status, OccurrenceStatus.scheduled);
      expect(await upcomingOf(untouched, untouched.startTimeUtc), hasLength(1));
    });
  });
}
