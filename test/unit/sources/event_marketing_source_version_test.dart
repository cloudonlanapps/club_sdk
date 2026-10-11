import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_marketing_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 1: an event's marketing block has a version of its own, sent with
/// the replace (`PUT`, in the body) and the removal (`DELETE`, as a query
/// parameter) (club_server#13).
({RemoteEventMarketingSource source, List<http.Request> requests}) harness(
  http.Response answer,
) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return answer;
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteEventMarketingSource(store), requests: requests);
}

http.Response json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  final writtenAt = DateTime.utc(2027, 2, 1, 9);
  final stored = {
    'eventId': 42,
    'fee': 500,
    'urgencyText': 'Limited seats!',
    'version': 4,
    'updatedAt': writtenAt.millisecondsSinceEpoch,
    'updatedBy': 'admin_1',
  };

  group('Issue 1: reading the marketing block', () {
    test('Issue 1: getEventMarketing reads the version and who wrote it '
        'last', () async {
      final h = harness(json(200, stored));
      final block = await h.source.getEventMarketing(42);
      expect(h.requests.single.method, 'GET');
      expect(
        h.requests.single.url.path,
        endsWith('/events/by_id/42/marketing'),
      );
      expect(block.version, 4);
      expect(block.updatedAtUtc, writtenAt);
      expect(block.updatedBy, 'admin_1');
      expect(block.fee, 500);
    });
  });

  group('Issue 1: replacing the marketing block', () {
    test('Issue 1: setEventMarketing puts the version beside the '
        'fields', () async {
      final h = harness(json(200, stored));
      await h.source.setEventMarketing(
        42,
        const EventMarketing(fee: 500, urgencyText: 'Limited seats!'),
        version: 3,
      );
      final r = h.requests.single;
      expect(r.method, 'PUT');
      expect(r.url.path, endsWith('/events/by_id/42/marketing'));
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['version'], 3);
      expect(body['fee'], 500);
      expect(body['urgencyText'], 'Limited seats!');
    });

    test('Issue 1: setEventMarketing sends the version it is given, not '
        'the one on the block', () async {
      final h = harness(json(200, stored));
      final loaded = EventMarketing.fromMap(stored);
      await h.source.setEventMarketing(42, loaded, version: 9);
      final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
      expect(body['version'], 9);
    });

    test('Issue 1: setEventMarketing does not send back who wrote the '
        'block last', () async {
      final h = harness(json(200, stored));
      final loaded = EventMarketing.fromMap(stored);
      await h.source.setEventMarketing(42, loaded, version: loaded.version);
      final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
      expect(body.containsKey('updatedAt'), isFalse);
      expect(body.containsKey('updatedBy'), isFalse);
    });

    test('Issue 1: setEventMarketing returns the block at its new '
        'version', () async {
      final h = harness(json(200, stored));
      final block = await h.source.setEventMarketing(
        42,
        const EventMarketing(fee: 500),
        version: 3,
      );
      expect(block.version, 4);
      expect(block.updatedBy, 'admin_1');
    });
  });

  group('Issue 1: removing the marketing block', () {
    test('Issue 1: clearEventMarketing deletes with the version as a '
        'query parameter', () async {
      final h = harness(http.Response('', 204));
      await h.source.clearEventMarketing(42, version: 4);
      final r = h.requests.single;
      expect(r.method, 'DELETE');
      expect(r.url.path, endsWith('/events/by_id/42/marketing'));
      expect(r.url.queryParameters, {'version': '4'});
      expect(r.body, isEmpty);
    });
  });

  group('Issue 1: a marketing write at a stale version', () {
    http.Response stale({int? updatedAt, String? updatedBy}) => json(409, {
      'detail': {
        'code': 'STALE_VERSION',
        'message': 'The event marketing was changed since you last loaded it',
        'version': 5,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      },
    });

    test('Issue 1: setEventMarketing throws StaleVersionException with '
        'the current version and writer', () async {
      final h = harness(
        stale(
          updatedAt: writtenAt.millisecondsSinceEpoch,
          updatedBy: 'admin_2',
        ),
      );
      await expectLater(
        h.source.setEventMarketing(
          42,
          const EventMarketing(fee: 500),
          version: 3,
        ),
        throwsA(
          isA<StaleVersionException>()
              .having((e) => e.version, 'version', 5)
              .having((e) => e.updatedAtUtc, 'updatedAtUtc', writtenAt)
              .having((e) => e.updatedBy, 'updatedBy', 'admin_2'),
        ),
      );
    });

    test('Issue 1: clearEventMarketing throws StaleVersionException', () async {
      final h = harness(
        stale(
          updatedAt: writtenAt.millisecondsSinceEpoch,
          updatedBy: 'admin_2',
        ),
      );
      await expectLater(
        h.source.clearEventMarketing(42, version: 3),
        throwsA(
          isA<StaleVersionException>().having((e) => e.version, 'version', 5),
        ),
      );
    });

    test('Issue 1: a stale write to an event with no block has no time '
        'and no writer', () async {
      final h = harness(
        json(409, {
          'detail': {
            'code': 'STALE_VERSION',
            'message':
                'The event marketing was changed since you last loaded it',
            'version': 1,
            'updatedAt': null,
            'updatedBy': null,
          },
        }),
      );
      await expectLater(
        h.source.setEventMarketing(
          42,
          const EventMarketing(fee: 500),
          version: 4,
        ),
        throwsA(
          isA<StaleVersionException>()
              .having((e) => e.version, 'version', 1)
              .having((e) => e.updatedAtUtc, 'updatedAtUtc', isNull)
              .having((e) => e.updatedBy, 'updatedBy', isNull),
        ),
      );
    });
  });
}
