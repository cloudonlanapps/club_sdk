# club_sdk

A pure-Dart client for the club_server API: events, users, attendance, enrollments, venues, and more.

## Quick Reference

- **Language**: Dart (SDK ^3.11.0)
- **Package**: `club_sdk_2` (v0.2.0)
- **Repo**: `cloudonlanapps/club_sdk` (public)
- **Main branch**: `main`
- **Linting**: `very_good_analysis` (10.3.0)
- **Task runner**: `just` (`just --list`)

## Build & Test Commands

```bash
# Get dependencies
dart pub get

# Run all tests
dart test

# Run unit tests only
just unit-test          # = dart test test/unit/ -j 1

# Run a specific test file
dart test test/unit/models/event_test.dart

# Run integration tests (must use -j 1; concurrent runs cause cross-file data conflicts)
dart test test/integration/ -j 1

# Analyze and check formatting
just lint

# Format code
dart format lib/ test/
```

## Architecture

```
lib/
  club_sdk_2.dart          # Main barrel export
  client.dart              # SecureClient (authenticated entry point)
  remote_store.dart        # Remote HTTP implementation export
  seeding.dart             # Seeding library export

  sdk/
    interfaces/            # Abstract *Source interfaces (AuthSource, EventSource, etc.)
    models/                # Immutable data classes with JSON serialization
    exceptions/            # 60+ domain-specific exception types extending SdkException
    utils/                 # Utilities (RruleUtil for recurring events)

  remote_store/
    remote_store.dart      # HTTP client wrapper (auth, retry, token refresh)
    remote_client.dart     # createRemoteSecureClient() factory
    http/                  # API exception mapping
    sources/               # Remote*Source implementations of interfaces

  seeding/                 # Test data seeding (SeedingService, AppSeedData)
```

### Layered Design

1. **Client Layer** - `SecureClient` aggregates domain sources
2. **Interface Layer** - Abstract `*Source` interfaces per domain (EventSource, UserSource, etc.)
3. **Implementation Layer** - `Remote*Source` classes implementing interfaces via HTTP
4. **Model Layer** - Immutable data classes with `copyWith`, `toMap`/`fromMap`, equality

### Key Design Patterns

- **Interface Segregation**: Each domain has its own `*Source` interface
- **Factory Pattern**: `createRemoteSecureClient()`
- **Immutable Models**: All use `@immutable`, `final` fields, ValueGetter pattern for nullable `copyWith`
- **Exception Hierarchy**: All exceptions extend `SdkException` with category-specific subclasses

## Test Structure

```
test/
  unit/models/             # Model serialization, equality, copyWith tests
  unit/utils/              # Utility function tests
  integration/             # Remote API integration tests
  shared/
    categories/            # 21 categorical test suites (s01-s21)
    workflows/             # 11 user workflow tests
    mock_seed_data.dart    # Shared mock data
```

## Core Domains

| Domain | Interface | Key Models |
|--------|-----------|------------|
| Auth | `AuthSource` | `AuthToken` |
| Users | `UserSource` | `UserInfo`, `UserPrivate`, `UserRoles`, `PublicProfile` |
| Events | `EventSource` | `Event`, `EventInput`, `EventWithAuxInfo` |
| Occurrences | `OccurrenceSource` | `Occurrence`, `OccurrenceOverride` |
| Enrollments | `EnrollmentSource` | `Enrollment` |
| Attendance | `AttendanceSource` | `AttendanceRecord`, `AttendanceStats` |
| Venues | `VenueSource` | `Venue` |
| Groups | `GroupSource` | `Group` |
| Notifications | `NotificationSource` | `AppNotification`, `NotificationPref` |

## Key Enums

- **EventType**: `oneOff`, `programme`, `camp`
- **EventStatus**: `active`, `rescheduled`, `cancelled`
- **EnrollmentStatus**: `invited`, `requested`, `accepted`, `rejected`, `assigned`, `assignedTrial`, `withdrawn`, `withdrawRequested`
- **AttendanceStatus**: `present`, `absent`, `late`, `onLeave`, `onLeaveRequested`
- **OccurrenceStatus**: `scheduled`, `cancelled`, `rescheduled`, `completed`
- **UserStatus**: `pending`, `active`, `blocked`, `left`

## Integration Test Guidelines

**Run against an isolated test stack, not a shared server.** From this repo:

```bash
just test                              # full suite
just test-one s23_broadcasts_test.dart
just test-one s23_broadcasts_test.dart keep=1   # leave the server up to debug
just test-modules                      # stack with credits, evaluations, marketing on
```

