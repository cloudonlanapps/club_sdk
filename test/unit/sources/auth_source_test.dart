import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/auth_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// club_server#510: logout revokes the session it is called with, access
/// and refresh token alike. The SDK sends the session's refresh token in the
/// logout body, so the server can revoke it whichever way it identifies the
/// session, and any logged-in user may log out whatever their status.
void main() {
  late List<http.Request> requests;

  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response tokens(String access, String refresh) => json({
    'accessToken': access,
    'tokenType': 'bearer',
    'expiresAtUtc': DateTime.utc(2030).millisecondsSinceEpoch,
    'refreshToken': refresh,
  }, 200);

  RemoteStore storeWith(http.Response Function(http.Request) respond) {
    requests = [];
    return RemoteStore(
      baseUrl: 'https://example.test/v1',
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
      maxRetries: 0,
    );
  }

  http.Response respond(http.Request r) {
    if (r.url.path.endsWith('/auth/login')) return tokens('a1', 'r1');
    if (r.url.path.endsWith('/auth/refresh')) return tokens('a2', 'r2');
    return http.Response('', 204);
  }

  Map<String, dynamic>? bodyOf(http.Request r) =>
      r.body.isEmpty ? null : jsonDecode(r.body) as Map<String, dynamic>;

  group('club_server#510: RemoteAuthSource.logout', () {
    test('sends the refresh token from login', () async {
      final auth = RemoteAuthSource(storeWith(respond));
      await auth.login('u', 'p');
      await auth.logout();

      final logout = requests.last;
      expect(logout.url.path, endsWith('/auth/logout'));
      expect(logout.headers['Authorization'], 'Bearer a1');
      expect(bodyOf(logout), {'refreshToken': 'r1'});
    });

    test('sends the refresh token from the latest refresh', () async {
      final auth = RemoteAuthSource(storeWith(respond));
      await auth.login('u', 'p');
      await auth.refreshToken('r1');
      await auth.logout();

      expect(bodyOf(requests.last), {'refreshToken': 'r2'});
    });

    test(
      'sends a refresh token the caller passes, over a remembered one',
      () async {
        final auth = RemoteAuthSource(storeWith(respond));
        await auth.login('u', 'p');
        await auth.logout(refreshToken: 'restored');

        expect(bodyOf(requests.last), {'refreshToken': 'restored'});
      },
    );

    test('sends no body when no refresh token is known', () async {
      final store = storeWith(respond)..authToken = 'restored-access';
      await RemoteAuthSource(store).logout();

      expect(requests.single.url.path, endsWith('/auth/logout'));
      expect(bodyOf(requests.single), isNull);
    });

    test('forgets the refresh token once logged out', () async {
      final auth = RemoteAuthSource(storeWith(respond));
      await auth.login('u', 'p');
      await auth.logout();
      await auth.logout();

      expect(bodyOf(requests.last), isNull);
    });
  });
}
