import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 25: update, correction and split send the version the caller
/// last loaded (club_server#292). A body without it is a 422.
({RemoteEventSource source, List<http.Request> requests}) harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({
        'id': 42,
        'title': 'T',
        'description': 'D',
        'type': 'programme',
        'visibility': 'public',
        'venueId': 1,
        'startTimeUtc': DateTime.utc(2027, 1, 1, 10).millisecondsSinceEpoch,
        'endTimeUtc': DateTime.utc(2027, 1, 1, 11).millisecondsSinceEpoch,
        'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
        'updatedAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
        'version': 8,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteEventSource(store), requests: requests);
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  group('Issue 25: event edits carry version', () {
    test('Issue 25: updateEvent sends version', () async {
      final h = harness();
      final e = await h.source.updateEvent(42, version: 7, title: 'T');
      expect(bodyOf(h.requests.single)['version'], 7);
      expect(e.version, 8);
    });

    test('Issue 25: correctionOnEvent sends version', () async {
      final h = harness();
      await h.source.correctionOnEvent(42, version: 7, title: 'T');
      expect(bodyOf(h.requests.single)['version'], 7);
    });

    test('Issue 5: rescheduleEvent sends version', () async {
      final h = harness();
      final e = await h.source.rescheduleEvent(
        42,
        version: 7,
        venueId: 3,
      );
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, endsWith('/events/by_id/42/reschedule'));
      expect(bodyOf(r)['version'], 7);
      expect(bodyOf(r)['venueId'], 3);
      expect(e.version, 8);
    });

    test('Issue 25: updateEventForAllFuture sends version', () async {
      final h = harness();
      await h.source.updateEventForAllFuture(
        42,
        version: 7,
        effectiveDateTimeUtc: DateTime.utc(2027, 2),
      );
      expect(bodyOf(h.requests.single)['version'], 7);
    });
  });
}
