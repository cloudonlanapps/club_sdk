import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Section 6: Venues Test Suite.
///
/// Tests requirements from Section 6 (Venues):
/// - 6.01: Create Venue
/// - 6.02: Update Venue
/// - 6.03: Delete Venue
/// - 6.04: List Venues
/// - 6.05: Get Venue by ID
/// - 6.06: Get Public Venues
///
/// VenueSource coverage:
/// - [`x`] getVenues
/// - [`x`] getVenue
/// - [`x`] createVenue
/// - [`x`] updateVenue
/// - [`x`] deleteVenue
/// - [ ] getDeletedVenues (covered in s02)
/// - [ ] restoreVenue (covered in s02)
/// - [ ] hardDeleteVenue (covered in s02)
void main() {
  group('Section 6: Venues', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean all test_ artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to clean state for the file
      await client.auth.login(sudoUsername, sudoPassword);
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

    group('6.01: Create Venue', () {
      test('creates venue with required fields', () async {
        final venue = await client.venues.createVenue(
          name: 'test_Test Venue 601',
          address: '123 Test Street',
        );

        expect(venue.id, isPositive);
        expect(venue.name, 'test_Test Venue 601');
        expect(venue.address, '123 Test Street');

        // Double-verify via query
        final fetched = await client.venues.getVenue(venue.id);
        expect(fetched.name, 'test_Test Venue 601');
      });

      test('with all optional fields', () async {
        final venue = await client.venues.createVenue(
          name: 'test_Full Venue 601',
          address: '456 Full Street',
          description: 'A complete venue',
          mapUri: 'https://maps.example.com/venue',
          isDefault: true,
          isFeatured: true,
        );

        expect(venue.name, 'test_Full Venue 601');
        expect(venue.description, 'A complete venue');
        expect(venue.isDefault, isTrue);
        expect(venue.isFeatured, isTrue);
      });

      test('IDs are auto-generated', () async {
        final venue = await client.venues.createVenue(
          name: 'test_Custom ID Venue',
        );

        expect(venue.id, greaterThan(0));

        final fetched = await client.venues.getVenue(venue.id);
        expect(fetched.name, 'test_Custom ID Venue');
      });
    });

    group('6.02: Update Venue', () {
      test('modifies name', () async {
        final created = await client.venues.createVenue(
          name: 'test_Original Venue 602',
        );

        final updated = await client.venues.updateVenue(
          created.id,
          name: 'test_Updated Venue 602',
        );

        expect(updated.name, 'test_Updated Venue 602');

        // Double-verify
        final fetched = await client.venues.getVenue(created.id);
        expect(fetched.name, 'test_Updated Venue 602');
      });

      test('modifies optional fields', () async {
        final created = await client.venues.createVenue(
          name: 'test_Venue 602b',
        );

        final updated = await client.venues.updateVenue(
          created.id,
          address: () => 'New Address',
          description: () => 'New Description',
        );

        expect(updated.address, 'New Address');
        expect(updated.description, 'New Description');
      });

      test('sets isDefault flag', () async {
        final created = await client.venues.createVenue(
          name: 'test_Default Venue 602',
        );

        final updated = await client.venues.updateVenue(
          created.id,
          isDefault: true,
        );

        expect(updated.isDefault, isTrue);
      });
    });

    group('6.03: Delete Venue', () {
      test('soft deletes venue', () async {
        final created = await client.venues.createVenue(
          name: 'test_Delete Venue 603',
        );

        await client.venues.deleteVenue(created.id);

        // Verify absent from active list
        final activeVenues = await client.venues.getVenues(limit: 100);
        expect(
          activeVenues.items.any((v) => v.id == created.id),
          isFalse,
        );
      });

      test('fails if events reference it', () async {
        final venue = await client.venues.createVenue(
          name: 'test_Referenced Venue 603',
        );

        await client.events.createEvent(
          title: 'test_Event at Venue 603',
          description: 'Test event',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue.id,
          startTimeUtc: DateTime.now().add(const Duration(days: 7)),
          endTimeUtc: DateTime.now().add(const Duration(days: 7, hours: 2)),
        );

        expect(
          () => client.venues.deleteVenue(venue.id),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.venueHasEvents,
            ),
          ),
        );
      });
    });

    group('6.04: List Venues', () {
      test('returns paginated list', () async {
        await client.venues.createVenue(name: 'test_List Venue 604a');
        await client.venues.createVenue(name: 'test_List Venue 604b');

        final page1 = await client.venues.getVenues(limit: 1);
        expect(page1.items.length, 1);

        final page2 = await client.venues.getVenues(limit: 1, offset: 1);
        expect(page2.items.isNotEmpty, isTrue);
      });
    });

    group('6.05: Get Venue by ID', () {
      test('returns venue details', () async {
        final created = await client.venues.createVenue(
          name: 'test_Get Venue 605',
          address: '605 Test Ave',
        );

        final fetched = await client.venues.getVenue(created.id);

        expect(fetched.id, created.id);
        expect(fetched.name, 'test_Get Venue 605');
        expect(fetched.address, '605 Test Ave');
      });

      test('throws for non-existent venue', () async {
        expect(
          () => client.venues.getVenue(999999),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('6.06: Get Public Venues', () {
      test('returns active venues', () async {
        await client.venues.createVenue(
          name: 'test_Public Venue 606',
        );

        final page = await client.venues.getVenues();
        expect(
          page.items.any((v) => v.name == 'test_Public Venue 606'),
          isTrue,
        );
      });

      test('excludes deleted venues', () async {
        final venue = await client.venues.createVenue(
          name: 'test_Deleted Venue 606',
        );
        await client.venues.deleteVenue(venue.id);

        final page = await client.venues.getVenues(limit: 100);
        expect(
          page.items.any((v) => v.id == venue.id),
          isFalse,
        );
      });
    });
  });
}
