import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Programme Recurrence Tests
///
/// Focus: RRULE programme creation and configuration verification.
void main() {
  group('Programme Recurrence Tests', () {
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

      // Create venue
      final venue = await client.venues.createVenue(
        name: 'test_Training Court',
      );
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

    test('programme created with RRULE configuration', () async {
      // A programme's rule is weekly on the start's weekday and open-ended;
      // COUNT / UNTIL / INTERVAL are refused (INVALID_RRULE_FOR_PROGRAMME).
      final eventStart = dayAt(14);
      final eventEnd = dayAt(14, hour: 11);
      final rrule = weeklyOn(eventStart);

      final event = await client.events.createEvent(
        title: 'test_Weekly Training',
        description: 'Recurring training programme',
        type: EventType.programme,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: eventStart,
        endTimeUtc: eventEnd,
        rrule: rrule,
      );

      expect(event.type, EventType.programme);
      expect(event.rrule, rrule);
      expect(event.startTimeUtc, eventStart);
      expect(event.endTimeUtc, eventEnd);
      expect(event.title, 'test_Weekly Training');

      final retrieved = await client.events.getEvent(event.id);
      expect(retrieved.type, EventType.programme);
      expect(retrieved.rrule, rrule);

      final baseOccurrence = await client.occurrences.getOccurrence(
        event.id,
        eventStart,
      );
      expect(baseOccurrence.eventId, event.id);
      expect(baseOccurrence.originalStartTimeUtc, eventStart);
    });
  });
}
