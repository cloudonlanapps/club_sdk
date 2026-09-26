import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 48: `updateEvent(coachNames: () => null)` used to send `null`, which
/// the server reads as "unchanged". A getter returning `null` or `[]` now
/// clears the coaches.
void main() {
  group('Issue 48: clearing coaches on updateEvent', () {
    late SecureClient sudo;
    late int venueId;
    var nextDay = 480;

    const coachA = 'test_i48_coach_a';
    const coachB = 'test_i48_coach_b';

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);

      for (final name in [coachA, coachB]) {
        await registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: 'password123',
          phone: '+919000000048',
          dateOfBirthUtc: DateTime.utc(1990),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
        await sudo.users.assignRole(name, 'coach');
      }

      venueId = (await sudo.venues.createVenue(
        name: 'test_i48_venue',
        address: '48 Rink Road',
      )).id;
    });

    tearDownAll(() async {
      await sudo.auth.logout();
    });

    Future<Event> coached(EventType type) {
      final start = dayAt(nextDay++, hour: 15);
      return sudo.events.createEvent(
        title: 'test_i48_${type.name}',
        description: 'coaches to clear',
        type: type,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        organizerName: sudoUsername,
        coachNames: [coachA, coachB],
      );
    }

    for (final type in [EventType.oneOff, EventType.camp]) {
      test("48.01: a ${type.name}'s coaches clear with () => null", () async {
        final event = await coached(type);
        expect(event.coachNames, unorderedEquals([coachA, coachB]));

        final updated = await sudo.events.updateEvent(
          event.id,
          version: event.version,
          coachNames: () => null,
        );
        expect(updated.coachNames ?? const <String>[], isEmpty);

        final read = await sudo.events.getEvent(event.id);
        expect(read.coachNames ?? const <String>[], isEmpty);
        expect(read.organizerName, sudoUsername);
      });
    }

    test('48.02: an empty list clears them too', () async {
      final event = await coached(EventType.oneOff);

      await sudo.events.updateEvent(
        event.id,
        version: event.version,
        coachNames: () => const [],
      );

      final read = await sudo.events.getEvent(event.id);
      expect(read.coachNames ?? const <String>[], isEmpty);
    });

    test('48.03: an omitted getter leaves them alone', () async {
      final event = await coached(EventType.oneOff);

      await sudo.events.updateEvent(
        event.id,
        version: event.version,
        title: 'test_i48_renamed',
      );

      final read = await sudo.events.getEvent(event.id);
      expect(read.title, 'test_i48_renamed');
      expect(read.coachNames, unorderedEquals([coachA, coachB]));
    });
  });
}
