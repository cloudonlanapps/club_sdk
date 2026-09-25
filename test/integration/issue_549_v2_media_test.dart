import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

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

    group('club_server#426: named download and HEAD', () {
      test('a download with a filename returns the same bytes', () async {
        final media = await uploadImage(filename: 'issue_426_named.png');
        try {
          final plain = await adminClient.media.download(media.uuid);
          final named = await adminClient.media.download(
            media.uuid,
            filename: media.filename,
          );
          expect(named, plain);
          expect(named.length, testPngBytes.length);
        } finally {
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      });

      test(
        "probeVariant reports the original's stored type and size",
        () async {
          final media = await uploadImage(filename: 'issue_426_probe.png');
          try {
            final info = await adminClient.media.probeVariant(media.uuid);
            expect(info, isNotNull);
            expect(info!.contentType, startsWith(media.mimeType));
            expect(info.contentLength, testPngBytes.length);
          } finally {
            await adminClient.media.softDelete(media.id);
            await adminClient.media.hardDelete(media.id);
          }
        },
      );

      test('probeVariant is null for a variant the item never got', () async {
        // A PDF kept as uploaded gets no page render, so it has no poster.
        final pdf = await adminClient.media.upload(
          fileBytes: minimalPdf.codeUnits,
          filename: 'issue_426_doc.pdf',
          contentType: 'application/pdf',
          preserveOriginal: true,
        );
        try {
          expect(await adminClient.media.probeVariant(pdf.uuid), isNotNull);
          expect(
            await adminClient.media.probeVariant(pdf.uuid, variant: 'poster'),
            isNull,
          );
        } finally {
          await adminClient.media.softDelete(pdf.id);
          await adminClient.media.hardDelete(pdf.id);
        }
      });

      test('probeVariant refuses a variant the media type never has with '
          '400', () async {
        final media = await uploadImage(filename: 'issue_426_badvariant.png');
        try {
          await expectLater(
            adminClient.media.probeVariant(media.uuid, variant: 'poster'),
            throwsA(
              isA<ServerException>().having((e) => e.statusCode, 'status', 400),
            ),
          );
        } finally {
          await adminClient.media.softDelete(media.id);
          await adminClient.media.hardDelete(media.id);
        }
      });
    });
  });
}

/// The smallest PDF a parser accepts: one empty page.
const minimalPdf =
    '%PDF-1.4\n'
    '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
    '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
    '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 72 72]>>endobj\n'
    'trailer<</Root 1 0 R>>\n'
    '%%EOF\n';
