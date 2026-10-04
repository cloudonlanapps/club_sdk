import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 9: a login-free public source is built through the public API,
/// with no import from inside the package.
void main() {
  group('Issue 9: createRemotePublicSource', () {
    ({PublicSource source, List<http.Request> requests}) harness() {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'clubInfo': {'name': 'My Example Club'},
            'siteMedia': <String, dynamic>{},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      const base = 'https://api.myexampleclub.com/v1';
      final source = createRemotePublicSource(
        baseUrl: base,
        store: RemoteStore(baseUrl: base, client: client),
      );
      return (source: source, requests: requests);
    }

    test('reads the /public routes on the given base URL', () async {
      final h = harness();
      final info = await h.source.getPublicClubInfo();
      expect(info.clubInfo['name'], 'My Example Club');
      final r = h.requests.single;
      expect(r.method, 'GET');
      expect(r.url.host, 'api.myexampleclub.com');
      expect(r.url.path, '/v1/public/club-info');
    });

    test('sends no Authorization header', () async {
      final h = harness();
      await h.source.getPublicClubInfo();
      expect(h.requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('builds its own store from baseUrl when none is given', () {
      final source = createRemotePublicSource(
        baseUrl: 'https://api.myexampleclub.com/v1',
      );
      expect(source, isA<PublicSource>());
    });
  });
}
