import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/media_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// club_server#426: the download route takes a decorative trailing filename,
/// and answers HEAD, which is how a client learns a variant's type and size
/// without fetching it.
({RemoteMediaSource source, List<http.Request> requests}) harness(
  http.Response Function(http.Request) respond,
) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return respond(request);
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
    maxRetries: 0,
  );
  return (source: RemoteMediaSource(store), requests: requests);
}

void main() {
  group('download', () {
    test('without a filename hits the bare download route', () async {
      final h = harness((_) => http.Response.bytes([1, 2, 3], 200));
      final bytes = await h.source.download('u1');
      expect(bytes, [1, 2, 3]);
      final r = h.requests.single;
      expect(r.method, 'GET');
      expect(r.url.path, endsWith('/media/by_id/u1/download'));
      expect(r.url.queryParameters['variant'], 'original');
    });

    test('with a filename appends it, percent-encoded, keeping the '
        'variant', () async {
      final h = harness((_) => http.Response.bytes([9], 200));
      await h.source.download(
        'u1',
        variant: 'poster',
        filename: 'match day.mp4',
      );
      final r = h.requests.single;
      expect(r.url.path, endsWith('/media/by_id/u1/download/match%20day.mp4'));
      expect(r.url.queryParameters['variant'], 'poster');
    });
  });

  group('probeVariant', () {
    test('sends HEAD and reads the type and size from the headers', () async {
      final h = harness(
        (_) => http.Response(
          '',
          200,
          headers: {'content-type': 'image/webp', 'content-length': '2048'},
        ),
      );
      final info = await h.source.probeVariant('u1', variant: 'poster');
      final r = h.requests.single;
      expect(r.method, 'HEAD');
      expect(r.url.path, endsWith('/media/by_id/u1/download'));
      expect(r.url.queryParameters['variant'], 'poster');
      expect(info, isNotNull);
      expect(info!.contentType, 'image/webp');
      expect(info.contentLength, 2048);
    });

    test('a missing Content-Length reads as null', () async {
      final h = harness(
        (_) => http.Response('', 200, headers: {'content-type': 'video/mp4'}),
      );
      final info = await h.source.probeVariant('u1');
      expect(info!.contentType, 'video/mp4');
      expect(info.contentLength, isNull);
      expect(h.requests.single.url.queryParameters['variant'], 'original');
    });

    test('a 404 means the variant does not exist: null', () async {
      final h = harness((_) => http.Response('', 404));
      expect(await h.source.probeVariant('u1', variant: 'poster'), isNull);
    });

    test('any other error is thrown with its status', () async {
      final h = harness((_) => http.Response('', 409));
      await expectLater(
        h.source.probeVariant('u1'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 409),
        ),
      );
    });
  });

  group('MediaVariantInfo', () {
    test('equality and hashCode follow the fields', () {
      const a = MediaVariantInfo(contentType: 'image/webp', contentLength: 1);
      const b = MediaVariantInfo(contentType: 'image/webp', contentLength: 1);
      const c = MediaVariantInfo(contentType: 'image/webp', contentLength: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('copyWith clears the length via ValueGetter', () {
      const a = MediaVariantInfo(contentType: 'image/webp', contentLength: 1);
      expect(a.copyWith(contentLength: () => null).contentLength, isNull);
      expect(a.copyWith(contentType: 'video/mp4').contentType, 'video/mp4');
    });
  });
}
