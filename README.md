# club_sdk

A pure-Dart client for the club_server API: users, groups, venues,
events and their schedules, occurrences, enrollments, attendance, media,
notifications, credits and evaluations. The package is `club_sdk_2`.

```yaml
dependencies:
  club_sdk_2:
    git:
      url: https://github.com/cloudonlanapps/club_sdk.git
      ref: <sha>
```

```dart
final client = await createRemoteSecureClient(
  baseUrl: 'https://api.myexampleclub.com/v1',
);
await client.auth.login('username', 'password');
```

`just unit-test` runs the unit tests; `just test` runs the integration suite
against a fresh server (see `CLAUDE.md`).

## Modules

| | # | Module | Interface | Description |
|---|---|--------|-----------|-------------|
| [x] | 1 | Authentication | `AuthSource` | Login, register, password reset, bootstrap super admin, token refresh |
| [x] | 2 | User Management | `UserSource` | CRUD, role management, status transitions (pending/active/blocked/left), profiles |
| [ ] | 4 | Group Management | `GroupSource` | Create, update, delete groups and manage members |
| [ ] | 5 | Guardian Management | `GuardianSource` | Guardian-dependent relationships, guardian limits |
| [ ] | 6 | Venue Management | `VenueSource` | CRUD, capacity management, active venue listing |
| [ ] | 7 | Event Management | `EventSource` | CRUD for one-off/programme/camp events, recurring rules (RRULE), conflict detection, available slot finding |
| [ ] | 8 | Occurrence Management | `OccurrenceSource` | Individual instances of recurring events - reschedule, cancel, status tracking |
| [ ] | 9 | Enrollment Management | `EnrollmentSource` | Invite, assign, withdraw users from events; trial enrollments; status transitions |
| [ ] | 10 | Attendance Tracking | `AttendanceSource` | Mark present/absent/late, leave requests, attendance stats |
| [ ] | 11 | Pending Actions | `PendingActionsSource` | Action counts for attendees and organizers |
| [ ] | 12 | Notification Management | `NotificationSource` | Fetch/manage notifications, mark read, channel preferences (in-app, email, SMS) |
| [x] | 14 | Public API | `PublicClient` | Unauthenticated read-only access - staff listings, public events, venues, landing/about/contact pages, health check |
| [x] | 15 | Seeding | `SeedingService` | Bulk test data loading, handles entity dependency ordering, force-clean |
