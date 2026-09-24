// Calendar workflow: uses fromTimeUtc/toTimeUtc filters on listEvents and
// listMyEvents to verify past/upcoming event separation. Server enforces
// max 24h session duration.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 5: The Yearly Calendar Cycle
///
/// Focus: EventFilter.pastEvents and broad date range handling.
void main() {
  group('Workflow 5: The Yearly Calendar Cycle', () {
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

      // Register and approve admin user
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_admin_1',
        email: 'test_admin_1@test.com',
        password: 'password123',
        firstName: 'Admin One',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_admin_1', 'admin');

      // Register and approve member user
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_u1',
        email: 'test_u1@test.com',
        password: 'password123',
        firstName: 'User One',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // Create venue
      final venue = await client.venues.createVenue(name: 'test_Venue WF5');
      venueId = venue.id;

      // Credit gates programme enrollment where the module is on
      // (#38); a no-op where it is off.
      await seedEnrolmentCreditIfGated(client, ['test_admin_1', 'test_u1']);

      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login('test_admin_1', 'password123');
      final user = await client.auth.getCurrentUser();
      expect(user.username, 'test_admin_1');
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // Not logged in — ignore
      }
    });

    test('Yearly Filtering Logic with Mid-Year Reference', () async {
      final t0 = DateTime.utc(2027, 6, 1, 12); // Mid-year

      // Server enforces max 24h session duration. Use same-day
      // session times + rrule for multi-day events.
      final janStart = DateTime.utc(2027, 1, 10, 9);
      final janEnd = DateTime.utc(2027, 1, 10, 17);

      final juneStart = DateTime.utc(2027, 6, 10, 9);
      final juneEnd = DateTime.utc(2027, 6, 10, 17);

      final decStart = DateTime.utc(2027, 12, 1, 9);
      final decEnd = DateTime.utc(2027, 12, 1, 17);

      const username = 'test_u1';

      // --- Create Events ---
      final eventJan = await client.events.createEvent(
        title: 'test_Winter Survival',
        description: 'Jan camp',
        type: EventType.camp,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: janStart,
        endTimeUtc: janEnd,
        rrule: 'FREQ=DAILY;COUNT=3',
      );

      final eventJune = await client.events.createEvent(
        title: 'test_Summer Solstice',
        description: 'June session',
        type: EventType.oneOff,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: juneStart,
        endTimeUtc: juneEnd,
      );

      final eventDec = await client.events.createEvent(
        title: 'test_End of Year Review',
        description: 'Dec programme',
        type: EventType.programme,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: decStart,
        endTimeUtc: decEnd,
        rrule: weeklyOn(decStart),
      );

      // --- Enroll User ---
      for (final e in [eventJan, eventJune, eventDec]) {
        await client.enrollments.assign(
          e.id,
          username,
        );
      }

      // --- Verification at T0 ---

      // 1. Past Events (Jan) — use listEvents with time range filter
      final past = await client.events.listEvents(
        toTimeUtc: t0,
      );
      expect(
        past.items.any((e) => e.id == eventJan.id),
        isTrue,
        reason: 'Jan event should be in past',
      );
      expect(
        past.items.any((e) => e.id == eventJune.id),
        isFalse,
        reason: 'June event is NOT in past',
      );
      expect(past.items.any((e) => e.id == eventDec.id), isFalse);

      // 2. My Events (Upcoming: June & Dec)
      final my = await client.myEvents.listMyEvents(
        username,
        fromTimeUtc: t0,
      );
      expect(
        my.items.any((e) => e.id == eventJune.id),
        isTrue,
        reason: 'June event should be in upcoming MyEvents',
      );
      expect(
        my.items.any((e) => e.id == eventDec.id),
        isTrue,
        reason: 'Dec event should be in upcoming MyEvents',
      );
      expect(
        my.items.any((e) => e.id == eventJan.id),
        isFalse,
        reason: 'Past event usually not in active MyEvents',
      );

      // --- 3. Property Deep Check (Jan) ---
      final occJan = await client.occurrences.getOccurrence(
        eventJan.id,
        janStart,
      );
      expect(occJan.eventId, eventJan.id);
      expect(occJan.actualEndTimeUtc.isBefore(t0), isTrue);

      // --- 4. Property Deep Check (Dec) ---
      final occDec = await client.occurrences.getOccurrence(
        eventDec.id,
        decStart,
      );
      expect(occDec.status, OccurrenceStatus.scheduled);
      expect(occDec.actualStartTimeUtc.isAfter(t0), isTrue);
    });
  });
}
