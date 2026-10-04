import 'dart:async';
import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 55: `RemoteStore`'s retry paths, pinning the fixes for #39 (a
/// module-disabled 503 is final), #40 (USER_NOT_FOUND / ACCOUNT_LEFT are not
/// refreshed), #41 (only safe methods are retried), #44 (a 2xx body that does
/// not parse is not an outage) and #49 (uploads use the injected client).
void main() {
  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response error(int status, String code) => json({
    'detail': {'code': code, 'message': code},
  }, status);

  late List<http.BaseRequest> requests;
  late int reachableCalls;
  late int unreachableCalls;

  setUp(() {
    requests = [];
    reachableCalls = 0;
    unreachableCalls = 0;
  });

  RemoteStore storeWith(
    FutureOr<http.Response> Function(http.Request request) respond, {
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 5),
    Future<String?> Function()? onTokenExpired,
  }) => RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: MockClient((request) async {
      requests.add(request);
      return respond(request);
    }),
    maxRetries: maxRetries,
    timeout: timeout,
    retryBaseDelay: const Duration(milliseconds: 1),
    onTokenExpired: onTokenExpired,
    onServerReachable: () => reachableCalls++,
    onServerUnreachable: () => unreachableCalls++,
  );

  group('Issue 55: safe requests are retried', () {
    test('a GET answered 500 then 200 succeeds after one retry', () async {
      var calls = 0;
      final store = storeWith(
        (_) => ++calls == 1
            ? error(500, 'INTERNAL_ERROR')
            : json({'ok': true}, 200),
      );

      expect(await store.get('/ping'), {'ok': true});
      expect(requests, hasLength(2));
      expect(reachableCalls, 1);
      expect(unreachableCalls, 0);
    });

    test('a GET answered 500 every time is sent 1 + maxRetries times, and '
        'the server still counts as reachable', () async {
      final store = storeWith((_) => error(500, 'INTERNAL_ERROR'));

      await expectLater(
        store.get('/ping'),
        throwsA(isA<ServerException>().having((e) => e.statusCode, '', 500)),
      );
      expect(requests, hasLength(4));
      expect(unreachableCalls, 0);
    });

    test('a plain 503 on a GET is still retried', () async {
      var calls = 0;
      final store = storeWith(
        (_) => ++calls == 1
            ? error(503, 'SERVICE_UNAVAILABLE')
            : json({'ok': true}, 200),
      );

      expect(await store.get('/ping'), {'ok': true});
      expect(requests, hasLength(2));
    });

    test('a GET that times out every time is sent 1 + maxRetries times and '
        'signals unreachable exactly once', () async {
      final store = storeWith(
        (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return json({'ok': true}, 200);
        },
        maxRetries: 2,
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(store.get('/ping'), throwsA(isA<TimeoutException>()));
      expect(requests, hasLength(3));
      expect(unreachableCalls, 1);
      expect(reachableCalls, 0);
    });
  });

  group('Issue 39: a feature-off 503 is final', () {
    for (final code in SdkErrorCode.moduleDisabledCodes) {
      test(
        'a 503 $code throws ModuleDisabledException after one request',
        () async {
          final store = storeWith((_) => error(503, code));

          await expectLater(
            store.get('/credits/me'),
            throwsA(isA<ModuleDisabledException>()),
          );
          expect(requests, hasLength(1));
        },
      );
    }

    test('a 503 ENCRYPTION_NOT_CONFIGURED fails after one request', () async {
      final store = storeWith(
        (_) => error(503, SdkErrorCode.encryptionNotConfigured),
      );

      await expectLater(
        store.get('/media/by_id/m1/download'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.encryptionNotConfigured,
          ),
        ),
      );
      expect(requests, hasLength(1));
    });
  });

  group('Issue 41: non-idempotent requests are not retried', () {
    final calls = <String, Future<Object?> Function(RemoteStore)>{
      'POST': (s) => s.post('/events', body: {'a': 1}),
      'POST (void)': (s) => s.postVoid('/events/1/cancel'),
      'PUT': (s) => s.put('/events/1', body: {'a': 1}),
      'PUT (void)': (s) => s.putVoid('/events/1', body: {'a': 1}),
      'PATCH': (s) => s.patch('/events/1', body: {'a': 1}),
      'DELETE': (s) => s.delete('/events/1'),
      'upload': (s) => s.uploadMultipart(
        '/media',
        fileBytes: [1, 2, 3],
        filename: 'a.jpg',
      ),
    };

    for (final MapEntry(key: name, value: call) in calls.entries) {
      test('a $name answered 500 is sent once', () async {
        final store = storeWith((_) => error(500, 'INTERNAL_ERROR'));

        await expectLater(
          call(store),
          throwsA(isA<ServerException>().having((e) => e.statusCode, '', 500)),
        );
        expect(requests, hasLength(1));
        expect(unreachableCalls, 0);
      });

      test('a $name that times out is sent once and signals unreachable '
          'once', () async {
        final store = storeWith((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return json({'ok': true}, 200);
        }, timeout: const Duration(milliseconds: 20));

        await expectLater(call(store), throwsA(isA<TimeoutException>()));
        expect(requests, hasLength(1));
        expect(unreachableCalls, 1);
      });
    }
  });

  group('Issue 44: a 2xx body that does not parse is not an outage', () {
    final bodies = <String, http.Response>{
      'an HTML page': http.Response('<html>proxy</html>', 200),
      'a list where a map was expected': json([1, 2], 200),
      'a null body': json(null, 200),
    };

    for (final MapEntry(key: name, value: response) in bodies.entries) {
      test('$name throws INVALID_RESPONSE, marks reachable, and is not '
          'retried', () async {
        final store = storeWith((_) => response);

        await expectLater(
          store.get('/ping'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidResponse,
            ),
          ),
        );
        expect(requests, hasLength(1));
        expect(reachableCalls, 1);
        expect(unreachableCalls, 0);
      });
    }

    test('getList with a map lacking items throws INVALID_RESPONSE', () async {
      final store = storeWith((_) => json({'a': 1}, 200));

      await expectLater(
        store.getList('/things'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidResponse,
          ),
        ),
      );
      expect(unreachableCalls, 0);
    });

    test('getOrNull returns null for a null body without signalling '
        'unreachable', () async {
      final store = storeWith((_) => json(null, 200));

      expect(await store.getOrNull('/maybe'), isNull);
      expect(reachableCalls, 1);
      expect(unreachableCalls, 0);
    });

    test('getOrNull returns the map for an object body', () async {
      final store = storeWith((_) => json({'a': 1}, 200));

      expect(await store.getOrNull('/maybe'), {'a': 1});
    });
  });

  group('Issue 40: a refresh that cannot help is not attempted', () {
    for (final code in [
      SdkErrorCode.userNotFound,
      SdkErrorCode.accountLeft,
    ]) {
      test('a 401 $code fails without calling onTokenExpired', () async {
        var refreshAttempts = 0;
        final store = storeWith(
          (_) => error(401, code),
          onTokenExpired: () async {
            refreshAttempts++;
            return 'new';
          },
        )..authToken = 'old';

        await expectLater(
          store.get('/users/me'),
          throwsA(isA<ServerException>().having((e) => e.code, 'code', code)),
        );
        expect(refreshAttempts, 0);
        expect(requests, hasLength(1));
      });
    }

    test('refreshing through the same store fails with USER_NOT_FOUND after '
        'one callback, no loop', () async {
      var refreshAttempts = 0;
      late RemoteStore store;
      store = storeWith(
        (request) => request.url.path.endsWith('/auth/refresh')
            ? error(401, SdkErrorCode.userNotFound)
            : error(401, 'INVALID_TOKEN'),
        maxRetries: 0,
        onTokenExpired: () async {
          if (++refreshAttempts > 3) throw StateError('refresh loop');
          final body = await store.post(
            '/auth/refresh',
            body: {'refreshToken': 'r'},
          );
          return body['accessToken'] as String?;
        },
      )..authToken = 'expired';

      await expectLater(
        store.get('/users/me'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.userNotFound,
          ),
        ),
      );
      expect(refreshAttempts, 1);
    });
  });

  group('Issue 49: uploads use the injected client', () {
    test('an upload through a MockClient reaches the mock', () async {
      final store = storeWith((_) => json({'id': 'm1'}, 201));

      final result = await store.uploadMultipart(
        '/media',
        fileBytes: [1, 2, 3],
        filename: 'a.jpg',
        contentType: 'image/jpeg',
        fields: {'title': 't'},
      );

      expect(result, {'id': 'm1'});
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/v1/media');
      expect(
        requests.single.headers['content-type'],
        startsWith('multipart/form-data'),
      );
    });
  });
}
