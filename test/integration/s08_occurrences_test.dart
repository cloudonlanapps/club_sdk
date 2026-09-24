import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 8: Occurrences Test Suite.
///
/// Tests requirements from Section 8 (Occurrences):
/// - 8.01: List Occurrences
/// - 8.02: Reschedule Occurrence
/// - 8.03: Cancel Occurrence
/// - 8.04: Restore Occurrence
/// - 8.05: Get Occurrence Details
/// - 8.06: List My Occurrences
/// - 8.07: Override Occurrence Venue
/// - 8.08: Override Occurrence Coach
///
/// OccurrenceSource coverage:
/// - [`x`] getOccurrence
/// - [`x`] listOccurrences
/// - [`x`] rescheduleOccurrence
/// - [`x`] cancelOccurrence
/// - [`x`] restoreOccurrence
void main() {
  group('Section 8: Occurrences', () {
    late SecureClient client;
    late int venue1Id;
    late int venue2Id;
    final now = DateTime.utc(2027, 3, 1, 10);
    // Programmes are weekly on one weekday (#16) and clash on venue and
    // organizer per occurrence, so each programme here takes its own weekday.

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean all test_ artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to seed test data
      await client.auth.login(sudoUsername, sudoPassword);

      // 3. Create venues
      final v1 = await client.venues.createVenue(
        name: 'test_Venue 1 S08',
        address: 'S08 Street 1',
      );
      venue1Id = v1.id;

      final v2 = await client.venues.createVenue(
        name: 'test_Venue 2 S08',
        address: 'S08 Street 2',
      );
      venue2Id = v2.id;

      // Create user for enrollment-based occurrence tests
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_alice_s08',
        email: 'test_alice_s08@test.com',
        password: 'password123',
        firstName: 'Alice S08',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // 4. Logout sudo
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

    group('8.01: List Occurrences', () {
      test('retrieves occurrences for date range', () async {
        final event = await client.events.createEvent(
          title: 'test_List Occ Test',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now,
          endTimeUtc: now.add(const Duration(hours: 1)),
          rrule: weeklyOn(now),
        );

        final occurrences = await client.occurrences.listOccurrences(
          fromTimeUtc: now,
          toTimeUtc: now.add(const Duration(days: 35)),
        );

        expect(
          occurrences.where((o) => o.eventId == event.id).length,
          5,
        );
      });
    });

    group('8.02: Reschedule Occurrence', () {
      test('changes occurrence time', () async {
        final eventStart = now.add(const Duration(days: 30));

        final event = await client.events.createEvent(
          title: 'test_Reschedule Test',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: eventStart,
          endTimeUtc: eventStart.add(const Duration(hours: 1)),
          rrule: weeklyOn(eventStart),
        );

        final newStart = eventStart.add(const Duration(hours: 2));
        final newEnd = newStart.add(const Duration(hours: 1));

        // Occurrence reschedule is now start + duration; the server derives
        // the end from start + newDurationMinutes (#113).
        await client.occurrences.rescheduleOccurrence(
          event.id,
          eventStart,
          newStartTimeUtc: newStart,
          newDurationMinutes: 60,
        );

        final updated = await client.occurrences.getOccurrence(
          event.id,
          eventStart,
        );

        expect(updated.actualStartTimeUtc, newStart);
        expect(updated.actualEndTimeUtc, newEnd);
      });
    });

    group('8.03: Cancel Occurrence', () {
      test('preserves history', () async {
        final eventStart = now.add(const Duration(days: 31));

        final event = await client.events.createEvent(
          title: 'test_Cancel Occ Test',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: eventStart,
          endTimeUtc: eventStart.add(const Duration(hours: 1)),
          rrule: weeklyOn(eventStart),
        );

        await client.occurrences.cancelOccurrence(
          event.id,
          eventStart,
          reason: 'Weather conditions',
        );

        final occurrence = await client.occurrences.getOccurrence(
          event.id,
          eventStart,
        );

        expect(occurrence.status, OccurrenceStatus.cancelled);
      });
    });

    group('8.04: Restore Occurrence', () {
      test('restores cancelled occurrence', () async {
        final occTime = now.add(const Duration(days: 33));
        final event = await client.events.createEvent(
          title: 'test_Restore Occ Test',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: occTime,
          endTimeUtc: occTime.add(const Duration(hours: 1)),
          rrule: weeklyOn(occTime),
        );

        await client.occurrences.cancelOccurrence(
          event.id,
          occTime,
          reason: 'Temporary cancellation',
        );

        await client.occurrences.undoCancelOccurrence(event.id, occTime);

        final occurrence = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );

        expect(occurrence.status, isNot(OccurrenceStatus.cancelled));
      });
    });

    group('8.05: Get Occurrence Details', () {
      test('retrieves single occurrence', () async {
        final eventStart = now.add(const Duration(days: 32));
        final event = await client.events.createEvent(
          title: 'test_Get Occ Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: eventStart,
          endTimeUtc: eventStart.add(const Duration(hours: 1)),
        );

        final occurrence = await client.occurrences.getOccurrence(
          event.id,
          eventStart,
        );

        expect(occurrence.eventId, event.id);
        expect(occurrence.originalStartTimeUtc, eventStart);
      });
    });

    group('8.06: List My Occurrences', () {
      test('filters by enrollment', () async {
        final event = await client.events.createEvent(
          title: 'test_My Occ Test',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: now.add(const Duration(days: 40)),
          endTimeUtc: now.add(const Duration(days: 40, hours: 1)),
        );

        await client.enrollments.assign(
          event.id,
          'test_alice_s08',
        );

        final occurrences = await client.myEvents.listMyOccurrences(
          'test_alice_s08',
          fromTimeUtc: now.add(const Duration(days: 39)),
          toTimeUtc: now.add(const Duration(days: 41)),
        );

        expect(
          occurrences.any((o) => o.eventId == event.id),
          isTrue,
        );
      });
    });

    group('8.07: Override Occurrence Venue', () {
      test('changes venue for single occurrence', () async {
        final occTime = now.add(const Duration(days: 34));
        final event = await client.events.createEvent(
          title: 'test_Venue Override Test',
          description: 'D',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venue1Id,
          startTimeUtc: occTime,
          endTimeUtc: occTime.add(const Duration(hours: 1)),
          rrule: weeklyOn(occTime),
        );

        await client.occurrences.rescheduleOccurrence(
          event.id,
          occTime,
          newVenueId: venue2Id,
        );

        final updated = await client.occurrences.getOccurrence(
          event.id,
          occTime,
        );

        expect(updated.venueId, venue2Id);
      });
    });

    // Per-occurrence organizer override was dropped from the reschedule
    // contract (#113): newOrganizerName is no longer accepted. The former
    // "8.08: Override Occurrence Coach" test is removed accordingly.
  });
}
