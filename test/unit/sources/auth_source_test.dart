import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/auth_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// club_server#510: logout revokes the session the access token belongs
/// to. Both tokens of a login carry its session id, so the request needs
/// nothing but the bearer token: no body is sent.
void main() {
  group('club_server#510: RemoteAuthSource.logout', () {
    test('posts the bearer token and no body, then clears the token', () async {
      final requests = <http.Request>[];
      final store = RemoteStore(
        baseUrl: 'https://example.test/v1',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
        maxRetries: 0,
      )..authToken = 'a1';

      await RemoteAuthSource(store).logout();

      final logout = requests.single;
      expect(logout.method, 'POST');
      expect(logout.url.path, endsWith('/auth/logout'));
      expect(logout.headers['Authorization'], 'Bearer a1');
      expect(logout.body, isEmpty);
      expect(store.authToken, isNull);
    });
  });
}
