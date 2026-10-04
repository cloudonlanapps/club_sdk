/// Seeds a single test entity into the server from JSON data.
///
/// Dart equivalent of `test_seed.sh`.
/// Does NOT use sudo access. Requires a pre-existing admin user
/// to create venues, approve users, assign roles, create events,
/// and manage groups.
///
/// Caller must respect the seeding order:
/// 1. Users
/// 2. Venues
/// 3. Groups
/// 4. Events (with inline enrollments)
///
/// If order is wrong, the SDK will throw because the required FK
/// resource does not exist.
///
/// Usage:
/// ```dart
/// final client = await createRemoteSecureClient(baseUrl: baseUrl);
///
/// await seed(
///   client: client,
///   username: 'test_admin_vikram',
///   password: 'password123',
///   entityType: EntityType.user,
///   seedJson: '{"username": "test_coach_1", ...}',
/// );
/// ```
library;

import 'dart:convert';
import 'dart:developer' as dev;

import 'package:club_sdk_2/club_sdk_2.dart';

import 'identity_document.dart';

/// Entity types that can be seeded.
enum EntityType { user, venue, event, group }

/// Seeds a single entity into the server from a JSON object string.
///
/// Authenticates as [username]/[password] (must be an existing admin),
/// then creates one entity of [entityType] from [seedJson].
///
/// Throws on any failure — caller is responsible for ordering.
Future<void> seed({
  required SecureClient client,
  required String username,
  required String password,
  required EntityType entityType,
  required String seedJson,
}) async {
  await client.auth.login(username, password);

  final data = json.decode(seedJson) as Map<String, dynamic>;

  switch (entityType) {
    case EntityType.user:
      await _seedUser(client, data, username, password);
    case EntityType.venue:
      await _seedVenue(client, data);
    case EntityType.group:
      await _seedGroup(client, data);
    case EntityType.event:
      await _seedEvent(client, data);
  }

  await client.auth.logout();
}

/// Registers a user via public API, walks them through submit-for-review
/// (server #120 / #142: a fresh sign-up is `registered`, and only a
/// `pending` user can be approved), approves, updates profile, assigns roles.
///
/// JSON format:
/// ```json
/// {
///   "username": "test_coach_priya",
///   "email": "priya@test.com",
///   "password": "password123",
///   "name": "Priya Coach",
///   "status": "active",
///   "roles": ["coach"],
///   "profile": {
///     "firstName": "Priya",
///     "lastName": "Sharma",
///     "bio": "...",
///     "profileImageUrl": "...",
///     "achievements": "...",
///     "dateOfBirthUtc": 946684800000
///   }
/// }
/// ```
Future<void> _seedUser(
  SecureClient client,
  Map<String, dynamic> data,
  String adminUsername,
  String adminPassword,
) async {
  final seedUsername = data['username'] as String;
  final email = data['email'] as String;
  final password = data['password'] as String;
  final firstName = data['name'] as String;
  final status = data['status'] as String? ?? 'active';

  // Extract required profile fields with defaults for test data
  final genderStr = data['gender'] as String? ?? 'male';
  final gender = Gender.values.firstWhere(
    (g) => g.name == genderStr || g.serverValue == genderStr,
    orElse: () => Gender.male,
  );
  final dobMs = data['dateOfBirthUtc'] as int?;
  final dateOfBirthUtc = dobMs != null
      ? DateTime.fromMillisecondsSinceEpoch(dobMs, isUtc: true)
      : DateTime.utc(2000);
  final phone = data['phone'] as String? ?? '0000000000';

  // Register via public endpoint
  final registered = await client.auth.register(
    username: seedUsername,
    email: email,
    password: password,
    firstName: firstName,
    phone: phone,
    dateOfBirthUtc: dateOfBirthUtc,
    gender: gender,
  );
  _log('Registered: $seedUsername');

  // registered -> pending: as the new user, attach the identity document
  // the server requires and submit for review — unless the deployment has
  // identity verification off (#2), where register already returned the
  // user pending. Either way the session returns to the admin.
  await submitForReviewIfRequired(
    client: client,
    registered: registered,
    password: password,
    adminUsername: adminUsername,
    adminPassword: adminPassword,
  );
  _log('Pending review: $seedUsername');

  // Approve (skip for pending)
  if (status != 'pending') {
    await client.users.approveUser(seedUsername);
    _log('Approved: $seedUsername');
  }

  // Update profile if present
  final profile = data['profile'] as Map<String, dynamic>?;
  if (profile != null) {
    final dobMs = profile['dateOfBirthUtc'] as int?;
    await client.users.updateUser(
      seedUsername,
      firstName: profile.containsKey('firstName')
          ? () => profile['firstName'] as String?
          : null,
      lastName: profile.containsKey('lastName')
          ? () => profile['lastName'] as String?
          : null,
      bio: profile.containsKey('bio') ? () => profile['bio'] as String? : null,
      achievements: profile.containsKey('achievements')
          ? () => profile['achievements'] as String?
          : null,
      dateOfBirthUtc: dobMs != null
          ? () => DateTime.fromMillisecondsSinceEpoch(dobMs, isUtc: true)
          : null,
    );
    _log('Profile updated: $seedUsername');
  }

  // Assign roles
  final roles = (data['roles'] as List<dynamic>?)?.cast<String>() ?? <String>[];
  for (final role in roles) {
    await client.users.assignRole(seedUsername, role);
    _log('Role "$role" assigned to: $seedUsername');
  }

  // Status transition (blocked / left)
  if (status == 'blocked') {
    await client.users.blockUser(seedUsername);
    _log('Blocked: $seedUsername');
  } else if (status == 'left') {
    await client.users.markLeft(seedUsername);
    _log('Marked left: $seedUsername');
  }
}

