import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/occurrence_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Builds a [RemoteOccurrenceSource] backed by a mock client that captures
/// each request and returns 204 No Content (the reschedule endpoint is void).
({RemoteOccurrenceSource source, List<http.Request> requests}) _harness() {
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

void main() {
  group('RemoteOccurrenceSource.rescheduleOccurrence', () {
    final occTime = DateTime.utc(2027, 6, 1, 9);

    test(
      'Issue 601: body uses newDurationMinutes and never newEndTimeUtc / '
      'newOrganizerName (#113)',
      () async {
        final h = _harness();
        final newStart = DateTime.utc(2027, 6, 1, 11);

        await h.source.rescheduleOccurrence(
          1,
          occTime,
          newStartTimeUtc: newStart,
          newDurationMinutes: 90,
          newVenueId: 5,
        );

        final req = h.requests.single;
        expect(req.method, 'POST');
        expect(
          req.url.path,
          endsWith(
            '/events/by_id/1/occurrences/'
            '${occTime.millisecondsSinceEpoch}/reschedule',
          ),
        );
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['newStartTimeUtc'], newStart.millisecondsSinceEpoch);
        expect(body['newDurationMinutes'], 90);
        expect(body['newVenueId'], 5);
        expect(body.containsKey('newEndTimeUtc'), isFalse);
        expect(body.containsKey('newOrganizerName'), isFalse);
      },
    );

    test(
      'Issue 601: omits null fields (duration-only reschedule)',
      () async {
        final h = _harness();

        await h.source.rescheduleOccurrence(
          1,
          occTime,
          newDurationMinutes: 45,
        );

        final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
        expect(body['newDurationMinutes'], 45);
        expect(body.containsKey('newStartTimeUtc'), isFalse);
        expect(body.containsKey('newVenueId'), isFalse);
      },
    );
  });
}
