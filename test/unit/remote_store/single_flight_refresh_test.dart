import 'dart:async';
import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 29: requests that get a 401 together share one token refresh.
void main() {
  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response expired() => json({
    'detail': {'code': 'TOKEN_EXPIRED', 'message': 'expired'},
  }, 401);

  group('Issue 29 (R2): concurrent 401s refresh the token once', () {
    test(
      'Issue 29: three GETs that all get 401 trigger one onTokenExpired',
      () async {
        var refreshes = 0;
        var calls = 0;
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient((request) async {
            calls++;
            if (request.headers['Authorization'] == 'Bearer fresh') {
              return json({'ok': true}, 200);
            }
            return json({
              'detail': {'code': 'TOKEN_EXPIRED', 'message': 'expired'},
            }, 401);
          }),
          onTokenExpired: () async {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return 'fresh';
          },
        )..authToken = 'stale';
        await Future.wait([
          store.get('/a'),
          store.get('/b'),
          store.get('/c'),
        ]);
        // Expected: one refresh shared by the three callers (single-flight).
        // Actual: three refreshes, one per request.
        expect(refreshes, 1, reason: 'calls to server: $calls');
      },
    );

    test(
      'Issue 29: all three requests succeed with the shared token',
      () async {
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient(
            (request) async =>
                request.headers['Authorization'] == 'Bearer fresh'
                ? json({'path': request.url.path}, 200)
                : expired(),
          ),
          onTokenExpired: () async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return 'fresh';
          },
        )..authToken = 'stale';

        final results = await Future.wait([
          store.get('/a'),
          store.get('/b'),
          store.get('/c'),
        ]);

        expect(results.map((r) => r['path']), ['/v1/a', '/v1/b', '/v1/c']);
        expect(store.authToken, 'fresh');
      },
    );

    test(
      'Issue 29: a refresh that returns null fails every waiting request '
      'with the original 401',
      () async {
        var refreshes = 0;
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient((_) async => expired()),
          onTokenExpired: () async {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return null;
          },
        )..authToken = 'stale';

        final outcomes = await Future.wait(
          ['/a', '/b', '/c'].map(
            (path) => store
                .get(path)
                .then<Object>((_) => 'succeeded')
                .catchError((Object e) => e),
          ),
        );

        expect(refreshes, 1);
        expect(
          outcomes,
          everyElement(
            isA<ServerException>()
                .having((e) => e.statusCode, 'status', 401)
                .having((e) => e.code, 'code', 'TOKEN_EXPIRED'),
          ),
        );
      },
    );

    test('Issue 29: a later expiry starts a new refresh', () async {
      var refreshes = 0;
      var valid = 'fresh1';
      final store = RemoteStore(
        baseUrl: 'https://example.test/v1',
        client: MockClient(
          (request) async => request.headers['Authorization'] == 'Bearer $valid'
              ? json({'ok': true}, 200)
              : expired(),
        ),
        onTokenExpired: () async {
          refreshes++;
          return 'fresh$refreshes';
        },
      )..authToken = 'stale';

      await store.get('/a');
      expect(refreshes, 1);
      expect(store.authToken, 'fresh1');

      // The server now rejects fresh1: the next 401 must refresh again
      // rather than reuse the first, finished refresh.
      valid = 'fresh2';
      await store.get('/b');
      expect(refreshes, 2);
      expect(store.authToken, 'fresh2');
    });

    test(
      'Issue 29: a refresh that throws is not reused by the next expiry',
      () async {
        var refreshes = 0;
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient(
            (request) async =>
                request.headers['Authorization'] == 'Bearer fresh'
                ? json({'ok': true}, 200)
                : expired(),
          ),
          onTokenExpired: () async {
            refreshes++;
            if (refreshes == 1) throw StateError('refresh failed');
            return 'fresh';
          },
        )..authToken = 'stale';

        await expectLater(store.get('/a'), throwsA(isA<StateError>()));
        await store.get('/b');
        expect(refreshes, 2);
      },
    );

    test(
      'Issue 29: a 401 that arrives after the refresh finished retries with '
      'the new token instead of refreshing again',
      () async {
        var refreshes = 0;
        final slowAnswer = Completer<void>();
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient((request) async {
            if (request.headers['Authorization'] == 'Bearer fresh') {
              return json({'ok': true}, 200);
            }
            // /slow was sent with the stale token, but its 401 comes back
            // only after /fast has refreshed.
            if (request.url.path.endsWith('/slow')) await slowAnswer.future;
            return expired();
          }),
          onTokenExpired: () async {
            refreshes++;
            return 'fresh';
          },
        )..authToken = 'stale';

        final slow = store.get('/slow');
        await store.get('/fast');
        slowAnswer.complete();

        expect(await slow, {'ok': true});
        expect(refreshes, 1);
      },
    );

    test(
      'Issue 29: a refresh made through this same store is not refreshed '
      'again, so it fails instead of waiting on itself',
      () async {
        var refreshes = 0;
        late RemoteStore store;
        store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          maxRetries: 0,
          client: MockClient((_) async => expired()),
          onTokenExpired: () async {
            if (++refreshes > 3) throw StateError('refresh loop');
            final body = await store.post(
              '/auth/refresh',
              body: {'refreshToken': 'r'},
            );
            return body['accessToken'] as String?;
          },
        )..authToken = 'stale';

        await expectLater(
          store.get('/users/me').timeout(const Duration(seconds: 2)),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'status', 401)
                .having((e) => e.code, 'code', 'TOKEN_EXPIRED'),
          ),
        );
        expect(refreshes, 1);
      },
    );
  });
}
