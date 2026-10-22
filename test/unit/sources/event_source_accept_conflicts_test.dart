import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 56: every event write that can clash takes `acceptConflicts`
/// (club_server#72). It is sent as `true` only when set; left out, the body
/// is what it was before, and the server's default (`false`) applies.
({RemoteEventSource source, List<http.Request> requests}) harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
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
        'version': 2,
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

/// One event write, called with or without `acceptConflicts`.
typedef Write =
    Future<Event> Function(RemoteEventSource source, {bool? accept});

final start = DateTime.utc(2027, 1, 1, 10);
final end = DateTime.utc(2027, 1, 1, 11);

final writes = <String, Write>{
  'createEvent': (source, {accept}) => accept == null
      ? source.createEvent(
          title: 'T',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: 1,
          startTimeUtc: start,
          endTimeUtc: end,
        )
      : source.createEvent(
          title: 'T',
          description: 'D',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: 1,
          startTimeUtc: start,
          endTimeUtc: end,
          acceptConflicts: accept,
        ),
  'updateEvent': (source, {accept}) => accept == null
      ? source.updateEvent(42, version: 1, organizerName: 'coach_a')
      : source.updateEvent(
          42,
          version: 1,
          organizerName: 'coach_a',
          acceptConflicts: accept,
        ),
  'updateEventForAllFuture': (source, {accept}) => accept == null
      ? source.updateEventForAllFuture(
          42,
          version: 1,
          effectiveDateTimeUtc: start,
          venueId: 3,
        )
      : source.updateEventForAllFuture(
          42,
          version: 1,
          effectiveDateTimeUtc: start,
          venueId: 3,
          acceptConflicts: accept,
        ),
  'rescheduleEvent': (source, {accept}) => accept == null
      ? source.rescheduleEvent(42, version: 1, venueId: 3)
      : source.rescheduleEvent(
          42,
          version: 1,
          venueId: 3,
          acceptConflicts: accept,
        ),
  'reinstate': (source, {accept}) => accept == null
      ? source.reinstate(42, version: 1)
      : source.reinstate(42, version: 1, acceptConflicts: accept),
};

void main() {
  group('Issue 56: event writes carry acceptConflicts', () {
    for (final MapEntry(key: name, value: write) in writes.entries) {
      test('Issue 56: $name sends acceptConflicts true when set', () async {
        final h = harness();
        await write(h.source, accept: true);
        expect(bodyOf(h.requests.single)['acceptConflicts'], isTrue);
      });

      test('Issue 56: $name leaves acceptConflicts out by default', () async {
        final h = harness();
        await write(h.source);
        expect(bodyOf(h.requests.single), isNot(contains('acceptConflicts')));
      });

      test('Issue 56: $name leaves acceptConflicts out when false', () async {
        final h = harness();
        await write(h.source, accept: false);
        expect(bodyOf(h.requests.single), isNot(contains('acceptConflicts')));
      });
    }
  });
}
