import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 3: a timetable is corrected in place (club_server#423) — through
/// `correctionOnEvent` for a programme, optionally naming the schedule, and
/// through `updateEvent` for a camp or one-off.
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
        'startTimeUtc': DateTime.utc(2027, 1, 4, 10).millisecondsSinceEpoch,
        'endTimeUtc': DateTime.utc(2027, 1, 4, 11).millisecondsSinceEpoch,
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

const List<EventSession> split = [
  EventSession(name: 'Warm-up', periodMinutes: 15),
  EventSession(name: 'Drills', periodMinutes: 45),
];
const List<Map<String, Object>> splitJson = [
  {'name': 'Warm-up', 'periodMinutes': 15},
  {'name': 'Drills', 'periodMinutes': 45},
];

void main() {
  group('Issue 3: correctionOnEvent sessions', () {
    test('sends sessions without scheduleId to correct the latest '
        'schedule', () async {
      final h = harness();
      await h.source.correctionOnEvent(42, version: 2, sessions: () => split);
      final r = h.requests.single;
      expect(r.method, 'PATCH');
      expect(r.url.path, endsWith('/events/by_id/42/correction'));
      final body = bodyOf(r);
      expect(body['sessions'], splitJson);
      expect(body.containsKey('scheduleId'), isFalse);
    });

    test(
      'sends scheduleId with sessions to correct a named schedule',
      () async {
        final h = harness();
        await h.source.correctionOnEvent(
          42,
          version: 2,
          sessions: () => split,
          scheduleId: 7,
        );
        final body = bodyOf(h.requests.single);
        expect(body['sessions'], splitJson);
        expect(body['scheduleId'], 7);
      },
    );

    test('a sessions getter returning null sends an explicit null', () async {
      final h = harness();
      await h.source.correctionOnEvent(42, version: 2, sessions: () => null);
      final body = bodyOf(h.requests.single);
      expect(body.containsKey('sessions'), isTrue);
      expect(body['sessions'], isNull);
    });

    test('an omitted sessions getter sends neither sessions nor '
        'scheduleId', () async {
      final h = harness();
      await h.source.correctionOnEvent(42, version: 2, title: 'T2');
      final body = bodyOf(h.requests.single);
      expect(body.containsKey('sessions'), isFalse);
      expect(body.containsKey('scheduleId'), isFalse);
    });
  });

  group('Issue 3: updateEvent sessions (camp / one-off)', () {
    test('sends the sessions getter value', () async {
      final h = harness();
      await h.source.updateEvent(42, version: 1, sessions: () => split);
      final r = h.requests.single;
      expect(r.method, 'PATCH');
      expect(r.url.path, endsWith('/events/by_id/42'));
      expect(bodyOf(r)['sessions'], splitJson);
    });

    test('a sessions getter returning null sends an explicit null', () async {
      final h = harness();
      await h.source.updateEvent(42, version: 1, sessions: () => null);
      final body = bodyOf(h.requests.single);
      expect(body.containsKey('sessions'), isTrue);
      expect(body['sessions'], isNull);
    });
  });

  group('Issue 3: SCHEDULE_NOT_FOUND', () {
    test('is a known error code', () {
      expect(SdkErrorCode.scheduleNotFound, 'SCHEDULE_NOT_FOUND');
    });

    test('a 404 SCHEDULE_NOT_FOUND maps to a ServerException carrying '
        'the code', () {
      final exc = mapHttpError(404, const {
        'detail': {'code': 'SCHEDULE_NOT_FOUND', 'message': 'm'},
      });
      expect(exc, isA<ServerException>());
      expect(exc.statusCode, 404);
      expect(exc.code, SdkErrorCode.scheduleNotFound);
    });
  });
}
