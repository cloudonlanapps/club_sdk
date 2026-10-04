import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/credit_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A [RemoteCreditSource] over a mock client that records each request and
/// answers with [body].
({RemoteCreditSource source, List<http.Request> requests}) creditHarness(
  Map<String, dynamic> body,
) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteCreditSource(store), requests: requests);
}

const rosterPage = <String, dynamic>{
  'items': [
    {
      'membername': 'alice',
      'usableCredits': 0,
      'boundCredits': 3,
      'payingAccountId': null,
      'blocked': true,
      'nextExpiryUtc': null,
    },
  ],
  'total': 1,
  'offset': 0,
  'limit': 50,
};

const entryPage = <String, dynamic>{
  'items': [
    {
      'id': 41,
      'accountId': 'AB12CD34',
      'membername': 'alice',
      'amount': -1,
      'entryType': 'sessionDeduction',
      'eventId': 9,
      'occurrenceTimeUtc': null,
      'reason': 'Attendance',
      'actorUsername': 'coach1',
      'createdAtUtc': 1790000000000,
      'offsetsEntryId': null,
      'balanceAfter': 9,
      'totalAfter': 9,
    },
  ],
  'total': 1,
  'offset': 0,
  'limit': 50,
};

void main() {
  group('RemoteCreditSource.listEventCredits', () {
    test('Issue 20: sends the roster filter by its wire name', () async {
      final h = creditHarness(rosterPage);
      final before = DateTime.utc(2026, 11);

      await h.source.listEventCredits(
        9,
        filter: RosterCreditFilter.expiringSoon,
        expiringBeforeUtc: before,
      );

      final uri = h.requests.single.url;
      expect(h.requests.single.method, 'GET');
      expect(uri.path, '/v1/events/by_id/9/credits');
      expect(uri.queryParameters['state'], 'expiringSoon');
      expect(
        uri.queryParameters['expiringBeforeUtc'],
        before.millisecondsSinceEpoch.toString(),
      );
    });

    test('Issue 20: omits the filter when none is given', () async {
      final h = creditHarness(rosterPage);

      await h.source.listEventCredits(9);

      expect(
        h.requests.single.url.queryParameters.containsKey('state'),
        isFalse,
      );
    });

    test('Issue 20: parses boundCredits on each row', () async {
      final h = creditHarness(rosterPage);

      final page = await h.source.listEventCredits(
        9,
        filter: RosterCreditFilter.blocked,
      );

      expect(h.requests.single.url.queryParameters['state'], 'blocked');
      expect(page.items.single.boundCredits, 3);
      expect(page.items.single.blocked, isTrue);
    });
  });

  group('RemoteCreditSource.listEntries', () {
    test('Issue 22: sends the order by its wire name', () async {
      final h = creditHarness(entryPage);

      final page = await h.source.listEntries(
        accountId: 'AB12CD34',
        order: EntryOrder.newestFirst,
      );

      final uri = h.requests.single.url;
      expect(uri.path, '/v1/credits/entries');
      expect(uri.queryParameters['order'], 'desc');
      expect(uri.queryParameters['accountId'], 'AB12CD34');
      expect(page.items.single.balanceAfter, 9);
      expect(page.items.single.totalAfter, 9);
    });

    test("Issue 22: omits the order so the server's default applies", () async {
      final h = creditHarness(entryPage);

      await h.source.listEntries();

      expect(
        h.requests.single.url.queryParameters.containsKey('order'),
        isFalse,
      );
    });
  });
}