Each recipe spins up its **own** fresh isolated server (free ports, started in
tmux via `background_server.sh` (native_deploy, on PATH)) and tears it down on exit — no shared
stack to reset or collide on. The stack is described by `sdk_test.conf` or
`sdk_test_modules.conf`, whose `source` clones club_server's `main` from git
afresh for each run (so it needs SSH access to that repo); to test against a
local server checkout, point `source` at it or point `SDK_CONF` at your own conf. The
recipes inject `MYCLUB_API_BASE_URL` (the just-picked port),
`MYCLUB_SUDO_USERNAME` and `MYCLUB_SUDO_PASSWORD` (the conf's
`bootstrap_password`) so `test_client.dart` connects to that stack. Running
plain `dart test test/integration/` works only if a server is already up and those env
vars point at it — the `just` recipes are the safer default.

Each integration test file must be **self-contained** — it owns its setup, data, and teardown. No reliance on global seeding or execution order of other test files.

### 1. No Global Seeding

- **Do NOT use `createTestClient()`** which triggers full JSON seeding of all users, venues, and groups.
- Use `createRemoteSecureClient(baseUrl: baseUrl)` directly for a bare client.
- Import `baseUrl`, `sudoUsername`, `sudoPassword` from `test_client.dart` for server config only.

### 2. Seed Only What the Test Needs

- In `setUpAll`, clean test artifacts then create **only** the entities this test file requires.
- Use direct SDK calls (register, createVenue, createGroup, etc.) to seed locally — do not route through the full `seed()` function unless the entity is complex.
- If a JSON seed entry is needed (e.g., a complex event with enrollments), copy **just that entry** inline or into a local constant — do not load entire JSON files.

### 3. Setup Structure

```dart
late SecureClient client;

setUpAll(() async {
  client = await createRemoteSecureClient(baseUrl: baseUrl);

  // 1. Clean test artifacts
  await clearTestArtifacts(
    client: client,
    username: sudoUsername,
    password: sudoPassword,
  );

  // 2. Login as sudo/admin
  await client.auth.login(sudoUsername, sudoPassword);

  // 3. Create and configure only the entities this test needs
  //    (register users, approve, assign roles, create venues, etc.)

  // 4. Logout admin
  await client.auth.logout();
});
```

- Create **named clients** in `setUpAll` when tests need to act as different roles (e.g., `adminClient`, `memberClient`, `coachClient`). Avoid logging in/out repeatedly inside individual tests.
- Use `setUp` (per-test) only for state that must be fresh each test.
- Use `tearDown` to logout if tests log in with the shared client.

### 4. Verify Server Behavior, Don't Assume It

- Use `isA<ServerException>()` instead of `throwsA(anything)` — catch the specific exception type so tests fail for the right reason.
- After login, verify with `getCurrentUser()` before testing authenticated operations — confirm you're testing what you think you're testing.
- If the server doesn't enforce an expected constraint (e.g., current password validation), that's a discovery — document it with a `skip` or a comment, don't force-fit the test.

### 5. Delete Lifecycle Testing

All entity types (users, venues, groups, events) support a three-step delete lifecycle: soft-delete → restore or hard-delete.

- **Soft-delete before hard-delete**: The server requires `delete*()` before `hardDelete*()`. Calling `hardDelete*()` on an active entity returns a 422 `INVALID_STATE` error.
- **Verify both listing APIs**: After soft-delete, confirm the entity is absent from the active listing API (`getUsers`, `getVenues`, `getGroups`, `listEvents`) **and** present in the deleted listing API (`getDeletedUsers`, `getDeletedVenues`, `getDeletedGroups`, `listDeletedEvents`). After restore, verify the reverse.
- **Hard-delete verification**: After hard-delete, confirm the entity is gone from **both** active and deleted listing APIs.
- **Permission testing**: Only the super admin can hard-delete. Always test that a regular admin receives `ServerException` when attempting `hardDelete*()`.

### 6. Test File Checklist

- [ ] Does NOT call `createTestClient()` or `seed()`
- [ ] `setUpAll` creates only the entities needed by this file
- [ ] No test depends on entities created by another test file
- [ ] Role-specific clients created once in `setUpAll`, not per-test
- [ ] `tearDown` handles logout for shared client usage
- [ ] Error assertions use `isA<ServerException>()` not `throwsA(anything)`
- [ ] Each `test()` verifies one requirement with meaningful `expect()` calls
- [ ] Delete lifecycle tests call `delete*` before `hardDelete*`
- [ ] Delete lifecycle tests verify both active and deleted listing APIs

### 7. Available Utilities

| Utility | Import | Purpose |
|---------|--------|---------|
| `baseUrl`, `sudoUsername`, `sudoPassword` | `test_client.dart` | Server config constants |
| `createRemoteSecureClient()` | `package:club_sdk_2/remote_store.dart` | Bare client factory |
| `clearTestArtifacts()` | `clear_test_artifacts.dart` | Wipes all `test_` entities |
| `testPrefix` | `mock_seed_data.dart` | The `test_` prefix constant |

## Dependencies

- `collection` - Collection utilities
- `http_parser` - Media types for uploads
- `http` - HTTP client
- `meta` - `@immutable` annotations
- `rrule` - RFC 5545 recurring event rules
