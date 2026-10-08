import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// SDK-side end-to-end coverage of the v2 media flow that backs the
/// `avatarImageProvider` + `avatarMutationProvider` from `cl_remote_store`
/// (#554).
///
/// The provider itself is glue around these calls — proving the calls work
/// against the real server is enough; the glue is unit-checked by analyze.
void main() {
  group('Issue 554: avatar upload/replace/clear via v2 media', () {
    late SecureClient adminClient;

    const tag = 'user_avatar';

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
      // Best-effort cleanup.
      try {
        await adminClient.userMedia.detachTag(sudoUsername, tag);
      } on Exception catch (_) {}
      await adminClient.auth.logout();
    });

    test(
      'Issue 554: upload + attach makes listByTag find the new avatar',
      () async {
        final media = await adminClient.media.upload(
          fileBytes: testPngBytes,
          filename: 'issue_554_initial.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: const ['public'],
        );
        expect(media.accessRoles, contains('public'));

        try {
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: tag,
            mediaUuid: media.uuid,
          );

          final links = await adminClient.userMedia.listByTag(
            sudoUsername,
            tag,
          );
          expect(links, hasLength(1));
          expect(links.single.mediaUuid, media.uuid);
          expect(links.single.tag, tag);
        } finally {
          try {
            await adminClient.userMedia.detachTag(sudoUsername, tag);
          } on Exception catch (_) {}
          await adminClient.media.softDelete(media.id);
        }
      },
    );

    test(
      'Issue 554: attaching a new avatar replaces the prior one',
      () async {
        final first = await adminClient.media.upload(
          fileBytes: testPngBytes,
          filename: 'issue_554_first.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: const ['public'],
        );
        await adminClient.userMedia.attach(
          sudoUsername,
          tag: tag,
          mediaUuid: first.uuid,
        );

        Media? second;
        try {
          final priorSnapshot = await adminClient.userMedia.listByTag(
            sudoUsername,
            tag,
          );
          expect(priorSnapshot, hasLength(1));

          second = await adminClient.media.upload(
            fileBytes: testPngBytes,
            filename: 'issue_554_second.png',
            contentType: 'image/png',
            preserveOriginal: true,
            accessRoles: const ['self', 'admin', 'coach'],
          );
          expect(second.accessRoles, containsAll(['self', 'admin', 'coach']));
          expect(second.accessRoles, isNot(contains('public')));

          await adminClient.userMedia.attach(
            sudoUsername,
            tag: tag,
            mediaUuid: second.uuid,
          );

          // The server keeps a user to one avatar (club_server#28): the
          // attach removed the prior link and soft-deleted its file, so
          // there is nothing left to detach or delete.

          final after = await adminClient.userMedia.listByTag(
            sudoUsername,
            tag,
          );
          expect(after, hasLength(1));
          expect(after.single.mediaUuid, second.uuid);
          final prior = await adminClient.media.getById(first.id);
          expect(prior.deletedAtUtc, isNotNull);
        } finally {
          try {
            await adminClient.userMedia.detachTag(sudoUsername, tag);
          } on Exception catch (_) {}
          if (second != null) {
            await adminClient.media.softDelete(second.id);
          }
        }
      },
    );

    test(
      'Issue 554: clear detaches every avatar link for the user',
      () async {
        final media = await adminClient.media.upload(
          fileBytes: testPngBytes,
          filename: 'issue_554_clear.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: const ['public'],
        );
        await adminClient.userMedia.attach(
          sudoUsername,
          tag: tag,
          mediaUuid: media.uuid,
        );

        try {
          var links = await adminClient.userMedia.listByTag(sudoUsername, tag);
          expect(links, isNotEmpty);

          await adminClient.userMedia.detachTag(sudoUsername, tag);

          links = await adminClient.userMedia.listByTag(sudoUsername, tag);
          expect(links, isEmpty);
        } finally {
          await adminClient.media.softDelete(media.id);
        }
      },
    );
  });
}
