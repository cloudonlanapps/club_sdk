@TestOn('vm')
library;

import 'dart:io';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/http/default_http_client.dart';
import 'package:club_sdk_2/remote_store/http/default_http_client_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 92: default HTTP client', () {
    test('Issue 92: the idle timeout is below a 5 s server keep-alive', () {
      expect(
        defaultHttpIdleTimeout,
        lessThan(const Duration(seconds: 5)),
      );
    });

    test('Issue 92: the default client sets the idle timeout', () {
      final client = configureDefaultHttpClient(
        HttpClient(),
        defaultHttpIdleTimeout,
      );
      expect(client.idleTimeout, defaultHttpIdleTimeout);
      client.close();
    });

    test('Issue 92: the default client on the VM is an IOClient', () {
      final client = createDefaultHttpClient();
      expect(client, isA<IOClient>());
      client.close();
    });

    test('Issue 92: a client passed to RemoteStore is used as is', () async {
      final requests = <http.Request>[];
      final passed = MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final store = RemoteStore(
        baseUrl: 'https://example.test/v1',
        client: passed,
      );
      await store.get('/health');
      expect(requests.single.url.path, '/v1/health');
    });
  });
}
