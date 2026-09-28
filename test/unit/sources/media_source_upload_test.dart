import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/media_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// club_server#521: a file the converter rejects answers 422
/// `MEDIA_CONVERSION_FAILED`. The SDK surfaces it at once, without retrying.
void main() {
  group('upload', () {
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
