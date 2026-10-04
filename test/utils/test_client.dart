/// Shared test client factory for integration tests.
///
/// Provides [createTestClient] which handles cleanup and seeding on first
/// use. Each test file imports this and uses it in setUp.
library;

import 'dart:convert';
import 'dart:io';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';

import 'clear_test_artifacts.dart';
import 'mock_seed_data.dart';
import 'seed_test_data.dart';

/// Base URL for the test server.
/// Override via environment variable MYCLUB_API_BASE_URL if needed.
final String baseUrl =
    Platform.environment['MYCLUB_API_BASE_URL'] ?? 'http://localhost:8155/v1';
final String sudoUsername =
    Platform.environment['MYCLUB_SUDO_USERNAME'] ?? 'sudo';
final String sudoPassword =
    Platform.environment['MYCLUB_SUDO_PASSWORD'] ?? 'testboot';

/// Flag to track if cleanup + seeding has been done for this test run.
bool _initialized = false;

/// Path to the JSON seed data directory.
/// dart test runs from the package root, so Directory.current is club_sdk_2/.
final _jsonDir = '${Directory.current.path}/test/utils/json';

/// Creates a test SecureClient connected to the remote server.
///
/// If [seedTestData] is true (default), ensures test data is cleaned up
/// and re-seeded. This only happens once per test run since tests share
/// the database.
Future<SecureClient> createTestClient({bool seedTestData = true}) async {
  final client = await createRemoteSecureClient(baseUrl: baseUrl);

  if (seedTestData && !_initialized) {
    await _initializeTestData(client);
    _initialized = true;
  }

  return client;
}

/// Cleans the database and seeds all test data from JSON files.
Future<void> _initializeTestData(SecureClient client) async {
  // Step 1: Clean all test_ artifacts
  await clearTestArtifacts(
    client: client,
    username: sudoUsername,
    password: sudoPassword,
  );

  // Step 2: Seed in order — users, venues, groups
  await _seedFromJson(client, EntityType.user, '$_jsonDir/users.json');
  await _seedFromJson(client, EntityType.venue, '$_jsonDir/venues.json');
  await _populateVenueIds(client);
  await _seedFromJson(client, EntityType.group, '$_jsonDir/groups.json');
}

/// Reads a JSON array file and calls [seed] for each item.
Future<void> _seedFromJson(
  SecureClient client,
  EntityType entityType,
  String filePath, {
  String? username,
  String? password,
}) async {
  final jsonString = File(filePath).readAsStringSync();
  final items = json.decode(jsonString) as List<dynamic>;

  final seedUsername = username ?? sudoUsername;
  final seedPassword = password ?? sudoPassword;

  for (final item in items) {
    await seed(
      client: client,
      username: seedUsername,
      password: seedPassword,
      entityType: entityType,
      seedJson: json.encode(item),
    );
  }
}

/// Populates the global [venueIds] map from mock_seed_data.dart.
Future<void> _populateVenueIds(SecureClient client) async {
  await client.auth.login(sudoUsername, sudoPassword);

  final venues = await client.venues.getVenues(limit: 100);
  venueIds.clear();
  for (final venue in venues.items) {
    if (venue.name.startsWith(testPrefix)) {
      venueIds[venue.name] = venue.id;
    }
  }

  await client.auth.logout();
}
