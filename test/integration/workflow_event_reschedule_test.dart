import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Event-lifecycle reshape coverage for issue #601:
/// - `POST /events/{id}/reschedule` (server #230, #232)
/// - `POST /events/{id}/undo-cancel` (server #111)
/// - camp `cancel` effective-time validation (server #108)
///
/// Camps are scheduled months ahead so the before-start guard
/// (`EVENT_ALREADY_STARTED`) and the 30-minute cancel lead time are
/// satisfied, and inside the 52-week horizon (`BEYOND_SCHEDULING_HORIZON`,
/// #16).
void main() {
  group('Issue 601: event reschedule / undo-cancel / camp cancel', () {
    late SecureClient client;
    late int venueId;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      await client.auth.login(sudoUsername, sudoPassword);

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_admin_601',
        email: 'test_admin_601@test.com',
        password: 'password123',
        firstName: 'Admin 601',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_admin_601', 'admin');

      final venue = await client.venues.createVenue(name: 'test_601 Court');
      venueId = venue.id;

      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login('test_admin_601', 'password123');
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // Not logged in — ignore.
      }
    });

    Future<Event> createCamp({required DateTime start}) {
      return client.events.createEvent(
        title: 'test_Camp 601',
        description: 'Reschedule lifecycle camp',
        type: EventType.camp,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 2)),
        rrule: 'FREQ=DAILY;COUNT=5',
      );
    }

    test('Issue 601: rescheduleEvent moves a camp start in place', () async {
      final start = DateTime.utc(2027, 3, 15, 10);
      final camp = await createCamp(start: start);

      final newStart = DateTime.utc(2027, 3, 16, 10);
      final moved = await client.events.rescheduleEvent(
        camp.id,
        version: camp.version,
        startTimeUtc: newStart,
      );

      // Moving only the start preserves the 2-hour duration.
      expect(moved.startTimeUtc, newStart);
      expect(moved.endTimeUtc, newStart.add(const Duration(hours: 2)));
    });

    test(
      'Issue 706: reschedule changes window and session split atomically',
      () async {
        final start = DateTime.utc(2027, 5, 10, 10);
        final camp = await client.events.createEvent(
          title: 'test_Camp 706',
          description: 'Atomic sessions reschedule',
          type: EventType.camp,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 2)),
          rrule: 'FREQ=DAILY;COUNT=5',
          sessions: const [
            EventSession(name: 'On-Ice', periodMinutes: 60),
            EventSession(name: 'Off-Ice', periodMinutes: 60),
          ],
        );

        // Shrink the daily window to 90 minutes and supply a split that fits
        // it, all in one call — impossible before the server moved sessions
        // onto the reschedule endpoint (#248).
        final newEnd = start.add(const Duration(minutes: 90));
        final updated = await client.events.rescheduleEvent(
          camp.id,
          version: camp.version,
          endTimeUtc: newEnd,
          sessions: () => const [
            EventSession(name: 'On-Ice', periodMinutes: 45),
            EventSession(name: 'Off-Ice', periodMinutes: 45),
          ],
        );

        expect(updated.endTimeUtc, newEnd);
        expect(updated.sessions, const [
          EventSession(name: 'On-Ice', periodMinutes: 45),
          EventSession(name: 'Off-Ice', periodMinutes: 45),
        ]);
      },
    );

    test(
      'Issue 706: reschedule with sessions: null clears the timetable',
      () async {
        final start = DateTime.utc(2027, 5, 20, 10);
        final camp = await client.events.createEvent(
          title: 'test_Camp 706 clear',
          description: 'Clear timetable on reschedule',
          type: EventType.camp,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 2)),
          rrule: 'FREQ=DAILY;COUNT=5',
          sessions: const [
            EventSession(name: 'On-Ice', periodMinutes: 60),
            EventSession(name: 'Off-Ice', periodMinutes: 60),
          ],
        );

        final cleared = await client.events.rescheduleEvent(
          camp.id,
          version: camp.version,
          startTimeUtc: start.add(const Duration(days: 1)),
          sessions: () => null,
        );

        expect(cleared.sessions, anyOf(isNull, isEmpty));
      },
    );

    test(
      'Issue 706: a split that does not sum to the new window is rejected',
      () async {
        final start = DateTime.utc(2027, 5, 25, 10);
        final camp = await client.events.createEvent(
          title: 'test_Camp 706 bad split',
          description: 'Stale split vs new window',
          type: EventType.camp,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 2)),
          rrule: 'FREQ=DAILY;COUNT=5',
          sessions: const [
            EventSession(name: 'On-Ice', periodMinutes: 60),
            EventSession(name: 'Off-Ice', periodMinutes: 60),
          ],
        );

        // Window shrinks to 90 but the supplied split still sums to 120.
        expect(
          () => client.events.rescheduleEvent(
            camp.id,
            version: camp.version,
            endTimeUtc: start.add(const Duration(minutes: 90)),
            sessions: () => const [
              EventSession(name: 'On-Ice', periodMinutes: 60),
              EventSession(name: 'Off-Ice', periodMinutes: 60),
            ],
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidSessionsTotal,
            ),
          ),
        );
      },
    );

    test(
      'Issue 601: rescheduleEvent with no fields → VALIDATION_ERROR',
      () async {
        final camp = await createCamp(start: DateTime.utc(2027, 4, 1, 10));

        // The event /reschedule schema requires at least one field; an empty
        // body is rejected at the schema layer (VALIDATION_ERROR), before any
        // business-logic check. (NOTHING_TO_RESCHEDULE is the occurrence-level
        // empty-body code — see the occurrence test below.)
        expect(
          () => client.events.rescheduleEvent(camp.id, version: camp.version),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.validationError,
            ),
          ),
        );
      },
    );

    test(
      'Issue 601: rescheduleOccurrence with no fields → NOTHING_TO_RESCHEDULE',
      () async {
        final start = DateTime.utc(2027, 4, 20, 10);
        final camp = await createCamp(start: start);

        // The occurrence /reschedule schema allows an all-null body; the
        // service rejects it with the coded NOTHING_TO_RESCHEDULE (#113).
        expect(
          // Untouched occurrence, so version 1.
          () => client.occurrences.rescheduleOccurrence(
            camp.id,
            start,
            version: 1,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.nothingToReschedule,
            ),
          ),
        );
      },
    );

    test(
      'Issue 601: camp cancel at a real session boundary, then undo-cancel',
      () async {
        final start = DateTime.utc(2027, 5, 6, 10);
        final camp = await createCamp(start: start);

        // The first occurrence start is a valid session boundary.
        final cancelled = await client.events.cancelSeries(
          camp.id,
          reason: 'Venue flooded',
          effectiveDateTimeUtc: start,
        );
        expect(cancelled.status, EventStatus.cancelled);

        final restored = await client.events.undoCancelSeries(camp.id);
        expect(restored.status, EventStatus.active);
      },
    );

    test(
      'Issue 601: camp cancel off a session boundary → '
      'EFFECTIVE_TIME_NOT_SESSION_BOUNDARY',
      () async {
        final start = DateTime.utc(2027, 6, 10, 10);
        final camp = await createCamp(start: start);

        // One hour past the first occurrence start is not a daily boundary;
        // it is still in the future and outside the 30-minute lead window, so
        // the boundary check is what fails.
        expect(
          () => client.events.cancelSeries(
            camp.id,
            reason: 'Bad time',
            effectiveDateTimeUtc: start.add(const Duration(hours: 1)),
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.effectiveTimeNotSessionBoundary,
            ),
          ),
        );
      },
    );

    test(
      'Issue 601: undo-cancel on a live event → EVENT_NOT_CANCELLED',
      () async {
        final camp = await createCamp(start: DateTime.utc(2027, 7, 1, 10));

        expect(
          () => client.events.undoCancelSeries(camp.id),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.eventNotCancelled,
            ),
          ),
        );
      },
    );
  });
}
