/// Shared test data constants and venue ID helpers.
///
/// Seed data itself lives in JSON files under test/utils/json/.
/// This file provides runtime state (venue ID mapping) and constants
/// used across test suites.
library;

/// Prefix applied to all test-created entity identifiers (usernames, venue
/// names, event titles, group names). The cleanup function deletes entities
/// matching this prefix before each run.
const testPrefix = 'test_';

/// Map of venue names to their auto-generated IDs.
/// Populated by the test runner after venues are created.
/// Tests should use [getVenueId] to get venue IDs.
Map<String, int> venueIds = {};

/// Get venue ID by name. Throws if venue not found.
int getVenueId(String name) {
  final id = venueIds[name];
  if (id == null) {
    throw StateError(
      'Venue not found: $name. Available: ${venueIds.keys.join(', ')}',
    );
  }
  return id;
}

/// Old string ID to venue name mapping for backward compatibility.
/// Tests should migrate from string IDs to using [getVenueId] with venue names.
const oldIdToName = <String, String>{
  'v-1': 'test_Main Stadium',
  'v-2': 'test_Training Ground 2',
  'v1': 'test_Venue 1',
  'v2': 'test_Venue 2',
  'v3': 'test_Venue 3',
  'v4': 'test_Venue 4',
  'v5': 'test_Venue 5',
  'v_spec': 'test_Special Venue',
  'v-conflict': 'test_Conflict Venue',
  'v-conflict-upd': 'test_Conflict Update Venue',
  'v-safe': 'test_Safe Venue',
  'venue-1': 'test_Venue One',
  'venue-2': 'test_Venue Two',
  'forest_camp': 'test_Forest Camp',
  'v-other': 'test_Other Venue',
};

/// Helper to get venue ID by old string ID (for migration).
/// Converts old string IDs like 'v1' to integer IDs.
int v(String oldId) => getVenueId(oldIdToName[oldId] ?? oldId);
