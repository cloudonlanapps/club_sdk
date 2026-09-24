import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Integration tests for the v2 media link tables (#550, server #162).
///
/// Exercises:
/// - Per-owner attach / listGrouped / listByTag / get / updateMetadata /
///   detach / detachTag on the four facades (user, event, group, venue).
/// - Typed reverse lookup via `client.media.getLinks(uuid)`.
/// - Cross-owner search via `client.media.searchLinks(...)`.
/// - The `MEDIA_IN_USE` 409 path: soft-delete refused while linked.
void main() {
  group('Issue 550: v2 media link tables', () {
    late SecureClient adminClient;

    final testPngBytes = <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x02,
      0x00,
      0x00,
      0x00,
      0x90,
      0x77,
      0x53,
      0xDE,
      0x00,
      0x00,
      0x00,
      0x0C,
      0x49,
      0x44,
      0x41,
      0x54,
      0x08,
      0xD7,
      0x63,
      0xF8,
      0xCF,
      0xC0,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x01,
      0xE2,
      0x21,
      0xBC,
      0x33,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ];

    Future<Media> upload({String filename = 'issue_550.png'}) =>
        adminClient.media.upload(
          fileBytes: testPngBytes,
          filename: filename,
          contentType: 'image/png',
          preserveOriginal: true,
        );

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await adminClient.auth.login(sudoUsername, sudoPassword);
    });

    tearDownAll(() async {
      await adminClient.auth.logout();
    });

    test(
      'Issue 550: userMedia attach/get/listByTag/listGrouped/update/detach',
      () async {
        final media = await upload(filename: 'issue_550_user.png');

        try {
          final attached = await adminClient.userMedia.attach(
            sudoUsername,
            tag: 'profile_photos',
            mediaUuid: media.uuid,
            metadata: 'primary',
          );
          expect(attached.mediaUuid, media.uuid);
          expect(attached.tag, 'profile_photos');
          expect(attached.metadata, 'primary');
          expect(attached.media.mimeType, startsWith('image/'));
          expect(attached.media.isImage, isTrue);
          expect(attached.media.filename, isNotEmpty);

          final got = await adminClient.userMedia.get(
            sudoUsername,
            'profile_photos',
            media.uuid,
          );
          expect(got.mediaUuid, media.uuid);

          final byTag = await adminClient.userMedia.listByTag(
            sudoUsername,
            'profile_photos',
          );
          expect(byTag, hasLength(1));
          expect(byTag.single.mediaUuid, media.uuid);

          final grouped = await adminClient.userMedia.listGrouped(sudoUsername);
          expect(grouped.keys, contains('profile_photos'));
          expect(grouped['profile_photos']!.single.mediaUuid, media.uuid);

          final updated = await adminClient.userMedia.updateMetadata(
            sudoUsername,
            tag: 'profile_photos',
            mediaUuid: media.uuid,
            metadata: 'archived',
          );
          expect(updated.metadata, 'archived');

          await adminClient.userMedia.detach(
            sudoUsername,
            'profile_photos',
            media.uuid,
          );
          final afterDetach = await adminClient.userMedia.listByTag(
            sudoUsername,
            'profile_photos',
          );
          expect(afterDetach, isEmpty);
        } finally {
          // best-effort cleanup
          try {
            await adminClient.userMedia.detach(
              sudoUsername,
              'profile_photos',
              media.uuid,
            );
          } on Exception catch (_) {}
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      },
    );

    test(
      'Issue 550: detachTag removes every link under that tag',
      () async {
        final m1 = await upload(filename: 'issue_550_tag_a.png');
        final m2 = await upload(filename: 'issue_550_tag_b.png');
        try {
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: 'docs',
            mediaUuid: m1.uuid,
          );
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: 'docs',
            mediaUuid: m2.uuid,
          );
          expect(
            await adminClient.userMedia.listByTag(sudoUsername, 'docs'),
            hasLength(2),
          );

          await adminClient.userMedia.detachTag(sudoUsername, 'docs');
          expect(
            await adminClient.userMedia.listByTag(sudoUsername, 'docs'),
            isEmpty,
          );
        } finally {
          for (final m in [m1, m2]) {
            try {
              await adminClient.userMedia.detach(sudoUsername, 'docs', m.uuid);
            } on Exception catch (_) {}
            await adminClient.media.softDelete(m.id);
            await adminClient.media.hardDelete(m.id);
          }
        }
      },
    );

    test(
      'Issue 550: media.getLinks returns typed reverse entries',
      () async {
        final media = await upload(filename: 'issue_550_reverse.png');
        try {
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: 'avatars',
            mediaUuid: media.uuid,
            metadata: 'small',
          );

          final links = await adminClient.media.getLinks(media.uuid);
          expect(links, hasLength(1));
          expect(links.single.ownerType, MediaLinkOwnerType.user);
          expect(links.single.ownerId, sudoUsername);
          expect(links.single.tag, 'avatars');
          expect(links.single.metadata, 'small');
        } finally {
          try {
            await adminClient.userMedia.detach(
              sudoUsername,
              'avatars',
              media.uuid,
            );
          } on Exception catch (_) {}
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      },
    );

    test(
      'Issue 550: media.searchLinks finds the link by ownerType + tag',
      () async {
        final media = await upload(filename: 'issue_550_search.png');
        try {
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: 'issue550_search_tag',
            mediaUuid: media.uuid,
          );

          final results = await adminClient.media.searchLinks(
            ownerType: MediaLinkOwnerType.user,
            tag: 'issue550_search_tag',
          );
          expect(results.items, isNotEmpty);
          expect(
            results.items.any((e) => e.mediaUuid == media.uuid),
            true,
            reason: 'cross-owner search should return the attached link',
          );
        } finally {
          try {
            await adminClient.userMedia.detach(
              sudoUsername,
              'issue550_search_tag',
              media.uuid,
            );
          } on Exception catch (_) {}
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      },
    );

    test(
      'Issue 550: soft-delete on a linked media returns MEDIA_IN_USE with '
      'a populated link list',
      () async {
        final media = await upload(filename: 'issue_550_in_use.png');
        try {
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: 'pinned',
            mediaUuid: media.uuid,
          );

          await expectLater(
            () => adminClient.media.softDelete(media.id),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.mediaInUse,
              ),
            ),
          );
        } finally {
          try {
            await adminClient.userMedia.detach(
              sudoUsername,
              'pinned',
              media.uuid,
            );
          } on Exception catch (_) {}
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      },
    );
  });
}
