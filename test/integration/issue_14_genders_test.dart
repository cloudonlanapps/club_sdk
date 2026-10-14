import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Issue 14: an event's and a group's eligibility take a list of genders
/// (club_server#25, #26). An empty list clears the criterion; a write
/// without `genders` leaves it alone.
void main() {
  group('Issue 14: genders, a list', () {
    late SecureClient client;
    late int venueId;
    const three = [Gender.male, Gender.other, Gender.preferNotToSay];
    final start = DateTime.utc(
      DateTime.now().toUtc().year,
      DateTime.now().toUtc().month,
      DateTime.now().toUtc().day,
      9,
    ).add(const Duration(days: 20));

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );
      await client.auth.login(sudoUsername, sudoPassword);
      venueId = (await client.venues.createVenue(name: 'test_Venue I14')).id;
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    test('Issue 14: an event created with three genders reads back with '
        'them; an empty list clears them', () async {
      final created = await client.events.createEvent(
        title: 'test_I14 event',
        description: '',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        genders: three,
      );
      expect(created.genders, three);
      expect((await client.events.getEvent(created.id)).genders, three);

      final renamed = await client.events.updateEvent(
        created.id,
        version: created.version,
        title: 'test_I14 event renamed',
      );
      expect(renamed.genders, three, reason: 'left out, left alone');

      final cleared = await client.events.updateEvent(
        created.id,
        version: renamed.version,
        genders: () => const [],
      );
      expect(cleared.genders, isEmpty);
      expect((await client.events.getEvent(created.id)).genders, isEmpty);
    });

    test('Issue 14: a group created with three genders reads back with '
        'them; an empty list clears them', () async {
      final created = await client.groups.createGroup(
        name: 'test_I14 group',
        genders: three,
      );
      expect(created.genders, three);
      expect((await client.groups.getGroup(created.id)).genders, three);

      final renamed = await client.groups.updateGroup(
        created.id,
        name: 'test_I14 group renamed',
      );
      expect(renamed.genders, three, reason: 'left out, left alone');

      final cleared = await client.groups.updateGroup(
        created.id,
        genders: () => const [],
      );
      expect(cleared.genders, isEmpty);
      expect((await client.groups.getGroup(created.id)).genders, isEmpty);
    });

    test(
      'Issue 14: the deprecated gender is stored as a list of one',
      () async {
        final created = await client.groups.createGroup(
          name: 'test_I14 single',
          gender: Gender.female,
        );
        expect(created.genders, [Gender.female]);
        expect(created.gender, Gender.female);
      },
    );
  });
}
