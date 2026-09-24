import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/test_client.dart';

/// Issue 9: `createRemotePublicSource` gives a caller with no login — a
/// public website — the token-free `/public` surface through the public
/// API. What an admin publishes, it reads back without ever authenticating.
void main() {
  group('Issue 9: login-free public source', () {
    late SecureClient admin;
    late PublicSource public;
    late String venuePublicId;
    late Event event;
    const venueName = 'test_Venue I9';
    const eventTitle = 'test_I9 public camp';
    const clubName = 'test_I9 Example Club';
    Object? originalClubInfo;
    var hadClubInfo = false;

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);

      final venue = await admin.venues.createVenue(name: venueName);
      final start = dayAt(15);
      event = await admin.events.createEvent(
        title: eventTitle,
        description: '',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=2',
      );
      try {
        originalClubInfo = (await admin.admin.getPreference('club_info')).value;
        hadClubInfo = true;
      } on ServerException catch (e) {
        if (e.statusCode != 404) rethrow;
      }
      await admin.admin.setPreference('club_info', {'name': clubName});

      public = createRemotePublicSource(baseUrl: baseUrl);
      venuePublicId = (await public.listPublicVenues())
          .singleWhere((v) => v.name == venueName)
          .publicId;
    });

    tearDownAll(() async {
      if (hadClubInfo) {
        await admin.admin.setPreference('club_info', originalClubInfo);
      }
      await admin.auth.logout();
    });

    test('reads the club info an admin set', () async {
      final info = await public.getPublicClubInfo();
      expect(info.clubInfo['name'], clubName);
    });

    test('lists and reads a public venue', () async {
      final venue = await public.getPublicVenue(venuePublicId);
      expect(venue.name, venueName);
      expect(venue.publicId, venuePublicId);
    });

    test('lists and reads a public event', () async {
      final page = await public.listPublicEvents(limit: 100);
      final listed = page.items.singleWhere((e) => e.title == eventTitle);
      final read = await public.getPublicEvent(listed.publicId);
      expect(read.title, eventTitle);
      expect(read.venueId, venuePublicId);
    });

    test(
      'a login-only route is refused: the source carries no token',
      () async {
        // The same base URL with no session: a staff read is a 401, which
        // proves the public reads above went through without one.
        final anonymous = await createRemoteSecureClient(baseUrl: baseUrl);
        await expectLater(
          anonymous.events.getEvent(event.id),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 401),
          ),
        );
      },
    );
  });
}
