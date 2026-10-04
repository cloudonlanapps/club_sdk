import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// [RemoteStore.healthCheck] asks the server's `/health`, which sits at the
/// server root rather than under the API's `/v1` prefix.
void main() {
  group('RemoteStore.healthCheck', () {
    late List<Uri> requested;

    RemoteStore storeWith(String baseUrl, int status) {
      requested = [];
      return RemoteStore(
        baseUrl: baseUrl,
        client: MockClient((request) async {
          requested.add(request.url);
          return http.Response('{"status":"healthy"}', status);
        }),
      );
    }

    test('calls /health at the server root, not under /v1', () async {
      final store = storeWith('https://api.myexampleclub.com/v1', 200);

      await store.healthCheck();

      expect(requested, [Uri.parse('https://api.myexampleclub.com/health')]);
    });

    test('keeps a path prefix in front of /v1', () async {
      final store = storeWith('https://myexampleclub.com/api/v1', 200);

      await store.healthCheck();

      expect(requested, [Uri.parse('https://myexampleclub.com/api/health')]);
    });

    test('is true on 200', () async {
      expect(
        await storeWith('https://api.myexampleclub.com/v1', 200).healthCheck(),
        isTrue,
      );
    });

    test('is false on any other status', () async {
      for (final status in [404, 500, 503]) {
        expect(
          await storeWith(
            'https://api.myexampleclub.com/v1',
            status,
          ).healthCheck(),
          isFalse,
          reason: 'status $status',
        );
      }
    });
  });
}
