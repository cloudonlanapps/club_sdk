import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/my_credits_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A [RemoteMyCreditsSource] over a mock client that records each request
/// and answers with an empty statement page.
({RemoteMyCreditsSource source, List<http.Request> requests})
myCreditsHarness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({'items': <dynamic>[], 'total': 0, 'offset': 0, 'limit': 50}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteMyCreditsSource(store), requests: requests);
}

void main() {
  group('RemoteMyCreditsSource.listMyEntries', () {
    test('Issue 22: sends the order by its wire name', () async {
      final h = myCreditsHarness();

      await h.source.listMyEntries('alice', order: EntryOrder.oldestFirst);

      final uri = h.requests.single.url;
      expect(uri.path, '/v1/mycredits/by_id/alice/entries');
      expect(uri.queryParameters['order'], 'asc');
    });

    test("Issue 22: omits the order so the server's default applies", () async {
      final h = myCreditsHarness();

      await h.source.listMyEntries('alice');

      expect(
        h.requests.single.url.queryParameters.containsKey('order'),
        isFalse,
      );
    });
  });
}
