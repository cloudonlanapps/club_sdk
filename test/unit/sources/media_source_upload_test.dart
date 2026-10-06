import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/media_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// club_server#521: a file the converter rejects answers 422
/// `MEDIA_CONVERSION_FAILED`. The SDK surfaces it at once, without retrying.
///
/// Issue 8: `ownerUsername` names the user an admin uploads on behalf of
/// (club_server#18); it is a form field, sent only when given.
void main() {
  group('upload', () {
    /// A source whose every upload is answered 201, with the multipart
    /// bodies it sent collected in [bodies].
    RemoteMediaSource acceptingSource(List<String> bodies) {
      final store = RemoteStore(
        baseUrl: 'https://example.test/v1',
        client: MockClient((request) async {
          bodies.add(latin1.decode(request.bodyBytes));
          return http.Response(
            jsonEncode({
              'id': 7,
              'uuid': 'u-7',
              'originalFilename': 'photo.png',
              'mediaType': 'image',
              'mimeType': 'image/png',
              'originalMimeType': 'image/png',
              'filename': 'u-7.png',
              'fileSize': 4,
              'preserveOriginal': false,
              'conversionStatus': 'completed',
              'uploadedBy': 'test_member',
              'accessRoles': ['self'],
              'isEncrypted': false,
              'createdAtUtc': 1700000000000,
              'updatedAtUtc': 1700000000000,
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        retryBaseDelay: Duration.zero,
      );
      return RemoteMediaSource(store);
    }

    test('Issue 8: ownerUsername is sent as a form field when given', () async {
      final bodies = <String>[];
      final media = await acceptingSource(bodies).upload(
        fileBytes: const [0, 1, 2, 3],
        filename: 'photo.png',
        contentType: 'image/png',
        accessRoles: ['self'],
        ownerUsername: 'test_member',
      );

      expect(bodies, hasLength(1));
      expect(
        bodies.single,
        matches(RegExp(r'name="ownerUsername"\r\n\r\ntest_member\r\n')),
      );
      expect(media.uploadedBy, 'test_member');
    });

    test('Issue 8: ownerUsername is absent when not given', () async {
      final bodies = <String>[];
      await acceptingSource(bodies).upload(
        fileBytes: const [0, 1, 2, 3],
        filename: 'photo.png',
        contentType: 'image/png',
      );

      expect(bodies, hasLength(1));
      expect(bodies.single, contains('name="preserveOriginal"'));
      expect(bodies.single, isNot(contains('ownerUsername')));
    });

    test(
      'club_server#521: a conversion failure surfaces as '
      'MEDIA_CONVERSION_FAILED and is sent once',
      () async {
        final requests = <http.BaseRequest>[];
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'detail': {
                  'code': 'MEDIA_CONVERSION_FAILED',
                  'message': 'The file could not be processed',
                },
              }),
              422,
              headers: {'content-type': 'application/json'},
            );
          }),
          retryBaseDelay: Duration.zero,
        );
        final source = RemoteMediaSource(store);

        await expectLater(
          source.upload(
            fileBytes: const [0, 1, 2, 3],
            filename: 'corrupt.png',
            contentType: 'image/png',
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 422)
                .having(
                  (e) => e.code,
                  'code',
                  SdkErrorCode.mediaConversionFailed,
                ),
          ),
        );
        expect(requests, hasLength(1));
        expect(requests.single.method, 'POST');
      },
    );
  });
}
