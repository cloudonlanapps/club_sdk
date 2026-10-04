import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Issue 25: optimistic locking on event edits (club_server#292).
void main() {
  group('Issue 25: event version', () {
    late SecureClient client;
    late int venueId;

    setUpAll(() async {
      client = await createTestClient();
      await client.auth.login(sudoUsername, sudoPassword);
      final venue = await client.venues.createVenue(name: 'test_Venue I25');
      venueId = venue.id;
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    test('Issue 25: a fresh event is version 1 and edits bump it', () async {
      final start = DateTime.now().toUtc().add(const Duration(days: 3));
      final event = await client.events.createEvent(
        title: 'test_I25 one-off',
        description: '',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
      expect(event.version, 1);

      final updated = await client.events.updateEvent(
        event.id,
        version: event.version,
        title: 'test_I25 renamed',
      );
      expect(updated.version, 2);
      expect(updated.updatedBy, sudoUsername);
    });

    test('Issue 25: a stale version is refused with the current one', () async {
      final start = DateTime.now().toUtc().add(const Duration(days: 4));
      final event = await client.events.createEvent(
        title: 'test_I25 stale',
        description: '',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
      final v2 = await client.events.updateEvent(
        event.id,
        version: 1,
        description: 'first edit',
      );
      expect(v2.version, 2);

      await expectLater(
        client.events.updateEvent(
          event.id,
          version: 1,
          description: 'edit from a stale load',
        ),
        throwsA(
          isA<StaleVersionException>()
              .having((e) => e.version, 'version', 2)
              .having((e) => e.updatedBy, 'updatedBy', sudoUsername)
              .having((e) => e.updatedAtUtc, 'updatedAtUtc', isNotNull),
        ),
      );

      // Nothing was written.
      final fetched = await client.events.getEvent(event.id);
      expect(fetched.description, 'first edit');
      expect(fetched.version, 2);
    });
  });
}
