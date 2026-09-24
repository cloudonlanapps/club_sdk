/// Dumps all soft-deleted entities from the server.
///
/// Dart equivalent of `dump_deleted.py`.
/// Uses /deleted endpoints for each resource type.
/// Use `dumpEntities` to see active entities.
///
/// Usage:
/// ```dart
/// final client = await createRemoteSecureClient(baseUrl: baseUrl);
/// await dumpDeletedEntities(
///   client: client, username: 'sudo', password: 'testboot');
/// ```
library;

import 'dart:developer' as dev;

import 'package:club_sdk_2/club_sdk_2.dart';

const _prefix = 'test_';
final String _separator = '=' * 70;

/// Dumps all soft-deleted entities from the server.
///
/// Authenticates as [username]/[password], fetches all soft-deleted users,
/// venues, events, and groups, then prints them in a table-like format.
/// Returns a summary map with counts of test_ entities.
Future<Map<String, int>> dumpDeletedEntities({
  required SecureClient client,
  required String username,
  required String password,
}) async {
  await client.auth.login(username, password);

  // Fetch all deleted entities
  final users = await _getAllDeletedUsers(client);
  final venues = await _getAllDeletedVenues(client);
  final events = await client.events.listDeletedEvents(limit: 100);
  final groups = await _getAllDeletedGroups(client);

  // Print sections
  _printUserSection('USERS (soft-deleted)', users);
  _printVenueSection('VENUES (soft-deleted)', venues);
  _printEventSection('EVENTS (soft-deleted)', events);
  _printGroupSection('GROUPS (soft-deleted)', groups);

  // Count test_ entities
  final testUsers = users.where((u) => u.username.startsWith(_prefix)).length;
  final testVenues = venues.where((v) => v.name.startsWith(_prefix)).length;
  final testEvents = events.where((e) => e.title.startsWith(_prefix)).length;
  final testGroups = groups.where((g) => g.name.startsWith(_prefix)).length;

  _log(_separator);
  _log(' SUMMARY: soft-deleted test_ entities');
  _log(_separator);
  _log('  test_ users:  $testUsers');
  _log('  test_ venues: $testVenues');
  _log('  test_ events: $testEvents');
  _log('  test_ groups: $testGroups');
  _log('');

  await client.auth.logout();

  return {
    'users': testUsers,
    'venues': testVenues,
    'events': testEvents,
    'groups': testGroups,
  };
}

/// Paginates through all deleted users.
Future<List<UserInfo>> _getAllDeletedUsers(SecureClient client) async {
  final all = <UserInfo>[];
  var offset = 0;
  const limit = 100;
  while (true) {
    final page = await client.users.getDeletedUsers(
      offset: offset,
      limit: limit,
    );
    all.addAll(page.items);
    if (page.items.length < limit) break;
    offset += limit;
  }
  return all;
}

/// Paginates through all deleted venues.
Future<List<Venue>> _getAllDeletedVenues(SecureClient client) async {
  final all = <Venue>[];
  var offset = 0;
  const limit = 100;
  while (true) {
    final page = await client.venues.getDeletedVenues(
      offset: offset,
      limit: limit,
    );
    all.addAll(page.items);
    if (page.items.length < limit) break;
    offset += limit;
  }
  return all;
}

/// Paginates through all deleted groups.
Future<List<Group>> _getAllDeletedGroups(SecureClient client) async {
  final all = <Group>[];
  var offset = 0;
  const limit = 100;
  while (true) {
    final page = await client.groups.getDeletedGroups(
      offset: offset,
      limit: limit,
    );
    all.addAll(page.items);
    if (page.items.length < limit) break;
    offset += limit;
  }
  return all;
}

void _printUserSection(String title, List<UserInfo> users) {
  _log(_separator);
  _log(' $title (${users.length} total)');
  _log(_separator);
  if (users.isEmpty) {
    _log('  (none)');
    return;
  }
  _log('  ${'username'.padRight(30)}  ${'status'.padRight(10)}  roles');
  _log('  ${'-' * 30}  ${'-' * 10}  ${'-' * 20}');
  for (final u in users) {
    _log(
      '  ${u.username.padRight(30)}  '
      '${u.status.name.padRight(10)}  '
      '${u.roles.toList().join(', ')}',
    );
  }
}

void _printVenueSection(String title, List<Venue> venues) {
  _log(_separator);
  _log(' $title (${venues.length} total)');
  _log(_separator);
  if (venues.isEmpty) {
    _log('  (none)');
    return;
  }
  _log('  ${'id'.padRight(6)}  ${'name'.padRight(30)}  address');
  _log('  ${'-' * 6}  ${'-' * 30}  ${'-' * 30}');
  for (final v in venues) {
    _log(
      '  ${v.id.toString().padRight(6)}  '
      '${v.name.padRight(30)}  '
      '${v.address ?? ''}',
    );
  }
}

void _printEventSection(String title, List<Event> events) {
  _log(_separator);
  _log(' $title (${events.length} total)');
  _log(_separator);
  if (events.isEmpty) {
    _log('  (none)');
    return;
  }
  _log(
    '  ${'id'.padRight(6)}  ${'title'.padRight(30)}  '
    '${'type'.padRight(12)}  visibility',
  );
  _log('  ${'-' * 6}  ${'-' * 30}  ${'-' * 12}  ${'-' * 12}');
  for (final e in events) {
    _log(
      '  ${e.id.toString().padRight(6)}  '
      '${e.title.padRight(30)}  '
      '${e.type.name.padRight(12)}  '
      '${e.visibility.name}',
    );
  }
}

void _printGroupSection(String title, List<Group> groups) {
  _log(_separator);
  _log(' $title (${groups.length} total)');
  _log(_separator);
  if (groups.isEmpty) {
    _log('  (none)');
    return;
  }
  _log('  ${'id'.padRight(6)}  ${'name'.padRight(30)}  description');
  _log('  ${'-' * 6}  ${'-' * 30}  ${'-' * 30}');
  for (final g in groups) {
    _log(
      '  ${g.id.toString().padRight(6)}  '
      '${g.name.padRight(30)}  '
      '${g.description ?? ''}',
    );
  }
}

void _log(String message) {
  // Intentional print for console visibility during dump operations.
  // ignore: avoid_print
  print('[DumpDeleted] $message');
  dev.log(message, name: 'DumpDeletedEntities');
}
