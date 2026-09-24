import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// SDK-side end-to-end coverage of the v2 media flow that backs
/// `clIdentityDocsMasterProvider` in `cl_remote_store` (#573).
///
/// Mirrors the avatar test (#554) but exercises additive uploads under the
/// `identity_document` tag with restricted access roles. The provider
/// itself is glue around these calls — proving the calls work against the
/// real server is enough; the glue is exercised in unit tests.
void main() {
  group('Issue 573: identity-document upload/list/discard via v2 media', () {
    late SecureClient adminClient;

    const tag = 'identity_document';
    const accessRoles = ['self', 'admin'];

    final pngBytes = <int>[
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
      try {
        await adminClient.userMedia.detachTag(sudoUsername, tag);
      } on Exception catch (_) {}
      await adminClient.auth.logout();
    });

    test(
      'Issue 573: upload + attach with restricted access roles records '
      'access_roles=[self,admin] and surfaces in listByTag',
      () async {
        final media = await adminClient.media.upload(
          fileBytes: pngBytes,
          filename: 'issue_573_aadhaar.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: accessRoles,
        );
        expect(media.accessRoles, containsAll(accessRoles));
        expect(media.accessRoles, isNot(contains('public')));
        expect(media.accessRoles, isNot(contains('coach')));

        try {
          final link = await adminClient.userMedia.attach(
            sudoUsername,
            tag: tag,
            mediaUuid: media.uuid,
          );
          expect(link.tag, tag);
          expect(link.mediaUuid, media.uuid);

          final links = await adminClient.userMedia.listByTag(
            sudoUsername,
            tag,
          );
          expect(links, hasLength(1));
          expect(links.single.mediaUuid, media.uuid);
        } finally {
          try {
            await adminClient.userMedia.detachTag(sudoUsername, tag);
          } on Exception catch (_) {}
          await adminClient.media.softDelete(media.id);
        }
      },
    );

    test(
      'Issue 573: identity-document uploads are additive — two attaches '
      'leave both links visible',
      () async {
        final first = await adminClient.media.upload(
          fileBytes: pngBytes,
          filename: 'issue_573_doc_1.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: accessRoles,
        );
        final second = await adminClient.media.upload(
          fileBytes: pngBytes,
          filename: 'issue_573_doc_2.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: accessRoles,
        );
        try {
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: tag,
            mediaUuid: first.uuid,
          );
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: tag,
            mediaUuid: second.uuid,
          );

          final links = await adminClient.userMedia.listByTag(
            sudoUsername,
            tag,
          );
          expect(links, hasLength(2));
          expect(
            links.map((l) => l.mediaUuid),
            containsAll([first.uuid, second.uuid]),
          );
        } finally {
          try {
            await adminClient.userMedia.detachTag(sudoUsername, tag);
          } on Exception catch (_) {}
          await adminClient.media.softDelete(first.id);
          await adminClient.media.softDelete(second.id);
        }
      },
    );

    test(
      'Issue 573: discard detaches link first then soft-deletes media — '
      'reverse order is rejected with MEDIA_IN_USE',
      () async {
        final media = await adminClient.media.upload(
          fileBytes: pngBytes,
          filename: 'issue_573_discard.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: accessRoles,
        );
        await adminClient.userMedia.attach(
          sudoUsername,
          tag: tag,
          mediaUuid: media.uuid,
        );

        // Try wrong order first — server refuses softDelete while linked.
        await expectLater(
          adminClient.media.softDelete(media.id),
          throwsA(isA<ServerException>()),
        );

        // Correct order: detach, then softDelete.
        await adminClient.userMedia.detach(sudoUsername, tag, media.uuid);
        await adminClient.media.softDelete(media.id);

        final links = await adminClient.userMedia.listByTag(sudoUsername, tag);
        expect(links, isEmpty);
      },
    );
  });
}
