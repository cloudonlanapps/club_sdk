// A clash on venue, organizer or coach is refused with 409
// SCHEDULE_CONFLICT and the report, whatever the event type
// (club_server#72, #56). `checkConflict` reports it beforehand; once the
// organizer re-sends with `acceptConflicts: true` the event is created and
// the admins are told as `event.conflict_detected`.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 7: The Double Booking Story
///
/// Focus: Venue, Coach, and Member conflict detection.
/// Enforcement: All times MUST be treated as UTC.
///
/// Steps:
/// 1. T0: Create Event A at Venue 'V1' from 10:00 to 11:00 UTC.
/// 2. T0: Assign Coach 'C1' to Event A.
/// 3. T0: Invite User 'U1' to Event A.
/// 4. T1: Create Event B at same Venue 'V1' from 10:30 to 11:30 UTC
///    (Overlaps A).
/// 5. T1: Try to assign same Coach 'C1' to Event B.
/// 6. T1: Try to invite/assign same User 'U1' to Event B.
/// 7. Verification: The system refuses B until the clash is accepted, and
///    reports the venue and organizer conflicts.
void main() {
  group('Workflow 7: The Double Booking Story', () {
    late SecureClient client;
    late int venueId1;
    late int venueId2;
    late int venueIdOther;

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

      // Register and approve coaches
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_c1',
        email: 'test_c1@test.com',
        password: 'password123',
        firstName: 'Coach One',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_c1', 'coach');

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_c2',
        email: 'test_c2@test.com',
        password: 'password123',
        firstName: 'Coach Two',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_c2', 'coach');

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

      // Create venues
      final v1 = await client.venues.createVenue(name: 'test_Venue 1');
      venueId1 = v1.id;
      final v2 = await client.venues.createVenue(name: 'test_Venue 2');
      venueId2 = v2.id;
      final vOther = await client.venues.createVenue(name: 'test_Other Venue');
      venueIdOther = vOther.id;

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

    test('Conflict Detection & UTC Enforcement', () async {
      // All times forced to UTC
      final eventAStart = DateTime.utc(2027, 3, 10, 10);
      final eventAEnd = DateTime.utc(2027, 3, 10, 11);

      const organizerName = 'test_c1';
      const username = 'test_u1';

      // --- T0: Event A Setup ---
      final eventA = await client.events.createEvent(
        title: 'test_Tennis A',
        description: 'Morning session',
        type: EventType.oneOff,
        venueId: venueId1,
        organizerName: organizerName,
        visibility: Visibility.public,
        startTimeUtc: eventAStart,
        endTimeUtc: eventAEnd,
      );

      await client.enrollments.invite(
        eventA.id,
        username,
      );

      // --- T1: Overlapping Event B ---
      final eventBStart = DateTime.utc(
        2027,
        3,
        10,
        10,
        30,
      ); // 30 min overlap with A
      final eventBEnd = DateTime.utc(2027, 3, 10, 11, 30);

      // Conflict detection: the overlap (Overlapping V1/T1) is reported
      // on both the venue and the organizer before anything is created.
      final bothReport = await client.events.checkConflict(
        type: EventType.oneOff,
        venueId: venueId1, // Same venue
        organizerName: organizerName, // Same coach
        startTimeUtc: eventBStart,
        endTimeUtc: eventBEnd,
      );
      expect(bothReport.hasConflict, isTrue);
      expect(
        bothReport.venueConflicts.map((c) => c.eventId),
        contains(eventA.id),
      );
      expect(
        bothReport.organizerConflicts.map((c) => c.eventId),
        contains(eventA.id),
      );

      // Same COACH but different venue: only the organizer clashes.
      final coachReport = await client.events.checkConflict(
        type: EventType.oneOff,
        venueId: venueIdOther,
        organizerName: organizerName, // Same coach
        startTimeUtc: eventBStart,
        endTimeUtc: eventBEnd,
      );
      expect(coachReport.hasConflict, isTrue);
      expect(coachReport.venueConflicts, isEmpty);
      expect(
        coachReport.organizerConflicts.map((c) => c.eventId),
        contains(eventA.id),
      );

      // A one-off overlap is refused with the report and nothing is
      // written (club_server#72, #56).
      final unreadBefore = await client.notifications.getUnreadCount();
      Future<Event> overlap({bool accept = false}) => client.events.createEvent(
        title: 'test_Tennis Coach Conflict',
        description: 'Same coach, different venue',
        type: EventType.oneOff,
        venueId: venueIdOther,
        organizerName: organizerName, // Same coach
        visibility: Visibility.public,
        startTimeUtc: eventBStart,
        endTimeUtc: eventBEnd,
        acceptConflicts: accept,
      );
      await expectLater(
        overlap(),
        throwsA(
          isA<ScheduleConflictException>().having(
            (e) => e.report.organizerConflicts.map((c) => c.eventId),
            'organizerConflicts',
            contains(eventA.id),
          ),
        ),
      );
      expect(
        (await client.events.listEvents()).items.map((e) => e.title),
        isNot(contains('test_Tennis Coach Conflict')),
      );

      // Accepted, it is created and reported to the admins as
      // event.conflict_detected.
      final overlapping = await overlap(accept: true);
      expect(overlapping.id, isNot(eventA.id));
      expect(
        await client.notifications.getUnreadCount(),
        greaterThan(unreadBefore),
        reason: 'the admin is told about the reported clash',
      );
      final notifications = await client.notifications.getNotifications(
        limit: 50,
      );
      expect(
        notifications.items.map((n) => n.type),
        contains(NotificationType.eventConflictDetected),
      );

      final allEvents = await client.events.listEvents();
      expect(allEvents.items.any((e) => e.id == overlapping.id), isTrue);
      expect(allEvents.items.any((e) => e.id == eventA.id), isTrue);

      // --- T2: Successful creation with different venue ---
      final eventB = await client.events.createEvent(
        title: 'test_Tennis B',
        description: 'Now in V2',
        type: EventType.oneOff,
        venueId: venueId2, // Different venue
        organizerName: 'test_c2', // Different coach
        visibility: Visibility.public,
        startTimeUtc: eventBStart,
        endTimeUtc: eventBEnd,
      );
      expect(eventB.id, isNot(eventA.id));

      await client.enrollments.invite(
        eventB.id,
        username,
      );

      // Verification: Check if both events are retrieved in lists
      final all = await client.events.listEvents();
      expect(all.items.any((e) => e.id == eventA.id), isTrue);
      expect(all.items.any((e) => e.id == eventB.id), isTrue);

      // Time verification
      expect(
        eventA.startTimeUtc.isUtc,
        isTrue,
        reason: 'Event A start time must be UTC',
      );
      expect(
        eventB.startTimeUtc.isUtc,
        isTrue,
        reason: 'Event B start time must be UTC',
      );

      // Deep property verification
      final occA = await client.occurrences.getOccurrence(
        eventA.id,
        eventAStart,
      );
      expect(occA.venueId, venueId1);
      expect(occA.organizerName, organizerName);

      final occB = await client.occurrences.getOccurrence(
        eventB.id,
        eventBStart,
      );
      expect(occB.venueId, venueId2);
      expect(occB.organizerName, 'test_c2');
    });
  });
}
