import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 272: events.listEligible(eventId) SDK wiring.
///
/// Covers GET /events/by_id/{event_id}/eligible (server #103).
void main() {
  group('Issue 272: events.listEligible', () {
    late SecureClient client;
    late int venueId;

    final maleDob = DateTime.utc(2010);
    final femaleDob = DateTime.utc(2010);
    final oldDob = DateTime.utc(2000);

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );
      await client.auth.login(sudoUsername, sudoPassword);

      final v = await client.venues.createVenue(
        name: 'test_Venue I272',
        address: 'I272 Street',
      );
      venueId = v.id;

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_male_i272',
        email: 'test_male_i272@test.com',
        password: 'password123',
        firstName: 'Male',
        phone: '1111111111',
        dateOfBirthUtc: maleDob,
        gender: Gender.male,
      );

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_female_i272',
        email: 'test_female_i272@test.com',
        password: 'password123',
        firstName: 'Female',
        phone: '2222222222',
        dateOfBirthUtc: femaleDob,
        gender: Gender.female,
      );

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_old_i272',
        email: 'test_old_i272@test.com',
        password: 'password123',
        firstName: 'Old',
        phone: '3333333333',
        dateOfBirthUtc: oldDob,
        gender: Gender.male,
      );

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

    var eventCounter = 0;
    Future<Event> createEvent({
      Gender? gender,
      DateTime? dobOnOrAfterUtc,
    }) async {
      eventCounter += 1;
      final start = DateTime.now().toUtc().add(
        Duration(days: eventCounter * 2),
      );
      return client.events.createEvent(
        title: 'test_Event I272',
        description: 'eligible-endpoint coverage',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        gender: gender,
        dobOnOrAfterUtc: dobOnOrAfterUtc,
      );
    }

    test('Issue 272: no-criteria event returns all active members', () async {
      final event = await createEvent();
      final eligible = await client.events.listEligible(event.id);
      final names = eligible.map((e) => e.username).toSet();
      expect(names.contains('test_male_i272'), isTrue);
      expect(names.contains('test_female_i272'), isTrue);
      expect(names.contains('test_old_i272'), isTrue);
    });

    test('Issue 272: gender constraint filters wrong-gender users', () async {
      final event = await createEvent(gender: Gender.female);
      final eligible = await client.events.listEligible(event.id);
      final names = eligible.map((e) => e.username).toSet();
      expect(names.contains('test_female_i272'), isTrue);
      expect(names.contains('test_male_i272'), isFalse);
      expect(names.contains('test_old_i272'), isFalse);
    });

    test('Issue 272: DOB window excludes out-of-window users', () async {
      final event = await createEvent(dobOnOrAfterUtc: DateTime.utc(2005));
      final eligible = await client.events.listEligible(event.id);
      final names = eligible.map((e) => e.username).toSet();
      expect(names.contains('test_male_i272'), isTrue);
      expect(names.contains('test_female_i272'), isTrue);
      expect(names.contains('test_old_i272'), isFalse);
    });
  });
}
