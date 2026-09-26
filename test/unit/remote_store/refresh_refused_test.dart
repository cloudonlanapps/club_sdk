import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 36: an app whose `onTokenExpired` refreshes through the same store
/// must not recurse when the server refuses the refresh token. The refresh
/// call's own 401 `INVALID_REFRESH_TOKEN` is final, not another expiry.
void main() {
  group('Issue 36: a refused refresh token ends the refresh', () {
    http.Response unauthorized(String code) => http.Response(
      jsonEncode({
        'detail': {'code': code, 'message': code},
      }),
      401,
      headers: {'content-type': 'application/json'},
    );

    test(
      'Issue 36: refreshing through the same store fails once, no loop',
      () async {
        var refreshAttempts = 0;
        late RemoteStore store;
        store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient(
            (request) async => request.url.path.endsWith('/auth/refresh')
                ? unauthorized('INVALID_REFRESH_TOKEN')
                : unauthorized('INVALID_TOKEN'),
          ),
          maxRetries: 0,
          onTokenExpired: () async {
            // Before the fix this re-entered itself without end; the cap
            // turns that into a failure instead of a hang.
            if (++refreshAttempts > 3) throw StateError('refresh loop');
            final body = await store.post(
              '/auth/refresh',
              body: {'refreshToken': 'revoked'},
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
              SdkErrorCode.invalidRefreshToken,
            ),
          ),
        );
        expect(refreshAttempts, 1);
      },
    );
  });
}
