import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 37: an error body with no readable `{code, message}` still gives
/// callers a code to branch on and a message naming the status.
void main() {
  // POST is not retried, so each case is one request.
  Future<Object?> postAnswering(http.Response response) => RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: MockClient((_) async => response),
  ).post('/events', body: const {});

  Matcher readableError(int status) => isA<ServerException>()
      .having((e) => e.statusCode, 'status', status)
      .having((e) => e.code, 'code', isNotEmpty)
      .having((e) => e.message, 'message', contains('$status'));

  // Finding 8: an error body with no readable {code, message} must still
  // give callers a code to branch on and a message naming the status.
  // Today: code '' and message 'Unknown error' (or a raw TypeError).
  group('Issue 37: unreadable error bodies', () {
    test('Issue 37: a proxy HTML 502 page', () async {
      await expectLater(
        postAnswering(
          http.Response('<html><body>502 Bad Gateway</body></html>', 502),
        ),
        throwsA(readableError(502)),
      );
    });

    test('Issue 37: an empty 504', () async {
      await expectLater(
        postAnswering(http.Response('', 504)),
        throwsA(readableError(504)),
      );
    });

    test('Issue 37: a JSON list body', () async {
      await expectLater(
        postAnswering(http.Response(jsonEncode(['oops']), 500)),
        throwsA(readableError(500)),
      );
    });

    test(
      'Issue 37: a non-string code is a ServerException, not a TypeError',
      () async {
        await expectLater(
          postAnswering(
            http.Response(
              jsonEncode({
                'detail': {'code': 42, 'message': 'x'},
              }),
              400,
            ),
          ),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });

  group('Issue 37: the fallback code and message', () {
    // A real client sets the response's request, which names the path.
    Future<Object?> postGetting(String body, int status) => RemoteStore(
      baseUrl: 'https://example.test/v1',
      client: MockClient(
        (request) async => http.Response(body, status, request: request),
      ),
    ).post('/events', body: const {});

    Matcher error(int status, String code, String message) =>
        isA<ServerException>()
            .having((e) => e.statusCode, 'status', status)
            .having((e) => e.code, 'code', code)
            .having((e) => e.message, 'message', message);

    for (final status in [502, 503, 504]) {
      test('Issue 37: an unreadable $status is SERVER_UNAVAILABLE', () async {
        await expectLater(
          postGetting('', status),
          throwsA(
            error(
              status,
              SdkErrorCode.serverUnavailable,
              'HTTP $status from /v1/events',
            ),
          ),
        );
      });
    }

    test('Issue 37: an unreadable 500 is INVALID_RESPONSE', () async {
      await expectLater(
        postGetting('<html>oops</html>', 500),
        throwsA(
          error(500, SdkErrorCode.invalidResponse, 'HTTP 500 from /v1/events'),
        ),
      );
    });

    test('Issue 37: an unreadable 401 and 403 keep their inferred codes', () {
      expect(
        mapHttpError(401, const {}),
        error(401, SdkErrorCode.notAuthenticated, 'HTTP 401'),
      );
      expect(
        mapHttpError(403, const {}),
        error(403, SdkErrorCode.insufficientPermission, 'HTTP 403'),
      );
    });

    test('Issue 37: a non-string code falls back by status', () {
      expect(
        mapHttpError(400, const {
          'detail': {'code': 42, 'message': 'x'},
        }),
        error(400, SdkErrorCode.invalidResponse, 'x'),
      );
    });

    test('Issue 37: a non-string message names the status and path', () {
      expect(
        mapHttpError(400, const {
          'detail': {'code': 'SOME_CODE', 'message': 42},
        }, path: '/v1/x'),
        error(400, 'SOME_CODE', 'HTTP 400 from /v1/x'),
      );
    });

    test('Issue 37: a readable code and message are unchanged', () async {
      await expectLater(
        postAnswering(
          http.Response(
            jsonEncode({
              'detail': {'code': 'EVENT_NOT_FOUND', 'message': 'No event'},
            }),
            404,
          ),
        ),
        throwsA(error(404, 'EVENT_NOT_FOUND', 'No event')),
      );
    });

    test('Issue 37: a 503 module-disabled code is still '
        'ModuleDisabledException', () async {
      await expectLater(
        postAnswering(
          http.Response(
            jsonEncode({
              'detail': {
                'code': SdkErrorCode.creditSystemDisabled,
                'message': 'off',
              },
            }),
            503,
          ),
        ),
        throwsA(isA<ModuleDisabledException>()),
      );
    });
  });
}
