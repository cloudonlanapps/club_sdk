import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';

/// club_server#521: an image or PDF the converter rejects answers 422
/// `MEDIA_CONVERSION_FAILED` (not 500), and no media item is created.
///
/// The uploads leave `preserveOriginal` off: that is what runs the converter.
void main() {
  group('club_server#521: a corrupt upload', () {
    late SecureClient sudoClient;

    /// A PNG signature followed by bytes that are no image at all.
    final corruptPng = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ...utf8.encode('test_i521 this is not an image'),
    ];

    /// Named and typed as a PDF, but no PDF: Ghostscript fails on it. (A
    /// `%PDF` header over garbage is not enough — Ghostscript exits 0 on it
    /// and renders nothing.)
    final corruptPdf = utf8.encode('test_i521 this is not a PDF at all');

    Future<bool> listed(String filename) async {
      final mine = await sudoClient.media.listMyFiles(limit: 100);
      return mine.items.any((m) => m.originalFilename == filename);
    }

    Matcher conversionFailed() => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', SdkErrorCode.mediaConversionFailed),
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
    });

    tearDownAll(() async {
      await sudoClient.auth.logout();
    });

    test('a corrupt image answers 422 MEDIA_CONVERSION_FAILED and is not '
        'listed', () async {
      const filename = 'test_i521_corrupt.png';

      await expectLater(
        sudoClient.media.upload(
          fileBytes: corruptPng,
          filename: filename,
          contentType: 'image/png',
        ),
        conversionFailed(),
      );
      expect(await listed(filename), isFalse);
    });

    test('a corrupt PDF answers 422 MEDIA_CONVERSION_FAILED and is not '
        'listed', () async {
      const filename = 'test_i521_corrupt.pdf';

      await expectLater(
        sudoClient.media.upload(
          fileBytes: corruptPdf,
          filename: filename,
          contentType: 'application/pdf',
        ),
        conversionFailed(),
      );
      expect(await listed(filename), isFalse);
    });
  });
}
