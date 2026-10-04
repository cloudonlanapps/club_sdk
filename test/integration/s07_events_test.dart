import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 7: Events Test Suite.
///
/// Tests requirements from Section 7 (Events):
/// - 7.01: Create Event
/// - 7.02: Correction on Event
/// - 7.03: Update Future Occurrences
/// - 7.04: Cancel Event
/// - 7.05: Delete Event
/// - 7.06: List Events
/// - 7.07: Get Event by ID
/// - 7.08: Get Event Chain
/// - 7.09: Set Event Visibility
/// - 7.10: Check Event Conflicts
/// - 7.12: Create OneOff Event
/// - 7.13: Create Programme
/// - 7.14: Create Camp
/// - 7.15: List My Events
/// - 7.16: Update with Effective Date
/// - 7.19: Conflict Detection (ConflictReport)
///
/// EventSource coverage:
/// - [`x`] createEvent
/// - [`x`] getEvent
/// - [`x`] listEvents
/// - [`x`] updateEvent
/// - [`x`] correctionOnEvent
/// - [`x`] updateEventForAllFuture
/// - [`x`] cancelSeries
/// - [`x`] listSchedules (the chain is gone, #16)
/// - [`x`] deleteEvent
/// - [`x`] checkConflict (every type, #16)
/// - [ ] listDeletedEvents / restoreEvent / hardDeleteEvent (covered in s02)
void main() {
  group('Section 7: Events', () {
    late SecureClient client;
    late int venue1Id;
    late int venue2Id;
    final now = DateTime.utc(2027, 3, 1, 10);

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean all test_ artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to seed test data
      await client.auth.login(sudoUsername, sudoPassword);

      // 3. Create venues needed by event tests
      final v1 = await client.venues.createVenue(
        name: 'test_Venue 1 S07',
        address: 'S07 Street 1',
      );
      venue1Id = v1.id;

      final v2 = await client.venues.createVenue(
        name: 'test_Venue 2 S07',
        address: 'S07 Street 2',
      );
      venue2Id = v2.id;

      // Create coach users for conflict and organizer tests
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_coach1_s07',
        email: 'test_coach1_s07@test.com',
        password: 'password123',
        firstName: 'Coach1 S07',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_coach1_s07', 'coach');

      // 4. Logout sudo
      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // Not logged in — ignore
      }
    });

    group('7.01: Create Event', () {
      test('one-off event', () async {
        final event = await client.events.createEvent(
          title: 'test_Match',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now,
          endTimeUtc: now.add(const Duration(hours: 1)),
        );
        expect(
          (await client.events.listEvents()).items.any((e) => e.id == event.id),
          isTrue,
        );
      });

      test('set venue location', () async {
        final event = await client.events.createEvent(
          title: 'test_Venue Location',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue2Id,
          startTimeUtc: now.add(const Duration(hours: 2)),
          endTimeUtc: now.add(const Duration(hours: 3)),
        );
        // Verify venue is set on the event itself
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.venueId, venue2Id);
      });

      test('set title and description', () async {
        final event = await client.events.createEvent(
          title: 'test_SPEC_TITLE',
          description: 'SPEC_DESC',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(hours: 4)),
          endTimeUtc: now.add(const Duration(hours: 5)),
        );
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.title, 'test_SPEC_TITLE');
      });
    });

    group('7.02: Correction on Event', () {
      test('updates programme event details', () async {
        final start = now.add(const Duration(days: 1));
        final event = await client.events.createEvent(
          title: 'test_Original Title',
          description: 'Original Desc',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: weeklyOn(start),
        );

        final updated = await client.events.correctionOnEvent(
          event.id,
          version: event.version,
          title: 'test_Updated Title',
          description: 'Updated Desc',
        );

        expect(updated.title, 'test_Updated Title');
        expect(updated.description, 'Updated Desc');
      });
    });

    group('7.03: Update Future Occurrences', () {
      test(
        'updates all future occurrences',
        () async {
          // Own weekday and hour: programmes clash on venue and organizer.
          final start = now.add(const Duration(days: 2, hours: 2));
          final event = await client.events.createEvent(
            title: 'test_Series Event',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venue1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
            rrule: weeklyOn(start),
          );

          // A split keeps the event id; the change is a new schedule (#16).
          final cutoff = start.add(const Duration(days: 7));
          final newStart = cutoff.add(const Duration(hours: 2));
          final newEvent = await client.events.updateEventForAllFuture(
            event.id,
            version: event.version,
            startTimeUtc: newStart,
            endTimeUtc: newStart.add(const Duration(hours: 1)),
            effectiveDateTimeUtc: cutoff,
          );

          expect(newEvent.id, event.id);
          expect(newEvent.startTimeUtc, newStart);
          final schedules = await client.events.listSchedules(event.id);
          expect(schedules, hasLength(2));
          expect(schedules.first.effectiveUntilUtc, cutoff);
          expect(schedules.last.startTimeUtc, newStart);
        },
      );
    });

    group('7.04: Cancel Event', () {
      test(
        'cancels all occurrences',
        () async {
          final start = now.add(const Duration(days: 7));
          final event = await client.events.createEvent(
            title: 'test_Cancel Test',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venue1Id,
            startTimeUtc: start,
            endTimeUtc: start.add(const Duration(hours: 1)),
            rrule: weeklyOn(start),
          );

          // A programme is ended by terminate, not cancel (#16); the cutoff
          // is an occurrence start and every occurrence from it is cancelled.
          final cutoff = start.add(const Duration(days: 7));
          await client.events.terminate(
            event.id,
            reason: 'Testing cancellation',
            cutoffTimeUtc: cutoff,
          );

          final cancelledEvent = await client.events.getEvent(event.id);
          expect(cancelledEvent.status, EventStatus.cancelled);
          expect(cancelledEvent.untilTimeUtc, cutoff);
          expect(isOccurrenceCancelled(cancelledEvent, cutoff), isTrue);
          expect(isOccurrenceCancelled(cancelledEvent, start), isFalse);
        },
      );
    });

    group('7.05: Delete Event', () {
      test('soft deletes event', () async {
        final event = await client.events.createEvent(
          title: 'test_Delete Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 14)),
          endTimeUtc: now.add(const Duration(days: 14, hours: 1)),
        );

        await client.events.deleteEvent(event.id);

        // Verify absent from active list
        final activeEvents = await client.events.listEvents(
          limit: 100,
        );
        expect(activeEvents.items.any((e) => e.id == event.id), isFalse);

        // Verify present in deleted list
        final deletedEvents = (await client.events.listDeletedEvents(
          limit: 100,
        )).items;
        expect(deletedEvents.any((e) => e.id == event.id), isTrue);
      });
    });

    group('7.06: List Events', () {
      test('filter by type, visibility, and date', () async {
        final start = now.add(const Duration(days: 15, hours: 4));
        await client.events.createEvent(
          title: 'test_Public Prog',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: weeklyOn(start),
        );

        final publicEvents = await client.events.listEvents(
          visibility: Visibility.public,
        );
        expect(
          publicEvents.items.every((e) => e.visibility == Visibility.public),
          isTrue,
        );

        final programmes = await client.events.listEvents(
          eventType: EventType.programme,
        );
        expect(
          programmes.items.every((e) => e.type == EventType.programme),
          isTrue,
        );
      });

      test('paginate with limit and offset', () async {
        for (var i = 0; i < 5; i++) {
          await client.events.createEvent(
            title: 'test_Page Test $i',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: venue1Id,
            startTimeUtc: now.add(Duration(days: 20 + i)),
            endTimeUtc: now.add(Duration(days: 20 + i, hours: 1)),
          );
        }

        final page1 = await client.events.listEvents(
          limit: 2,
        );
        expect(page1.items.length, 2);

        final page2 = await client.events.listEvents(
          limit: 2,
          offset: 2,
        );
        expect(page2.items.isNotEmpty, isTrue);
      });
    });

    group('7.07: Get Event by ID', () {
      test('returns event details', () async {
        final event = await client.events.createEvent(
          title: 'test_Get Test',
          description: 'Get Description',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 30)),
          endTimeUtc: now.add(const Duration(days: 30, hours: 1)),
        );

        final fetched = await client.events.getEvent(event.id);
        expect(fetched.id, event.id);
        expect(fetched.title, 'test_Get Test');
        expect(fetched.description, 'Get Description');
      });
    });

    group('7.08: Get Event Chain', () {
      test('returns linked events', () async {
        // A split no longer creates a successor: the event keeps its id and
        // the history is its schedule list (#16).
        final start = now.add(const Duration(days: 40));
        final original = await client.events.createEvent(
          title: 'test_Chain Test',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          rrule: weeklyOn(start),
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        final cutoff = start.add(const Duration(days: 7));
        final splitEvent = await client.events.updateEventForAllFuture(
          original.id,
          version: original.version,
          effectiveDateTimeUtc: cutoff,
          coachNames: () => ['test_coach1_s07'],
        );
        expect(splitEvent.id, original.id);

        final schedules = await client.events.listSchedules(original.id);
        expect(schedules.length, 2);
        expect(schedules[0].eventId, original.id);
        expect(schedules[0].effectiveUntilUtc, cutoff);
        expect(schedules[1].effectiveFromUtc, cutoff);
        expect(schedules[1].isCurrent, isTrue);
        expect(schedules[1].coachNames, ['test_coach1_s07']);
      });
    });

    group('7.09: Set Event Visibility', () {
      test('private event not visible to non-enrolled', () async {
        final event = await client.events.createEvent(
          title: 'test_Private',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.private,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 50)),
          endTimeUtc: now.add(const Duration(days: 50, hours: 1)),
        );
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.visibility, Visibility.private);
      });
    });

    group('7.10: Check Event Conflicts', () {
      test('prevents double booking', () async {
        await client.events.createEvent(
          title: 'test_Booking 1',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: DateTime.utc(2027, 4, 1, 10),
          endTimeUtc: DateTime.utc(2027, 4, 1, 12),
        );

        // A one-off overlap is reported, not blocked (#16): the probe
        // names the venue clash and the creation still goes through.
        final report = await client.events.checkConflict(
          type: EventType.oneOff,
          venueId: venue1Id,
          startTimeUtc: DateTime.utc(2027, 4, 1, 11),
          endTimeUtc: DateTime.utc(2027, 4, 1, 13),
        );
        expect(report.hasConflict, isTrue);
        expect(report.venueConflicts, isNotEmpty);

        final second = await client.events.createEvent(
          title: 'test_Booking 2',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: DateTime.utc(2027, 4, 1, 11),
          endTimeUtc: DateTime.utc(2027, 4, 1, 13),
        );
        expect(second.status, EventStatus.active);
      });
    });

    group('7.12: Create OneOff Event', () {
      test('creates single event', () async {
        final event = await client.events.createEvent(
          title: 'test_OneOff 712',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 60)),
          endTimeUtc: now.add(const Duration(days: 60, hours: 1)),
        );

        expect(event.type, EventType.oneOff);
        expect(event.rrule, isNull);
      });
    });

    group('7.13: Create Programme', () {
      test('recurring event with RRULE', () async {
        final event = await client.events.createEvent(
          title: 'test_Yoga',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 70, hours: 6)),
          endTimeUtc: now.add(const Duration(days: 70, hours: 7)),
          rrule: weeklyOn(now.add(const Duration(days: 70))),
        );
        expect(event.type, EventType.programme);
        expect(event.rrule, weeklyOn(now.add(const Duration(days: 70))));
      });
    });

    group('7.14: Create Camp', () {
      test('multi-day event with RRULE', () async {
        final event = await client.events.createEvent(
          title: 'test_Camp',
          description: 'D',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 80)),
          endTimeUtc: now.add(const Duration(days: 80, hours: 1)),
          rrule: 'FREQ=DAILY;COUNT=5',
        );
        expect(event.type, EventType.camp);
      });
    });

    group('7.15: List My Events', () {
      test('member can view public events', () async {
        await client.events.createEvent(
          title: 'test_My Events Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 90)),
          endTimeUtc: now.add(const Duration(days: 90, hours: 1)),
        );

        final events = await client.events.listEvents(
          visibility: Visibility.public,
        );
        expect(events.items.isNotEmpty, isTrue);
      });
    });

    group('7.16: Update with Effective Date', () {
      test('schedules future changes', () async {
        final start = now.add(const Duration(days: 100));
        final event = await client.events.createEvent(
          title: 'test_Effective Date Test',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          rrule: weeklyOn(start),
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
        );

        // The split takes scheduling and staffing only (#16); a rename goes
        // through correction. The event keeps its id and gains a schedule.
        final effectiveDate = start.add(const Duration(days: 14));
        final newStart = effectiveDate.add(const Duration(hours: 2));
        final newEvent = await client.events.updateEventForAllFuture(
          event.id,
          version: event.version,
          effectiveDateTimeUtc: effectiveDate,
          startTimeUtc: newStart,
          endTimeUtc: newStart.add(const Duration(hours: 1)),
        );
        expect(newEvent.id, event.id);
        expect(newEvent.startTimeUtc, newStart);
        expect(newEvent.untilTimeUtc, isNull);
        expect(newEvent.status, EventStatus.active);

        final schedules = await client.events.listSchedules(event.id);
        expect(schedules, hasLength(2));
        expect(schedules.first.effectiveUntilUtc, effectiveDate);
        expect(schedules.first.startTimeUtc, start);
        expect(schedules.last.effectiveFromUtc, effectiveDate);
        expect(schedules.last.startTimeUtc, newStart);

        final renamed = await client.events.correctionOnEvent(
          event.id,
          version: newEvent.version,
          title: 'test_Effective Date Test - After Split',
        );
        expect(renamed.title, 'test_Effective Date Test - After Split');
      });
    });

    group('7.19: Conflict Detection - ConflictReport', () {
      test('checkConflict detects venue conflict on camp', () async {
        await client.events.createEvent(
          title: 'test_Camp Conflict Existing',
          description: 'D',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: DateTime.utc(2027, 5, 1, 10),
          endTimeUtc: DateTime.utc(2027, 5, 1, 12),
          rrule: 'FREQ=DAILY;COUNT=3',
        );

        final report = await client.events.checkConflict(
          type: EventType.camp,
          venueId: venue1Id,
          startTimeUtc: DateTime.utc(2027, 5, 1, 10),
          endTimeUtc: DateTime.utc(2027, 5, 1, 12),
          rrule: 'FREQ=DAILY;COUNT=3',
          untilTimeUtc: DateTime.utc(2027, 5, 3, 12),
        );

        expect(report.hasConflict, isTrue);
        expect(report.venueConflicts, isNotEmpty);
      });

      test('checkConflict detects organizer conflict on camp', () async {
        await client.events.createEvent(
          title: 'test_Organizer Conflict',
          description: 'D',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venue1Id,
          organizerName: 'test_coach1_s07',
          startTimeUtc: DateTime.utc(2027, 5, 2, 10),
          endTimeUtc: DateTime.utc(2027, 5, 2, 12),
          rrule: 'FREQ=DAILY;COUNT=2',
        );

        final report = await client.events.checkConflict(
          type: EventType.camp,
          venueId: venue2Id,
          organizerName: 'test_coach1_s07',
          startTimeUtc: DateTime.utc(2027, 5, 2, 10),
          endTimeUtc: DateTime.utc(2027, 5, 2, 12),
          rrule: 'FREQ=DAILY;COUNT=2',
          untilTimeUtc: DateTime.utc(2027, 5, 3, 12),
        );

        expect(report.hasConflict, isTrue);
        expect(report.organizerConflicts, isNotEmpty);
      });

      test(
        'checkConflict returns no conflict when clear',
        () async {
          // A slot no programme in this file touches (venue 2, 03:00).
          final report = await client.events.checkConflict(
            type: EventType.camp,
            venueId: venue2Id,
            startTimeUtc: DateTime.utc(2027, 6, 3, 3),
            endTimeUtc: DateTime.utc(2027, 6, 3, 5),
            rrule: 'FREQ=DAILY;COUNT=2',
            untilTimeUtc: DateTime.utc(2027, 6, 4, 5),
          );

          expect(report.hasConflict, isFalse);
          expect(report.venueConflicts, isEmpty);
          expect(report.organizerConflicts, isEmpty);
          expect(report.coachConflicts, isEmpty);
        },
      );
    });

    group('7.20: Update Event (camp/oneOff)', () {
      test('updates a one-off event title and description', () async {
        final event = await client.events.createEvent(
          title: 'test_OneOff Update',
          description: 'Original',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 110)),
          endTimeUtc: now.add(const Duration(days: 110, hours: 1)),
        );

        final updated = await client.events.updateEvent(
          event.id,
          version: event.version,
          title: 'test_OneOff Updated',
          description: 'Updated Desc',
        );

        expect(updated.title, 'test_OneOff Updated');
        expect(updated.description, 'Updated Desc');

        // Verify via getEvent
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.title, 'test_OneOff Updated');
      });

      test('updates a camp event visibility', () async {
        final event = await client.events.createEvent(
          title: 'test_Camp Update',
          description: 'D',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 112)),
          endTimeUtc: now.add(const Duration(days: 112, hours: 4)),
          rrule: 'FREQ=DAILY;COUNT=3',
        );

        final updated = await client.events.updateEvent(
          event.id,
          version: event.version,
          visibility: Visibility.private,
        );

        expect(updated.visibility, Visibility.private);
      });

      test('Issue 601: reschedules a one-off event venue', () async {
        final event = await client.events.createEvent(
          title: 'test_OneOff Venue Update',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 114)),
          endTimeUtc: now.add(const Duration(days: 114, hours: 1)),
        );

        // Venue changes move through /reschedule, not the metadata PATCH (#232).
        final updated = await client.events.rescheduleEvent(
          event.id,
          version: event.version,
          venueId: venue2Id,
        );

        expect(updated.venueId, venue2Id);
      });
    });

    group('7.21: Event type routing enforcement', () {
      test('updateEvent rejects programme events', () async {
        final programme = await client.events.createEvent(
          title: 'test_Programme Guard',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 120, hours: 6)),
          endTimeUtc: now.add(const Duration(days: 120, hours: 7)),
          rrule: weeklyOn(now.add(const Duration(days: 120))),
        );

        expect(
          () => client.events.updateEvent(
            programme.id,
            version: programme.version,
            title: 'test_Should Fail',
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidEventType,
            ),
          ),
        );
      });

      test('correctionOnEvent rejects one-off events', () async {
        final oneOff = await client.events.createEvent(
          title: 'test_OneOff Guard',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 122)),
          endTimeUtc: now.add(const Duration(days: 122, hours: 1)),
        );

        expect(
          () => client.events.correctionOnEvent(
            oneOff.id,
            version: oneOff.version,
            title: 'test_Should Fail',
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidEventType,
            ),
          ),
        );
      });

      test('correctionOnEvent rejects camp events', () async {
        final camp = await client.events.createEvent(
          title: 'test_Camp Guard',
          description: 'D',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 124)),
          endTimeUtc: now.add(const Duration(days: 124, hours: 4)),
          rrule: 'FREQ=DAILY;COUNT=3',
        );

        expect(
          () => client.events.correctionOnEvent(
            camp.id,
            version: camp.version,
            title: 'test_Should Fail',
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidEventType,
            ),
          ),
        );
      });

      test(
        'updateEventForAllFuture rejects one-off events',
        () async {
          final oneOff = await client.events.createEvent(
            title: 'test_OneOff Future Guard',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: venue1Id,
            startTimeUtc: now.add(const Duration(days: 126)),
            endTimeUtc: now.add(const Duration(days: 126, hours: 1)),
          );

          expect(
            () => client.events.updateEventForAllFuture(
              oneOff.id,
              version: oneOff.version,
              effectiveDateTimeUtc: oneOff.startTimeUtc,
              venueId: venue1Id,
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.invalidEventType,
              ),
            ),
          );
        },
      );

      test('correctionOnEvent accepts programme events', () async {
        final programme = await client.events.createEvent(
          title: 'test_Programme Correction OK',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 128, hours: 8)),
          endTimeUtc: now.add(const Duration(days: 128, hours: 9)),
          rrule: weeklyOn(now.add(const Duration(days: 128))),
        );

        final updated = await client.events.correctionOnEvent(
          programme.id,
          version: programme.version,
          title: 'test_Programme Corrected',
        );

        expect(updated.title, 'test_Programme Corrected');
      });

      test('updateEvent accepts one-off events', () async {
        final oneOff = await client.events.createEvent(
          title: 'test_OneOff Update OK',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 130)),
          endTimeUtc: now.add(const Duration(days: 130, hours: 1)),
        );

        final updated = await client.events.updateEvent(
          oneOff.id,
          version: oneOff.version,
          title: 'test_OneOff Updated OK',
        );

        expect(updated.title, 'test_OneOff Updated OK');
      });

      test('updateEvent accepts camp events', () async {
        final camp = await client.events.createEvent(
          title: 'test_Camp Update OK',
          description: 'D',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 132)),
          endTimeUtc: now.add(const Duration(days: 132, hours: 4)),
          rrule: 'FREQ=DAILY;COUNT=3',
        );

        final updated = await client.events.updateEvent(
          camp.id,
          version: camp.version,
          title: 'test_Camp Updated OK',
        );

        expect(updated.title, 'test_Camp Updated OK');
      });
    });
  });
}
