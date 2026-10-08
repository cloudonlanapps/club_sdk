import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/media_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 15: a media record is read by its uuid (club_server#27), the
/// identifier a media link carries, in place of paging through a listing to
/// find the id.
({RemoteMediaSource source, List<http.Request> requests}) harness(
  http.Response Function(http.Request) respond,
) {
  final requests = <http.Request>[];
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
    maxRetries: 0,
  );
  return (source: RemoteMediaSource(store), requests: requests);
}

void main() {
  group('getByUuid', () {
    test('Issue 15: reads the record from the by_uuid route', () async {
      final h = harness(
        (_) => http.Response(
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
            'deletedAtUtc': 1700000001000,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final media = await h.source.getByUuid('u-7');

      final request = h.requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/media/by_uuid/u-7'));
      expect(media.id, 7);
      expect(media.uuid, 'u-7');
      expect(media.uploadedBy, 'test_member');
      expect(media.accessRoles, ['self']);
      expect(media.deletedAtUtc, isNotNull);
    });

    test('Issue 15: a uuid the caller may not read is a ServerException '
        'with MEDIA_NOT_FOUND', () async {
      final h = harness(
        (_) => http.Response(
          jsonEncode({
            'detail': {'code': 'MEDIA_NOT_FOUND', 'message': 'Media not found'},
          }),
          404,
          headers: {'content-type': 'application/json'},
        ),
      );

      await expectLater(
        h.source.getByUuid('nope'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', 'MEDIA_NOT_FOUND'),
        ),
      );
      expect(h.requests.single.url.path, endsWith('/media/by_uuid/nope'));
    });
  });
}
