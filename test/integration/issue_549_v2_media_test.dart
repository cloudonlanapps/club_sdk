import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// Integration tests for the v2 media foundation (#549, server #161).
///
/// Exercises every endpoint on `client.media`:
/// - upload (image with preserveOriginal=true to avoid needing
///   media_convert.sh on the test stack)
/// - list / listMyFiles
/// - getById
/// - patch (accessRoles)
/// - download (variant=original)
/// - getLinksRaw (placeholder — replaced by typed list in #550)
/// - softDelete → restore → softDelete → hardDelete lifecycle
void main() {
  group('Issue 549: v2 media foundation', () {
    late SecureClient adminClient;

    // Minimal valid 1x1 white PNG (67 bytes). Borrowed from s14_files_test.
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

    Future<Media> uploadImage({
      String filename = 'issue_549.png',
      List<String>? accessRoles,
    }) {
      return adminClient.media.upload(
        fileBytes: testPngBytes,
        filename: filename,
        contentType: 'image/png',
        preserveOriginal: true,
        accessRoles: accessRoles,
      );
    }

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

    test('Issue 549: upload returns Media with expected fields', () async {
      final media = await uploadImage(filename: 'issue_549_upload.png');

      expect(media.id, isPositive);
      expect(media.uuid, isNotEmpty);
      expect(media.originalFilename, 'issue_549_upload.png');
      expect(media.mediaType, 'image');
      expect(media.mimeType, 'image/png');
      expect(media.fileSize, testPngBytes.length);
      expect(media.preserveOriginal, true);
      expect(media.uploadedBy, sudoUsername);
      expect(media.accessRoles, isNotEmpty);
      expect(media.isEncrypted, false);
      expect(media.isDeleted, false);

      // cleanup
      await adminClient.media.softDelete(media.id);
      await adminClient.media.hardDelete(media.id);
    });

    test('Issue 549: list and listMyFiles return the uploaded media', () async {
      final media = await uploadImage(filename: 'issue_549_list.png');
      try {
        final all = await adminClient.media.list();
        expect(
          all.items.any((m) => m.id == media.id),
          true,
          reason: 'admin list should include the uploaded media',
        );

        final mine = await adminClient.media.listMyFiles();
        expect(
          mine.items.any((m) => m.id == media.id),
          true,
          reason: "listMyFiles should include the caller's uploads",
        );

        final filtered = await adminClient.media.list(mediaType: 'image');
        for (final m in filtered.items) {
          expect(m.mediaType, 'image');
        }
      } finally {
        await adminClient.media.softDelete(media.id);
        await adminClient.media.hardDelete(media.id);
      }
    });

    test('Issue 549: getById returns the full record', () async {
      final media = await uploadImage(filename: 'issue_549_get.png');
      try {
        final fetched = await adminClient.media.getById(media.id);
        expect(fetched.id, media.id);
        expect(fetched.uuid, media.uuid);
        expect(fetched.originalFilename, media.originalFilename);
      } finally {
        await adminClient.media.softDelete(media.id);
        await adminClient.media.hardDelete(media.id);
      }
    });

    test('Issue 549: patch updates accessRoles', () async {
      final media = await uploadImage(filename: 'issue_549_patch.png');
      try {
        final updated = await adminClient.media.patch(
          media.id,
          accessRoles: ['admin', 'coach'],
        );
        expect(updated.accessRoles, containsAll(<String>['admin', 'coach']));
      } finally {
        await adminClient.media.softDelete(media.id);
        await adminClient.media.hardDelete(media.id);
      }
    });

    test('Issue 549: download returns the original bytes', () async {
      final media = await uploadImage(filename: 'issue_549_download.png');
      try {
        final bytes = await adminClient.media.download(media.uuid);
        expect(bytes, isNotEmpty);
        expect(bytes.length, testPngBytes.length);
      } finally {
        await adminClient.media.softDelete(media.id);
        await adminClient.media.hardDelete(media.id);
      }
    });

    test(
      'Issue 549: getLinksRaw is empty for a newly uploaded media',
      () async {
        final media = await uploadImage(filename: 'issue_549_links.png');
        try {
          final links = await adminClient.media.getLinksRaw(media.uuid);
          expect(links, isEmpty);
        } finally {
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      },
    );

    test(
      'Issue 549: soft-delete → restore → soft-delete → hard-delete',
      () async {
        final media = await uploadImage(filename: 'issue_549_lifecycle.png');

        await adminClient.media.softDelete(media.id);
        final afterSoft = await adminClient.media.getById(media.id);
        expect(afterSoft.isDeleted, true);

        final restored = await adminClient.media.restore(media.id);
        expect(restored.isDeleted, false);

        await adminClient.media.softDelete(media.id);
        await adminClient.media.hardDelete(media.id);

        expect(
          () => adminClient.media.getById(media.id),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test(
      'Issue 549: hard-delete on a non-soft-deleted record returns '
      'MEDIA_NOT_DELETED',
      () async {
        final media = await uploadImage(
          filename: 'issue_549_hard_not_deleted.png',
        );
        try {
          await expectLater(
            () => adminClient.media.hardDelete(media.id),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.mediaNotDeleted,
              ),
            ),
          );
        } finally {
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      },
    );
  });
}