/// Creates a venue from JSON.
///
/// JSON format:
/// ```json
/// {
///   "name": "test_Ice Arena",
///   "address": "123 Rink Rd",
///   "description": "Main rink",
///   "isDefault": false,
///   "isFeatured": false,
///   "mapUrl": "https://...",
///   "imageUrl": "https://..."
/// }
/// ```
Future<void> _seedVenue(SecureClient client, Map<String, dynamic> data) async {
  final name = data['name'] as String;
  final venue = await client.venues.createVenue(
    name: name,
    address: data['address'] as String?,
    description: data['description'] as String?,
    mapUri: data['mapUrl'] as String?,
    isDefault: data['isDefault'] as bool? ?? false,
    isFeatured: data['isFeatured'] as bool? ?? false,
  );
  _log('Created venue: $name (id=${venue.id})');
}

/// Creates an event from JSON. Looks up venue by name.
///
/// JSON format:
/// ```json
/// {
///   "title": "test_Weekend Training",
///   "description": "Regular weekend session",
///   "type": "programme",
///   "visibility": "public",
///   "venueName": "test_Ice Arena",
///   "organizerName": "test_coach_priya",
///   "startTimeUtc": 1700000000000,
///   "endTimeUtc": 1700003600000,
///   "rrule": "FREQ=WEEKLY;BYDAY=SA",
///   "auxInfo": { ... },
///   "enrollments": [
///     { "username": "test_alice", "status": "assigned" },
///     { "username": "test_bob", "status": "invited" }
///   ]
/// }
/// ```
Future<void> _seedEvent(SecureClient client, Map<String, dynamic> data) async {
  final title = data['title'] as String;
  final venueName = data['venueName'] as String;
  final venueId = await _lookupVenueId(client, venueName);

  final event = await client.events.createEvent(
    title: title,
    description: data['description'] as String? ?? '',
    type: EventType.values.firstWhere((t) => t.name == data['type']),
    visibility: Visibility.values.firstWhere(
      (v) => v.name == data['visibility'],
    ),
    venueId: venueId,
    startTimeUtc: DateTime.fromMillisecondsSinceEpoch(
      data['startTimeUtc'] as int,
      isUtc: true,
    ),
    endTimeUtc: DateTime.fromMillisecondsSinceEpoch(
      data['endTimeUtc'] as int,
      isUtc: true,
    ),
    organizerName: data['organizerName'] as String?,
    rrule: data['rrule'] as String?,
  );
  _log('Created event: $title (id=${event.id})');

  // Enrollments
  final enrollments =
      (data['enrollments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      <Map<String, dynamic>>[];
  for (final e in enrollments) {
    final enrollUsername = e['username'] as String;
    final enrollStatus = e['status'] as String;
    await _createEnrollment(client, event.id, enrollUsername, enrollStatus);
    _log('Enrollment: $enrollUsername -> $enrollStatus');
  }
}

/// Creates a group from JSON and adds members.
///
/// JSON format:
/// ```json
/// {
///   "name": "test_Staff",
///   "description": "Staff group",
///   "members": ["test_coach_priya", "test_coach_raj"]
/// }
/// ```
Future<void> _seedGroup(SecureClient client, Map<String, dynamic> data) async {
  final name = data['name'] as String;
  final group = await client.groups.createGroup(
    name: name,
    description: data['description'] as String?,
  );
  _log('Created group: $name (id=${group.id})');

  final members = (data['members'] as List<dynamic>?)?.cast<String>() ?? [];
  for (final member in members) {
    await client.groups.addMember(group.id, member);
    _log('Added $member to $name');
  }
}

/// Looks up a venue ID by its unique name.
Future<int> _lookupVenueId(SecureClient client, String venueName) async {
  final venues = await client.venues.getVenues(limit: 100);
  final match = venues.items.where((v) => v.name == venueName);
  if (match.isEmpty) {
    throw StateError(
      'Venue not found: "$venueName". '
      'Available: ${venues.items.map((v) => v.name).join(', ')}',
    );
  }
  return match.first.id;
}

/// Creates an enrollment based on status string.
Future<void> _createEnrollment(
  SecureClient client,
  int eventId,
  String username,
  String status,
) async {
  switch (status) {
    case 'assigned':
      await client.enrollments.assign(eventId, username);
    case 'invited':
      await client.enrollments.invite(eventId, username);
    case 'requested':
      await client.myEvents.requestToJoin(username, eventId);
    case 'accepted':
      await client.enrollments.invite(eventId, username);
      await client.myEvents.acceptInvite(username, eventId);
    default:
      throw ArgumentError('Unknown enrollment status: $status');
  }
}

void _log(String message) {
  // Intentional print for console visibility during seeding operations.
  // ignore: avoid_print
  print('[Seed] $message');
  dev.log(message, name: 'SeedTestData');
}
