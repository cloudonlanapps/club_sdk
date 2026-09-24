import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 21: Concurrency Test Suite.
///
/// Tests requirements from Section 21 (Concurrency):
/// - 21.01: Event Version Field
/// - 21.02: Auto-Increment Version
/// - 21.03: Version Required for Updates
/// - 21.04: Version Validation
/// - 21.05: OptimisticLockException
/// - 21.06: Version Not in copyWith
/// - 21.07: Version Survives Split
/// - 21.08: Enrollment Methods Excluded
/// - 21.09: HTTP 409 Conflict
/// - 21.10: Retry Pattern
///
/// Optimistic locking is club_server#292 / SDK #25: every event carries a
/// `version`, the edit paths (update, correction, split) require it and a
/// stale one is refused with 409 `STALE_VERSION` (`StaleVersionException`).
void main() {
  group('Section 21: Concurrency', () {
    late SecureClient client;
    late int venueId;

    final now = DateTime.utc(2027, 3, 1, 10);

    const alice = 'test_alice_s21';
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

      // 3. Create venue
      final venue = await client.venues.createVenue(
        name: 'test_Venue S21',
        address: 'S21 Street',
      );
      venueId = venue.id;

      // 4. Register and approve alice
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: alice,
        email: '$alice@test.com',
        password: password,
        firstName: 'Alice S21',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // 5. Logout
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

    /// A one-off in its own day slot, inside the horizon.
    var slot = 0;
    Future<Event> oneOff(String title) {
      final start = now.add(Duration(days: 5 + slot++));
      return client.events.createEvent(
        title: title,
        description: 'D',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
    }

    group('21.01: Event Version Field', () {
      test('21.01: Event Version Field - events have version', () async {
        final event = await oneOff('test_Version Field S21');
        expect(event.version, 1);
        expect(event.updatedBy, sudoUsername);
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.version, 1);
      });
    });

    group('21.02: Auto-Increment Version', () {
      test(
        '21.02: Auto-Increment Version - version increases on update',
        () async {
          final event = await oneOff('test_Auto Increment S21');
          final v2 = await client.events.updateEvent(
            event.id,
            version: event.version,
            title: 'test_Auto Increment S21 v2',
          );
          expect(v2.version, event.version + 1);
          final v3 = await client.events.updateEvent(
            event.id,
            version: v2.version,
            description: 'third',
          );
          expect(v3.version, v2.version + 1);
        },
      );
    });

    group('21.03: Version Required for Updates', () {
      test(
        '21.03: Version Required for Updates - must provide version',
        () async {
          // The SDK makes `version` a required argument on every edit path
          // (update, correction, split); the server refuses a body without
          // it with 422. Each path bumps the version it was given.
          final event = await oneOff('test_Version Required S21');
          final updated = await client.events.updateEvent(
            event.id,
            version: event.version,
            title: 'test_Version Required S21 v2',
          );
          expect(updated.version, 2);

          final pStart = now.add(const Duration(days: 40));
          final programme = await client.events.createEvent(
            title: 'test_Version Required S21 programme',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: pStart,
            endTimeUtc: pStart.add(const Duration(hours: 1)),
            rrule: weeklyOn(pStart),
          );
          final corrected = await client.events.correctionOnEvent(
            programme.id,
            version: programme.version,
            title: 'test_Version Required S21 programme v2',
          );
          expect(corrected.version, programme.version + 1);
          final split = await client.events.updateEventForAllFuture(
            programme.id,
            version: corrected.version,
            effectiveDateTimeUtc: pStart.add(const Duration(days: 14)),
            coachNames: () => [alice],
          );
          expect(split.version, corrected.version + 1);
        },
      );
    });

    group('21.04: Version Validation', () {
      test('21.04: Version Validation - rejects stale version', () async {
        final event = await oneOff('test_Version Validation S21');
        await client.events.updateEvent(
          event.id,
          version: event.version,
          title: 'test_Version Validation S21 v2',
        );
        await expectLater(
          client.events.updateEvent(
            event.id,
            version: event.version,
            title: 'test_Version Validation S21 stale',
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having((e) => e.code, 'code', SdkErrorCode.staleVersion),
          ),
        );
        final fetched = await client.events.getEvent(event.id);
        expect(fetched.title, 'test_Version Validation S21 v2');
        expect(fetched.version, 2);
      });
    });

    group('21.05: OptimisticLockException', () {
      test('21.05: OptimisticLockException - thrown on conflict', () async {
        final event = await oneOff('test_Lock Exception S21');
        final current = await client.events.updateEvent(
          event.id,
          version: event.version,
          description: 'moved on',
        );
        await expectLater(
          client.events.updateEvent(
            event.id,
            version: event.version,
            description: 'from a stale load',
          ),
          throwsA(
            isA<StaleVersionException>()
                .having((e) => e.version, 'version', current.version)
                .having((e) => e.updatedBy, 'updatedBy', sudoUsername)
                .having((e) => e.updatedAtUtc, 'updatedAtUtc', isNotNull),
          ),
        );
      });
    });

    group('21.06: Version Not in copyWith', () {
      test(
        '21.06: Version Not in copyWith - version unchanged by copyWith',
        () async {
          final event = await oneOff('test_CopyWith S21');
          final local = event.copyWith(title: 'test_CopyWith S21 local');
          expect(local.version, event.version);
          // A local edit does not move the server's version either.
          final fetched = await client.events.getEvent(event.id);
          expect(fetched.version, event.version);
          // The copy still carries the version the server accepts.
          final updated = await client.events.updateEvent(
            event.id,
            version: local.version,
            title: local.title,
          );
          expect(updated.title, 'test_CopyWith S21 local');
        },
      );
    });

    group('21.07: Version Survives Split', () {
      test(
        '21.07: Version Survives Split - new event chain has version',
        () async {
          // A split keeps the event (#16): the same id continues with a
          // bumped version and a second schedule.
          final pStart = now.add(const Duration(days: 41));
          final programme = await client.events.createEvent(
            title: 'test_Split Version S21',
            description: 'D',
            type: EventType.programme,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: pStart,
            endTimeUtc: pStart.add(const Duration(hours: 1)),
            rrule: weeklyOn(pStart),
          );
          final cutoff = pStart.add(const Duration(days: 7));
          final split = await client.events.updateEventForAllFuture(
            programme.id,
            version: programme.version,
            effectiveDateTimeUtc: cutoff,
            startTimeUtc: cutoff.add(const Duration(hours: 1)),
            endTimeUtc: cutoff.add(const Duration(hours: 2)),
          );
          expect(split.id, programme.id);
          expect(split.version, programme.version + 1);
          final schedules = await client.events.listSchedules(programme.id);
          expect(schedules, hasLength(2));
          // The pre-split version is now stale.
          await expectLater(
            client.events.correctionOnEvent(
              programme.id,
              version: programme.version,
              title: 'test_Split Version S21 stale',
            ),
            throwsA(isA<StaleVersionException>()),
          );
          final renamed = await client.events.correctionOnEvent(
            programme.id,
            version: split.version,
            title: 'test_Split Version S21 renamed',
          );
          expect(renamed.version, split.version + 1);
        },
      );
    });

    // =========================================================================
    // 21.08: Enrollment Methods Excluded (the only testable requirement)
    // =========================================================================

    group('21.08: Enrollment Methods Excluded', () {
      test(
        '21.08: Enrollment operations work without version',
        () async {
          final event = await client.events.createEvent(
            title: 'test_Enrollment Test S21',
            description: 'D',
            type: EventType.oneOff,
            visibility: Visibility.public,
            venueId: venueId,
            startTimeUtc: now.add(const Duration(days: 5)),
            endTimeUtc: now.add(const Duration(days: 5, hours: 1)),
          );

          await client.enrollments.assign(
            event.id,
            alice,
          );

          final enrollments = await client.enrollments.listEnrollments(
            event.id,
          );
          expect(enrollments[alice], EnrollmentStatus.assigned);
        },
      );
    });

    group('21.09: HTTP 409 Conflict', () {
      test(
        '21.09: HTTP 409 Conflict - remote returns 409',
        skip: 'Requires HTTP response testing',
        () async {},
      );
    });

    group('21.10: Retry Pattern', () {
      test(
        '21.10: Retry Pattern - supports retry on conflict',
        skip: 'Retry pattern not implemented',
        () async {},
      );
    });
  });
}
