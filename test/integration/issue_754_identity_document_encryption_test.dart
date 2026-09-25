import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// End-to-end coverage of encrypted identity documents (#754): a document
/// uploaded with `encrypt: true` is stored encrypted at rest, yet the admin
/// review path recovers it intact — the link is listable and the download
/// returns the exact original bytes (the server decrypts transparently).
///
/// Requires the test stack to have an `ENCRYPTION_KEY` configured;
/// `scripts/start_test_server` sets a throwaway one, so encrypted uploads
/// don't return 503 here.
void main() {
  group('Issue 754: encrypted identity document round-trip', () {
    late SecureClient adminClient;

    const tag = 'identity_document';
    const accessRoles = ['self', 'admin'];

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
      'Issue 754: identity document uploaded with encrypt:true is stored '
      'encrypted, and the admin review path recovers the original bytes',
      () async {
        // Upload as the user would, but requesting encryption at rest.
        final media = await adminClient.media.upload(
          fileBytes: testPngBytes,
          filename: 'issue_754_id.png',
          contentType: 'image/png',
          preserveOriginal: true,
          accessRoles: accessRoles,
          encrypt: true,
        );

        // Stored encrypted, still restricted to self/admin.
        expect(media.isEncrypted, isTrue, reason: 'must be encrypted at rest');
        expect(media.accessRoles, containsAll(accessRoles));
        expect(media.accessRoles, isNot(contains('public')));

        try {
          await adminClient.userMedia.attach(
            sudoUsername,
            tag: tag,
            mediaUuid: media.uuid,
          );

          // What the admin review view reads: the identity_document link...
          final links = await adminClient.userMedia.listByTag(
            sudoUsername,
            tag,
          );
          expect(links, hasLength(1));
          expect(links.single.mediaUuid, media.uuid);

          // ...and the image bytes behind it. The server decrypts on download,
          // so the admin sees the exact original — proving recovery works.
          final bytes = await adminClient.media.download(media.uuid);
          expect(bytes, equals(testPngBytes));
        } finally {
          try {
            await adminClient.userMedia.detachTag(sudoUsername, tag);
          } on Exception catch (_) {}
          await adminClient.media.softDelete(media.id);
        }
      },
    );
  });
}
