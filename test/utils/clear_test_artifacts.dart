/// Cleans all test_ prefixed entities from the server.
///
/// Dart equivalent of `clean_test_entities.py`.
/// Performs soft-delete then hard-delete for every test_ entity found.
/// Reports errors without aborting.
///
/// Usage:
/// ```dart
/// final client = await createRemoteSecureClient(baseUrl: baseUrl);
/// await clearTestArtifacts(
///   client: client, username: 'sudo', password: 'testboot');
/// ```
library;

import 'dart:developer' as dev;

import 'package:club_sdk_2/club_sdk_2.dart';

const _prefix = 'test_';

/// Cleans all test_ prefixed entities from the server.
///
/// Authenticates as [username]/[password], then soft-deletes and hard-deletes
/// all events, groups, venues, and users whose identifiers start with `test_`.
///
/// Errors are logged but do not abort the cleanup.
Future<void> clearTestArtifacts({
  required SecureClient client,
  required String username,
  required String password,
}) async {
  await client.auth.login(username, password);

  _log('=== Cleaning test_ entities (as $username) ===');

  // --- Phase 1: Soft delete active entities ---
  _log('--- Phase 1: Soft Delete ---');

  // Events
  _log('[events]');
  try {
    final eventPage = await client.events.listEvents(
      limit: 100,
    );
    for (final event in eventPage.items) {
      if (event.title.startsWith(_prefix)) {
        await _fire(
          () => client.events.deleteEvent(event.id),
          'soft-delete event ${event.id} "${event.title}"',
        );
      }
    }
  } on Exception catch (e) {
    _log('  ERR listing events: $e');
  }

  // Groups
  _log('[groups]');
  try {
    final groups = await client.groups.getGroups(limit: 100);
    for (final group in groups.items) {
      if (group.name.startsWith(_prefix)) {
        await _fire(
          () => client.groups.deleteGroup(group.id),
          'soft-delete group ${group.id} "${group.name}"',
        );
      }
    }
  } on Exception catch (e) {
    _log('  ERR listing groups: $e');
  }

  // Venues
  _log('[venues]');
  try {
    final venues = await client.venues.getVenues(limit: 100);
    for (final venue in venues.items) {
      if (venue.name.startsWith(_prefix)) {
        await _fire(
          () => client.venues.deleteVenue(venue.id),
          'soft-delete venue ${venue.id} "${venue.name}"',
        );
      }
    }
  } on Exception catch (e) {
    _log('  ERR listing venues: $e');
  }

  // Users (skip self)
  _log('[users]');
  // `GET /users` omits `registered` users unless asked for them by status,
  // so a sign-up that never reached review would survive every cleanup and
  // block the next seed with DUPLICATE_USERNAME. Sweep each status.
  for (final status in UserStatus.values) {
    try {
      var offset = 0;
      const batchSize = 50;
      while (true) {
        final page = await client.users.getUsers(
          searchTerm: _prefix,
          status: status,
          limit: batchSize,
          offset: offset,
        );
        if (page.items.isEmpty) break;
        for (final user in page.items) {
          if (user.username.startsWith(_prefix) && user.username != username) {
            await _fire(
              () => client.users.deleteUser(user.username),
              'soft-delete user "${user.username}" (was ${user.status.name})',
            );
          }
        }
        if (page.items.length < batchSize) break;
        offset += batchSize;
      }
    } on Exception catch (e) {
      _log('  ERR listing ${status.name} users: $e');
    }
  }

  // --- Phase 2: Hard delete (soft-deleted items via /deleted endpoint) ---
  _log('--- Phase 2: Hard Delete ---');

  // Events
  _log('[events]');
  try {
    final deletedEvents = (await client.events.listDeletedEvents(
      limit: 100,
    )).items;
    for (final event in deletedEvents) {
      if (event.title.startsWith(_prefix)) {
        await _fire(
          () => client.events.hardDeleteEvent(event.id),
          'hard-delete event ${event.id} "${event.title}"',
        );
      }
    }
  } on Exception catch (e) {
    _log('  ERR listing deleted events: $e');
  }

  // Groups
  _log('[groups]');
  try {
    final deletedGroups = await client.groups.getDeletedGroups(limit: 100);
    for (final group in deletedGroups.items) {
      if (group.name.startsWith(_prefix)) {
        await _fire(
          () => client.groups.hardDeleteGroup(group.id),
          'hard-delete group ${group.id} "${group.name}"',
        );
      }
    }
  } on Exception catch (e) {
    _log('  ERR listing deleted groups: $e');
  }

  // Venues
  _log('[venues]');
  try {
    final deletedVenues = await client.venues.getDeletedVenues(limit: 100);
    for (final venue in deletedVenues.items) {
      if (venue.name.startsWith(_prefix)) {
        await _fire(
          () => client.venues.hardDeleteVenue(venue.id),
          'hard-delete venue ${venue.id} "${venue.name}"',
        );
      }
    }
  } on Exception catch (e) {
    _log('  ERR listing deleted venues: $e');
  }

  // Users
  _log('[users]');
  try {
    final deletedUsers = await client.users.getDeletedUsers(limit: 100);
    for (final user in deletedUsers.items) {
      if (user.username.startsWith(_prefix)) {
        await _fire(
          () => client.users.hardDeleteUser(user.username),
          'hard-delete user "${user.username}"',
        );
      }
    }
  } on Exception catch (e) {
    _log('  ERR listing deleted users: $e');
  }

  _log('=== Done ===');

  await client.auth.logout();
}

/// Fire an async action, log success or error.
Future<void> _fire(Future<void> Function() action, String label) async {
  try {
    await action();
    _log('  OK   $label');
  } on Exception catch (e) {
    _log('  ERR  $label -> $e');
  }
}

void _log(String message) {
  // Intentional print for console visibility during cleanup operations.
  // print('[ClearArtifacts] $message');
  dev.log(message, name: 'ClearTestArtifacts');
}
