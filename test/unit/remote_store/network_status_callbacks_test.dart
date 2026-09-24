import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 729: every request through [RemoteStore] must signal network
/// reachability so the app's reactive network monitor can take over when the
/// server goes down. The store fires [RemoteStore.onServerReachable] whenever
/// an HTTP response is received (any status code) and
/// [RemoteStore.onServerUnreachable] on a connection-level failure.
void main() {
  group('Issue 729: RemoteStore network-status callbacks', () {
    late int reachableCalls;
    late int unreachableCalls;

    void onReachable() => reachableCalls++;
    void onUnreachable() => unreachableCalls++;

    setUp(() {
      reachableCalls = 0;
      unreachableCalls = 0;
    });

    RemoteStore storeWith(http.Client client) => RemoteStore(
      baseUrl: 'https://example.test/v1',
      client: client,
      onServerReachable: onReachable,
      onServerUnreachable: onUnreachable,
      maxRetries: 1,
    );

    test(
      'Issue 729: a successful response marks the server reachable',
      () async {
        final store = storeWith(
          MockClient(
            (_) async => http.Response(
              jsonEncode({'ok': true}),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );

        await store.get('/ping');

        expect(reachableCalls, 1);
        expect(unreachableCalls, 0);
      },
    );

    // An "unrelated" application error — auth, permission, validation, or even
    // a server-side 500 — still arrives as an HTTP response, proving the
    // server is reachable. None of these may push the monitor toward a
    // failure state: each marks reachable exactly once and never unreachable.
    for (final status in [401, 403, 404, 409, 422, 500]) {
      test(
        'Issue 729: an HTTP $status response marks the server reachable, '
        'never unreachable',
        () async {
          final store = storeWith(
            MockClient(
              (_) async => http.Response(
                jsonEncode({'detail': 'error $status'}),
                status,
                headers: {'content-type': 'application/json'},
              ),
            ),
          );

          await expectLater(store.get('/resource'), throwsA(isA<Object>()));

          expect(reachableCalls, 1, reason: 'status $status is reachable');
          expect(
            unreachableCalls,
            0,
            reason:
                'status $status is not a '
                'connection failure',
          );
        },
      );
    }

    test(
      'Issue 729: a connection failure marks the server unreachable',
      () async {
        final store = storeWith(
          MockClient(
            (_) async => throw const SocketException(
              'Connection refused (errno = 111)',
            ),
          ),
        );

        await expectLater(store.get('/ping'), throwsA(isA<Object>()));

        expect(unreachableCalls, 1);
        expect(reachableCalls, 0);
      },
    );

    test(
      'Issue 729: a ClientException connection failure marks the server '
      'unreachable',
      () async {
        final store = storeWith(
          MockClient(
            (_) async => throw http.ClientException(
              'Connection closed before full header was received',
            ),
          ),
        );

        await expectLater(store.get('/ping'), throwsA(isA<Object>()));

        expect(unreachableCalls, 1);
        expect(reachableCalls, 0);
      },
    );

    test(
      'Issue 729: a timeout that exhausts retries marks the server '
      'unreachable',
      () async {
        final store = storeWith(
          MockClient((_) async => throw TimeoutException('slow')),
        );

        await expectLater(store.get('/ping'), throwsA(isA<Object>()));

        expect(unreachableCalls, 1);
        expect(reachableCalls, 0);
      },
    );

    test(
      'Issue 729: callbacks are optional — a store without them still works',
      () async {
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient(
            (_) async => http.Response(jsonEncode({'ok': true}), 200),
          ),
        );

        await expectLater(store.get('/ping'), completes);
      },
    );
  });
}
