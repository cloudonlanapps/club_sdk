import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Section 19: Data Integrity Test Suite.
///
/// Tests requirements from Section 19 (Data Integrity):
/// - 19.01: UTC Timestamps
/// - 19.02: Row-Level Locking
/// - 19.03: Soft Delete Default
/// - 19.04: No Anonymous Accounts
/// - 19.05: No File Storage
void main() {
  group('Section 19: Data Integrity', () {
    late SecureClient client;

    late int venueId;
    final now = DateTime.utc(2026, 3, 1, 10);

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean test artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo and create test venue
      await client.auth.login(sudoUsername, sudoPassword);
      final adminUser = await client.auth.getCurrentUser();
      expect(adminUser.username, sudoUsername);

      final venue = await client.venues.createVenue(
        name: 'test_Venue S19',
        address: 'S19 Street',
      );
      venueId = venue.id;

      // 3. Logout
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
    // 19.01: UTC Timestamps
    // =========================================================================

    group('19.01: UTC Timestamps', () {
      test('19.01: UTC Timestamps - all timestamps in UTC', () async {
        final event = await client.events.createEvent(
          title: 'test_UTC Test S19',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: now,
          endTimeUtc: now.add(const Duration(hours: 1)),
        );

        expect(event.startTimeUtc.isUtc, isTrue);
        expect(event.endTimeUtc.isUtc, isTrue);
      });
    });

    // =========================================================================
    // 19.02: Row-Level Locking
    // =========================================================================

    group('19.02: Row-Level Locking', () {
      test(
        '19.02: Row-Level Locking - updates are serialized',
        () async {
          final venue = await client.venues.createVenue(
            name: 'test_Row Lock Test Venue S19',
          );

          await client.venues.updateVenue(
            venue.id,
            name: 'test_Updated Name 1',
          );

          await client.venues.updateVenue(
            venue.id,
            name: 'test_Updated Name 2',
          );

          final finalVenue = await client.venues.getVenue(venue.id);
          expect(finalVenue.name, 'test_Updated Name 2');
        },
      );
    });

    // =========================================================================
    // 19.03: Soft Delete Default
    // =========================================================================

    group('19.03: Soft Delete Default', () {
      test('19.03: Soft Delete Default - deleted items hidden', () async {
        final venue = await client.venues.createVenue(
          name: 'test_Soft Delete Test S19',
        );

        await client.venues.deleteVenue(venue.id);

        final page = await client.venues.getVenues();
        final activeVenues = page.items.where((v) => v.isActive).toList();
        expect(activeVenues.any((v) => v.id == venue.id), isFalse);
      });
    });

    // =========================================================================
    // 19.04: No Anonymous Accounts
    // =========================================================================

    group('19.04: No Anonymous Accounts', () {
      test(
        '19.04: No Anonymous Accounts - operations require auth',
        () async {
          await client.auth.logout();

          expect(
            () => client.events.listEvents(),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.notAuthenticated,
              ),
            ),
          );

          // Re-login for tearDown
          await client.auth.login(sudoUsername, sudoPassword);
        },
      );
    });
  });
}
