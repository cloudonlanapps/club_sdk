import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:club_sdk_2/remote_store/sources/occurrence_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 1: every change to an occurrence carries the occurrence's own
/// version (club_server#430). A body without it is a 422; a stale one is a
/// 409 `STALE_VERSION`.
({RemoteStore store, List<http.Request> requests}) harness({
  http.Response Function(http.Request)? respond,
}) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    if (respond != null) return respond(request);
    if (request.url.path.contains('/occurrences/')) {
      return http.Response('', 204);
    }
    // drop / reinstate answer the event.
    return http.Response(
      jsonEncode({
        'id': 42,
        'title': 'T',
        'description': 'D',
        'type': 'oneOff',
        'visibility': 'public',
        'venueId': 1,
        'startTimeUtc': DateTime.utc(2027, 1, 1, 10).millisecondsSinceEpoch,
        'endTimeUtc': DateTime.utc(2027, 1, 1, 11).millisecondsSinceEpoch,
        'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
        'updatedAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
        'version': 1,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return (
    store: RemoteStore(baseUrl: 'https://example.test/v1', client: mockClient),
    requests: requests,
  );
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  final occTime = DateTime.utc(2027, 6, 1, 9);
  final occPath =
      '/events/by_id/42/occurrences/${occTime.millisecondsSinceEpoch}';

  group('Issue 1: occurrence changes send the occurrence version', () {
    test('rescheduleOccurrence sends version with the change', () async {
      final h = harness();
      await RemoteOccurrenceSource(h.store).rescheduleOccurrence(
        42,
        occTime,
        version: 3,
        newDurationMinutes: 45,
      );
      final r = h.requests.single;
      expect(r.url.path, endsWith('$occPath/reschedule'));
      expect(bodyOf(r), {'version': 3, 'newDurationMinutes': 45});
    });

    test('cancelOccurrence sends version and reason', () async {
      final h = harness();
      await RemoteOccurrenceSource(
        h.store,
      ).cancelOccurrence(42, occTime, version: 1, reason: 'ice');
      final r = h.requests.single;
      expect(r.url.path, endsWith('$occPath/cancel'));
      expect(bodyOf(r), {'version': 1, 'reason': 'ice'});
    });

    test('undoCancelOccurrence sends a body carrying only version', () async {
      final h = harness();
      await RemoteOccurrenceSource(
        h.store,
      ).undoCancelOccurrence(42, occTime, version: 2);
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, endsWith('$occPath/undo-cancel'));
      expect(bodyOf(r), {'version': 2});
    });

    test('drop sends the occurrence version and the reason', () async {
      final h = harness();
      await RemoteEventSource(h.store).drop(42, version: 1, reason: 'rain');
      final r = h.requests.single;
      expect(r.url.path, endsWith('/events/by_id/42/drop'));
      expect(bodyOf(r), {'version': 1, 'reason': 'rain'});
    });

    test('reinstate sends a body carrying only version', () async {
      final h = harness();
      await RemoteEventSource(h.store).reinstate(42, version: 2);
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, endsWith('/events/by_id/42/reinstate'));
      expect(bodyOf(r), {'version': 2});
    });
  });

  group('Issue 1: a stale occurrence version', () {
    test('surfaces as StaleVersionException with who changed it', () async {
      final at = DateTime.utc(2027, 5, 30, 18);
      final h = harness(
        respond: (_) => http.Response(
          jsonEncode({
            'detail': {
              'code': 'STALE_VERSION',
              'message': 'Occurrence is at version 3',
              'version': 3,
              'updatedAt': at.millisecondsSinceEpoch,
              'updatedBy': 'coach_2',
            },
          }),
          409,
          headers: {'content-type': 'application/json'},
        ),
      );
      await expectLater(
        RemoteOccurrenceSource(
          h.store,
        ).cancelOccurrence(42, occTime, version: 2, reason: 'ice'),
        throwsA(
          isA<StaleVersionException>()
              .having((e) => e.version, 'version', 3)
              .having((e) => e.updatedBy, 'updatedBy', 'coach_2')
              .having((e) => e.updatedAtUtc, 'updatedAtUtc', at),
        ),
      );
    });
  });
}
