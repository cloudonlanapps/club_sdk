import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// club_server#517: the media links of a soft-deleted group, venue or event
/// stay readable, each marked `ownerDeleted`, and are read-only: adding,
/// changing or removing one answers 422 `OWNER_DELETED`. The reverse lookup
/// and the cross-owner search carry the same `ownerDeleted` marker.
void main() {
  group('club_server#517: links on a soft-deleted owner', () {
    late SecureClient sudoClient;
    late int venueId; // hosts the event; never deleted
    const tag = 'photos';

    /// One owner type: how to make one, soft-delete it, and reach its links.
    final owners =
        <
          String,
          ({
            Future<int> Function(String name) create,
            Future<void> Function(int id) softDelete,
            OwnerMediaSource<int> Function() links,
            MediaLinkOwnerType ownerType,
          })
        >{
          'group': (
            create: (name) async =>
                (await sudoClient.groups.createGroup(name: name)).id,
            softDelete: (id) => sudoClient.groups.deleteGroup(id),
            links: () => sudoClient.groupMedia,
            ownerType: MediaLinkOwnerType.group,
          ),
          'venue': (
            create: (name) async => (await sudoClient.venues.createVenue(
              name: name,
              address: '517 Rink Road',
            )).id,
            softDelete: (id) async => sudoClient.venues.deleteVenue(id),
            links: () => sudoClient.venueMedia,
            ownerType: MediaLinkOwnerType.venue,
          ),
          'event': (
            create: (name) async => (await sudoClient.events.createEvent(
              title: name,
              description: 'club_server#517',
              type: EventType.oneOff,
              visibility: Visibility.public,
              venueId: venueId,
              // Inside the 52-week scheduling horizon (#16).
              startTimeUtc: dayAt(40, hour: 9),
              endTimeUtc: dayAt(40, hour: 10),
              organizerName: sudoUsername,
            )).id,
            softDelete: (id) async => sudoClient.events.deleteEvent(id),
            links: () => sudoClient.eventMedia,
            ownerType: MediaLinkOwnerType.event,
          ),
        };

    Future<Media> upload(String name) async {
      final media = await sudoClient.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i517_$name.png',
        contentType: 'image/png',
        preserveOriginal: true,
      );
      expect(media.uuid, isNotEmpty);
      return media;
    }

    Matcher refusedOwnerDeleted() => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', SdkErrorCode.ownerDeleted),
    );

    setUpAll(() async {
      sudoClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudoClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudoClient.auth.login(sudoUsername, sudoPassword);
      expect((await sudoClient.auth.getCurrentUser()).username, sudoUsername);

      venueId = (await sudoClient.venues.createVenue(
        name: 'test_i517_host_venue',
        address: '517 Rink Road',
      )).id;
    });

    tearDownAll(() async {
      await sudoClient.auth.logout();
    });

    for (final MapEntry(key: type, value: owner) in owners.entries) {
      group('$type:', () {
        late int ownerId;
        late Media linked; // attached while the owner was live
        late Media spare; // never attached; used for the refused attach

        setUpAll(() async {
          ownerId = await owner.create('test_i517_$type');
          linked = await upload('${type}_linked');
          spare = await upload('${type}_spare');

          final link = await owner.links().attach(
            ownerId,
            tag: tag,
            mediaUuid: linked.uuid,
            metadata: 'before',
          );
          expect(link.ownerDeleted, isFalse, reason: 'the owner is live');

          await owner.softDelete(ownerId);
        });

        test('its links are still listed, marked ownerDeleted', () async {
          final links = await owner.links().listByTag(ownerId, tag);
          expect(links, hasLength(1));
          expect(links.single.mediaUuid, linked.uuid);
          expect(links.single.ownerDeleted, isTrue);

          final grouped = await owner.links().listGrouped(ownerId);
          expect(grouped[tag]!.single.ownerDeleted, isTrue);
        });

        test('the reverse lookup marks the link ownerDeleted', () async {
          final entries = await sudoClient.media.getLinks(linked.uuid);
          final entry = entries.singleWhere(
            (e) => e.ownerType == owner.ownerType && e.ownerId == '$ownerId',
          );
          expect(entry.ownerDeleted, isTrue);
        });

        test('the cross-owner search marks the link ownerDeleted', () async {
          final page = await sudoClient.media.searchLinks(
            ownerType: owner.ownerType,
            tag: tag,
            limit: 100,
          );
          final entry = page.items.singleWhere(
            (e) => e.mediaUuid == linked.uuid,
          );
          expect(entry.ownerId, '$ownerId');
          expect(entry.ownerDeleted, isTrue);
        });

        test('adding a link is refused with 422 OWNER_DELETED', () async {
          await expectLater(
            owner.links().attach(ownerId, tag: tag, mediaUuid: spare.uuid),
            refusedOwnerDeleted(),
          );
          final links = await owner.links().listByTag(ownerId, tag);
          expect(links.map((l) => l.mediaUuid), [linked.uuid]);
        });

        test('changing a link is refused with 422 OWNER_DELETED', () async {
          await expectLater(
            owner.links().updateMetadata(
              ownerId,
              tag: tag,
              mediaUuid: linked.uuid,
              metadata: 'after',
            ),
            refusedOwnerDeleted(),
          );
          final links = await owner.links().listByTag(ownerId, tag);
          expect(links.single.metadata, 'before');
        });

        test('removing a link is refused with 422 OWNER_DELETED', () async {
          await expectLater(
            owner.links().detach(ownerId, tag, linked.uuid),
            refusedOwnerDeleted(),
          );
          await expectLater(
            owner.links().detachTag(ownerId, tag),
            refusedOwnerDeleted(),
          );
          final links = await owner.links().listByTag(ownerId, tag);
          expect(links.map((l) => l.mediaUuid), [linked.uuid]);
        });
      });
    }
  });
}
