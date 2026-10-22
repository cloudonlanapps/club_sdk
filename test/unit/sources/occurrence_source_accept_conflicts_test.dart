import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/occurrence_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 56: moving one occurrence takes `acceptConflicts`
/// (club_server#72), sent as `true` only when set.
({RemoteOccurrenceSource source, List<http.Request> requests}) harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response('', 204);
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteOccurrenceSource(store), requests: requests);
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  final occurrence = DateTime.utc(2027, 6, 1, 9);
  final newStart = DateTime.utc(2027, 6, 1, 11);

  group('Issue 56: rescheduleOccurrence carries acceptConflicts', () {
    test('Issue 56: sends acceptConflicts true when set', () async {
      final h = harness();
      await h.source.rescheduleOccurrence(
        1,
        occurrence,
        version: 1,
        newStartTimeUtc: newStart,
        acceptConflicts: true,
      );
      expect(bodyOf(h.requests.single)['acceptConflicts'], isTrue);
    });

    test('Issue 56: leaves acceptConflicts out by default', () async {
      final h = harness();
      await h.source.rescheduleOccurrence(
        1,
        occurrence,
        version: 1,
        newStartTimeUtc: newStart,
      );
      expect(bodyOf(h.requests.single), isNot(contains('acceptConflicts')));
    });
  });
}
