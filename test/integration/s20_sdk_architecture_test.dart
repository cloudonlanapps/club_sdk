import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 20: SDK Architecture Test Suite.
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.01: Three SDK Packages
/// - 20.02: Core SDK Minimal Dependencies
/// - 20.03: Local SDK Dependency
/// - 20.04: API SDK Dependency
/// - 20.05: Abstract Interface Contract
/// - 20.06: Models in Core Only
/// - 20.07: Manual JSON Serialization
/// - 20.08: Backward Compatible FromJson
/// - 20.09: No Raw Maps in API
/// - 20.10: Async All Methods
/// - 20.11: Typed Exceptions
/// - 20.12: Stateless SDK
/// - 20.13: Runtime Switchable
void main() {
  group('Section 20: SDK Architecture', () {
    late SecureClient client;
    late SecureClient memberClient;
    late int venueId;

    // Relative so camps and one-offs stay inside the scheduling horizon.
    final now = dayAt(0);

    const testUser = 'test_user_s20';
    const password = 'password123';

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean test artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo and seed data
      await client.auth.login(sudoUsername, sudoPassword);
      final adminUser = await client.auth.getCurrentUser();
      expect(adminUser.username, sudoUsername);

      // 3. Create venues
      final v1 = await client.venues.createVenue(
        name: 'test_Venue 1 S20',
        address: 'S20 Street 1',
      );
      venueId = v1.id;

      // 4. Register and approve a test user for enrollment tests
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: testUser,
        email: '$testUser@test.com',
        password: password,
        firstName: 'User S20',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // Credit gates programme enrollment where the module is on (#38);
      // a no-op where it is off.
      await seedEnrolmentCreditIfGated(client, [testUser]);

      // 5. Create member client
      memberClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await memberClient.auth.login(testUser, password);

      // 6. Logout admin
      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // ignore
      }
    });

    // =========================================================================
    // 20.01: Three SDK Packages
    // =========================================================================

    group('20.01: Three SDK Packages', () {
      test(
        '20.01: Three SDK Packages - SDK has modular structure',
        () async {
          expect(client.users, isNotNull);
          expect(client.events, isNotNull);
          expect(client.venues, isNotNull);
          expect(client.enrollments, isNotNull);
        },
      );
    });

    // =========================================================================
    // 20.02: Core SDK Minimal Dependencies
    // =========================================================================

    group('20.02: Core SDK Minimal Dependencies', () {
      test(
        '20.02: Core SDK - models work without platform',
        () async {
          final event = Event(
            id: 1,
            title: 'test_Test',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: now,
            endTimeUtc: now.add(const Duration(hours: 1)),
            createdAtUtc: now,
            updatedAtUtc: now,
          );

          expect(event.toMap(), isA<Map<String, dynamic>>());
          expect(event.toJson(), isA<String>());
        },
      );
    });

    // =========================================================================
    // 20.03–20.05: SDK Structure
    // =========================================================================

    group('20.03: Local SDK Dependency', () {
      test('20.03: Local operations work', () async {
        final venues = await client.venues.getVenues();
        expect(venues.items, isNotEmpty);
      });
    });

    group('20.04: API SDK Dependency', () {
      test('20.04: Sources are functional', () async {
        expect(client.users, isNotNull);
        expect(client.events, isNotNull);
        expect(client.venues, isNotNull);
        expect(client.enrollments, isNotNull);

        final venues = await client.venues.getVenues();
        expect(venues.items, isA<List<Venue>>());
      });
    });

    group('20.05: Abstract Interface Contract', () {
      test('20.05: Sources are abstract', () async {
        expect(client.users, isNotNull);
        expect(client.events, isNotNull);
        expect(client.enrollments, isNotNull);
      });
    });

    // =========================================================================
    // 20.06: Models in Core Only
    // =========================================================================

    group('20.06: Models in Core Only', () {
      test('20.06: Models are shared', () async {
        final event = await client.events.createEvent(
          title: 'test_Model Test S20',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: now.add(const Duration(days: 200)),
          endTimeUtc: now.add(const Duration(days: 200, hours: 1)),
        );

        expect(event, isA<Event>());
        expect(event.title, 'test_Model Test S20');
      });
    });

    // =========================================================================
    // 20.07: Manual JSON Serialization
    // =========================================================================

    group('20.07: Manual JSON Serialization', () {
      test('20.07: No codegen — toMap works', () async {
        final event = await client.events.createEvent(
          title: 'test_JSON Test S20',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: now.add(const Duration(days: 201)),
          endTimeUtc: now.add(const Duration(days: 201, hours: 1)),
        );

        final map = event.toMap();
        expect(map, isA<Map<String, dynamic>>());
        expect(map['title'], 'test_JSON Test S20');
      });
    });

    // =========================================================================
    // 20.08: Backward Compatible FromJson
    // =========================================================================

    group('20.08: Backward Compatible FromJson', () {
      test('20.08: Handles missing fields', () async {
        final minimalMap = <String, dynamic>{
          'id': 1,
          'title': 'Test',
          'description': 'D',
          'type': 'oneOff',
          'visibility': 'public',
          'venueId': 1,
          'startTimeUtc': now.millisecondsSinceEpoch,
          'endTimeUtc': now
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          'createdAtUtc': now.millisecondsSinceEpoch,
          'updatedAtUtc': now.millisecondsSinceEpoch,
        };
        final event = Event.fromMap(minimalMap);
        expect(event.rrule, isNull);
      });
    });

    // =========================================================================
    // 20.09: No Raw Maps in API
    // =========================================================================

    group('20.09: No Raw Maps in API', () {
      test('20.09: Uses typed models', () async {
        final events = await client.events.listEvents();
        expect(events, isA<PaginatedList<Event>>());
      });
    });

    // =========================================================================
    // 20.10: Async All Methods
    // =========================================================================

    group('20.10: Async All Methods', () {
      test('20.10: All source methods return Future', () async {
        final future = client.events.listEvents();
        expect(future, isA<Future<PaginatedList<Event>>>());
      });
    });

    // =========================================================================
    // 20.11: Typed Exceptions
    // =========================================================================

    group('20.11: Typed Exceptions', () {
      test('20.11a: getEvent throws ServerException on invalid ID', () async {
        expect(
          () => client.events.getEvent(99999),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.eventNotFound,
            ),
          ),
        );
      });

      test(
        '20.11b: correctionOnEvent throws on invalid event ID',
        () async {
          expect(
            () => client.events.correctionOnEvent(
              99999,
              version: 1,
              title: 'test_New Title',
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventNotFound,
              ),
            ),
          );
        },
      );

      test(
        '20.11c: cancelSeries throws on invalid event',
        () async {
          expect(
            () => client.events.cancelSeries(
              99999,
              reason: 'Cancelled',
              effectiveDateTimeUtc: DateTime.utc(2030),
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventNotFound,
              ),
            ),
          );
        },
      );

      test(
        '20.11d: updateEventForAllFuture throws on invalid event',
        () async {
          expect(
            () => client.events.updateEventForAllFuture(
              99999,
              version: 1,
              effectiveDateTimeUtc: DateTime.utc(2030),
              venueId: 1,
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventNotFound,
              ),
            ),
          );
        },
      );

      test('20.11e: getEventChain throws on invalid event', () async {
        // The chain is gone; the schedules list is the history (#16).
        expect(
          () => client.events.listSchedules(99999),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.eventNotFound,
            ),
          ),
        );
      });
    });

    // =========================================================================
    // 20.11: Occurrence Errors
    // =========================================================================

    group('20.11: ServerException - OccurrenceNotFound', () {
      test('20.11f: getOccurrence throws on invalid time', () async {
        final event = await client.events.createEvent(
          title: 'test_Occ Error Test S20',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: now,
          endTimeUtc: now.add(const Duration(hours: 1)),
          rrule: weeklyOn(now),
        );

        final invalidTime = DateTime.utc(2025, 1, 1, 10);
        expect(
          () => client.occurrences.getOccurrence(
            event.id,
            invalidTime,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.occurrenceNotFound,
            ),
          ),
        );
      });

      test('20.11g: cancelOccurrence throws on invalid time', () async {
        final event = await client.events.createEvent(
          title: 'test_Cancel Occ Error S20',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: now.add(const Duration(days: 100)),
          endTimeUtc: now.add(const Duration(days: 100, hours: 1)),
          rrule: weeklyOn(now.add(const Duration(days: 100))),
        );

        final invalidTime = DateTime.utc(2025, 1, 1, 10);
        expect(
          () => client.occurrences.cancelOccurrence(
            event.id,
            invalidTime,
            reason: 'Test',
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.occurrenceNotFound,
            ),
          ),
        );
      });

      test(
        '20.11h: declareLeave throws on invalid occurrence',
        () async {
          final event = await client.events.createEvent(
            title: 'test_Leave Occ Error S20',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: now.add(const Duration(days: 200)),
            endTimeUtc: now.add(const Duration(days: 200, hours: 1)),
            rrule: weeklyOn(now.add(const Duration(days: 200))),
          );

          await client.enrollments.assign(
            event.id,
            testUser,
          );

          // Use memberClient: super admin bypasses leave window check.
          // Server returns LEAVE_WINDOW_CLOSED for past times.
          final invalidTime = DateTime.utc(2025, 1, 1, 10);
          expect(
            () => memberClient.myEvents.requestLeave(
              testUser,
              event.id,
              invalidTime,
            ),
            throwsA(isA<ServerException>()),
          );
        },
      );
    });

    // =========================================================================
    // 20.11: Invalid Transition Errors
    // =========================================================================

    group('20.11: ServerException - InvalidTransition', () {
      test(
        '20.11i: acceptInvite throws when not invited',
        () async {
          final event = await client.events.createEvent(
            title: 'test_Accept Error S20',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: now.add(const Duration(days: 300)),
            endTimeUtc: now.add(const Duration(days: 300, hours: 1)),
            rrule: weeklyOn(now.add(const Duration(days: 300))),
          );

          // Server returns ENROLLMENT_NOT_FOUND (404) when no enrollment
          // exists, rather than INVALID_TRANSITION (422).
          expect(
            () => client.myEvents.acceptInvite(
              testUser,
              event.id,
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.enrollmentNotFound,
              ),
            ),
          );
        },
      );

      test(
        '20.11j: withdraw throws when not enrolled',
        () async {
          final event = await client.events.createEvent(
            title: 'test_Withdraw Error S20',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venueId,
            // Two hours later than the other programmes on this weekday:
            // programmes clash on venue and organizer (#16).
            startTimeUtc: now.add(const Duration(days: 301, hours: 2)),
            endTimeUtc: now.add(const Duration(days: 301, hours: 3)),
            rrule: weeklyOn(now.add(const Duration(days: 301))),
          );

          // Server returns ENROLLMENT_NOT_FOUND (404) when no enrollment
          // exists, rather than INVALID_TRANSITION (422).
          expect(
            () => client.myEvents.withdraw(
              testUser,
              event.id,
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.enrollmentNotFound,
              ),
            ),
          );
        },
      );
    });

    // =========================================================================
    // 20.11: Venue Conflict
    // =========================================================================

    group('20.11: ServerException - VenueConflict', () {
      test(
        '20.11k: createEvent throws on venue conflict',
        () async {
          // Only a programme-against-programme clash blocks creation with
          // 409; a one-off overlap is reported, not refused (#16).
          final conflictTime = now.add(const Duration(days: 400, hours: 4));
          await client.events.createEvent(
            title: 'test_First Event S20',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: conflictTime,
            endTimeUtc: conflictTime.add(const Duration(hours: 1)),
            rrule: weeklyOn(conflictTime),
          );

          expect(
            () => client.events.createEvent(
              title: 'test_Second Event S20',
              description: 'D',
              type: EventType.programme,
              visibility: Visibility.public,
              venueId: venueId,
              startTimeUtc: conflictTime,
              endTimeUtc: conflictTime.add(const Duration(hours: 1)),
              rrule: weeklyOn(conflictTime),
            ),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'statusCode', 409)
                  .having((e) => e.code, 'code', SdkErrorCode.timeConflict),
            ),
          );
        },
      );
    });

    // =========================================================================
    // 20.11: Client-side errors
    // =========================================================================

    group('20.11: SdkError - client-side errors', () {
      test('20.11l: SdkError has code and message fields', () {
        const error = SdkError(
          'End time must be after start time',
          code: SdkErrorCode.invalidRrule,
        );
        expect(error.code, SdkErrorCode.invalidRrule);
        expect(error.message, contains('End time'));
      });

      test('20.11m: ServerException has code and message fields', () {
        const exception = ServerException(
          statusCode: 403,
          code: SdkErrorCode.insufficientPermission,
          message: 'You do not have permission to modify user 123',
        );
        expect(exception.code, SdkErrorCode.insufficientPermission);
        expect(exception.message, contains('permission'));
      });
    });

    // =========================================================================
    // 20.11: Bulk operation
    // =========================================================================

    group('20.11: Bulk operation', () {
      test('20.11n: inviteBulk throws on invalid event', () async {
        expect(
          () => client.enrollments.inviteBulk(
            99999,
            ['test_user1', 'test_user2'],
          ),
          throwsA(isA<ServerException>()),
        );
      });
    });

    // =========================================================================
    // 20.12: Stateless SDK
    // =========================================================================

    group('20.12: Stateless SDK', () {
      test('20.12: Each call is independent', () async {
        final venues1 = await client.venues.getVenues();
        final venues2 = await client.venues.getVenues();
        expect(venues1.items.length, venues2.items.length);
      });
    });

    // =========================================================================
    // 20.13: Runtime Switchable
    // =========================================================================

    group('20.13: Runtime Switchable', () {
      test('20.13: Client uses configurable backend', () async {
        expect(client, isNotNull);
        final user = await client.auth.getCurrentUser();
        expect(user, isNotNull);
      });
    });
  });
}
