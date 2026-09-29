import 'dart:async';
import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 92: a request written onto a keep-alive connection the server has
/// just closed fails with an `http.ClientException` ("Broken pipe") before it
/// reaches the server. A safe (GET) request is retried; anything else is not,
/// since the SDK cannot tell whether the server saw it.
void main() {
  late List<http.BaseRequest> requests;
  late int unreachableCalls;

  setUp(() {
    requests = [];
    unreachableCalls = 0;
  });

  RemoteStore storeWith(FutureOr<http.Response> Function(int call) respond) {
    var calls = 0;
    return RemoteStore(
      baseUrl: 'https://example.test/v1',
      client: MockClient((request) async {
        requests.add(request);
        return respond(++calls);
      }),
      retryBaseDelay: const Duration(milliseconds: 1),
      onServerUnreachable: () => unreachableCalls++,
    );
  }

  http.Response ok() => http.Response(
    jsonEncode({'ok': true}),
    200,
    headers: {'content-type': 'application/json'},
  );

  Never brokenPipe() => throw http.ClientException(
    'Write failed (OS Error: Broken pipe, errno = 32)',
  );

  group('Issue 92: connection failures', () {
    test('Issue 92: a GET that hits a closed connection is retried and '
        'succeeds', () async {
      final store = storeWith((call) => call == 1 ? brokenPipe() : ok());

      final result = await store.get('/me');

      expect(result, {'ok': true});
      expect(requests, hasLength(2));
      expect(unreachableCalls, 0);
    });

    test('Issue 92: a GET that keeps failing gives up after the retries and '
        'reports the server unreachable', () async {
      final store = storeWith((_) => brokenPipe());

      await expectLater(
        store.get('/me'),
        throwsA(isA<http.ClientException>()),
      );

      expect(requests, hasLength(4)); // the first try + maxRetries (3)
      expect(unreachableCalls, 1);
    });

    test(
      'Issue 92: a POST that hits a closed connection is not retried',
      () async {
        final store = storeWith((call) => call == 1 ? brokenPipe() : ok());

        await expectLater(
          store.post('/events', body: {'name': 'x'}),
          throwsA(isA<http.ClientException>()),
        );

        expect(requests, hasLength(1));
        expect(unreachableCalls, 1);
      },
    );
  });
}
