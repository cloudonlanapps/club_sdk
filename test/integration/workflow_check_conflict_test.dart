import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// `checkConflict` query API tests, camp-shaped.
///
/// The endpoint accepts a full schedule of any type (#16) and returns
/// per-actor (venue / organizer / coach) overlap reports for the expanded
/// occurrences. Camps stay inside the 52-week scheduling horizon.
void main() {
  group('Check Conflict (camp) Tests', () {
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
        username: 'test_admin_1',
        email: 'test_admin_1@test.com',
        password: 'password123',
        firstName: 'Admin One',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_admin_1', 'admin');

      final venue = await client.venues.createVenue(name: 'test_Main Court');
      venueId = venue.id;

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

    test('detects venue conflict for overlapping camp occurrences', () async {
      final start = DateTime.utc(2027, 3, 15, 10);
      final end = DateTime.utc(2027, 3, 15, 12);
      final until = DateTime.utc(2027, 3, 19, 12);

      await client.events.createEvent(
        title: 'test_Camp Existing',
        description: 'Existing camp',
        type: EventType.camp,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: start,
        endTimeUtc: end,
        rrule: 'FREQ=DAILY;COUNT=5',
      );

      final report = await client.events.checkConflict(
        type: EventType.camp,
        venueId: venueId,
        startTimeUtc: start.add(const Duration(hours: 1)),
        endTimeUtc: end.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=5',
        untilTimeUtc: until,
      );

      expect(report.hasConflict, isTrue);
      expect(report.venueConflicts, isNotEmpty);
      expect(report.venueConflicts.first.occurrences, isNotEmpty);
    });

    test('no conflict for non-overlapping camp', () async {
      final start = DateTime.utc(2027, 4, 1, 9);
      final end = DateTime.utc(2027, 4, 1, 11);

      final report = await client.events.checkConflict(
        type: EventType.camp,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: end,
        rrule: 'FREQ=DAILY;COUNT=3',
        untilTimeUtc: DateTime.utc(2027, 4, 3, 11),
      );

      expect(report.hasConflict, isFalse);
      expect(report.venueConflicts, isEmpty);
      expect(report.organizerConflicts, isEmpty);
      expect(report.coachConflicts, isEmpty);
    });
  });
}
