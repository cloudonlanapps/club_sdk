import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:club_sdk_2/sdk/models/enums.dart';
import 'package:club_sdk_2/sdk/models/event_session.dart';
import 'package:club_sdk_2/sdk/models/gender.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Builds a [RemoteEventSource] backed by a mock client that captures the
/// request body and method/path, and returns a minimal valid Event JSON.
({RemoteEventSource source, List<http.Request> requests}) _harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({
        'id': 42,
        'title': 'Updated',
        'description': 'D',
        'type': 'oneOff',
        'visibility': 'public',
        'venueId': 1,
        'startTimeUtc': DateTime.utc(2027, 1, 1, 10).millisecondsSinceEpoch,
        'endTimeUtc': DateTime.utc(2027, 1, 1, 11).millisecondsSinceEpoch,
        'createdAtUtc': DateTime.utc(2026, 1, 1, 9).millisecondsSinceEpoch,
        'updatedAtUtc': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        'isFeatured': false,
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

void main() {
  group('RemoteEventSource.updateEvent', () {
    test(
      'Issue 292: PATCH body does not include untilTimeUtc',
      () async {
        final h = _harness();

        await h.source.updateEvent(
          42,
          version: 1,
          title: 'Updated',
          description: 'D',
          visibility: Visibility.public,
          organizerName: 'Org',
          coachNames: () => ['c1'],
          isFeatured: true,
        );

        final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
        expect(
          body.containsKey('untilTimeUtc'),
          isFalse,
          reason:
              'untilTimeUtc must never appear in updateEvent PATCH '
              'body — series termination must go through cancelSeries.',
        );
        expect(body['title'], 'Updated');
      },
    );

    test(
      'Issue 601: PATCH body carries only metadata — never schedule/identity '
      'fields (EventUpdate is extra="forbid", #232)',
      () async {
        final h = _harness();

        // Every metadata field the form can edit, set at once.
        await h.source.updateEvent(
          42,
          version: 1,
          title: 'Updated',
          description: 'D',
          visibility: Visibility.private,
          organizerName: 'Org',
          coachNames: () => ['c1'],
          gender: () => Gender.male,
          dobOnOrAfterUtc: () => DateTime.utc(2010),
          dobOnOrBeforeUtc: () => DateTime.utc(2015),
          isFeatured: true,
          galleryUris: () => ['uuid-2'],
        );

        final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
        for (final forbidden in const [
          'startTimeUtc',
          'endTimeUtc',
          'rrule',
          'venueId',
          'type',
        ]) {
          expect(
            body.containsKey(forbidden),
            isFalse,
            reason: '$forbidden moved to /reschedule and would 422 here.',
          );
        }
        expect(body['title'], 'Updated');
        expect(body['visibility'], 'private');
        expect(body['isFeatured'], true);
      },
    );
  });

  group('RemoteEventSource.rescheduleEvent', () {
    test(
      'Issue 601: POSTs schedule fields to /reschedule with resetOverrides',
      () async {
        final h = _harness();
        final start = DateTime.utc(2027, 6, 1, 9);
        final end = DateTime.utc(2027, 6, 1, 10);

        await h.source.rescheduleEvent(
          42,
          version: 1,
          startTimeUtc: start,
          endTimeUtc: end,
          rrule: 'FREQ=DAILY;COUNT=3',
          venueId: 7,
          resetOverrides: true,
        );

        final req = h.requests.single;
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/events/by_id/42/reschedule'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['startTimeUtc'], start.millisecondsSinceEpoch);
        expect(body['endTimeUtc'], end.millisecondsSinceEpoch);
        expect(body['rrule'], 'FREQ=DAILY;COUNT=3');
        expect(body['venueId'], 7);
        expect(body['resetOverrides'], true);
      },
    );

    test(
      'Issue 601: resetOverrides defaults to false and omits null fields',
      () async {
        final h = _harness();

        await h.source.rescheduleEvent(42, version: 1, venueId: 7);

        final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
        expect(body['venueId'], 7);
        expect(body['resetOverrides'], false);
        expect(body.containsKey('startTimeUtc'), isFalse);
        expect(body.containsKey('endTimeUtc'), isFalse);
        expect(body.containsKey('rrule'), isFalse);
        expect(
          body.containsKey('sessions'),
          isFalse,
          reason: 'an omitted sessions getter leaves the timetable untouched.',
        );
      },
    );

    test(
      'Issue 706: sessions getter sends the split to /reschedule',
      () async {
        final h = _harness();
        final start = DateTime.utc(2027, 6, 1, 9);
        final end = DateTime.utc(2027, 6, 1, 11);

        await h.source.rescheduleEvent(
          42,
          version: 1,
          startTimeUtc: start,
          endTimeUtc: end,
          rrule: 'FREQ=DAILY;COUNT=3',
          sessions: () => const [
            EventSession(name: 'On-Ice', periodMinutes: 60),
            EventSession(name: 'Off-Ice', periodMinutes: 60),
          ],
        );

        final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
        expect(body['sessions'], [
          {'name': 'On-Ice', 'periodMinutes': 60},
          {'name': 'Off-Ice', 'periodMinutes': 60},
        ]);
      },
    );

    test(
      'Issue 706: a sessions getter returning null sends an explicit null '
      '(clears the timetable)',
      () async {
        final h = _harness();
        final start = DateTime.utc(2027, 6, 1, 9);
        final end = DateTime.utc(2027, 6, 1, 10);

        await h.source.rescheduleEvent(
          42,
          version: 1,
          startTimeUtc: start,
          endTimeUtc: end,
          rrule: 'FREQ=DAILY;COUNT=3',
          sessions: () => null,
        );

        final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
        expect(
          body.containsKey('sessions'),
          isTrue,
          reason: 'the key must be present so the server clears the timetable.',
        );
        expect(body['sessions'], isNull);
      },
    );
  });

  group('RemoteEventSource.cancelSeries / undoCancelSeries', () {
    test(
      'Issue 601: cancelSeries always sends the required effectiveDateTimeUtc',
      () async {
        final h = _harness();
        final effective = DateTime.utc(2027, 7, 1, 9);

        await h.source.cancelSeries(
          42,
          reason: 'R',
          effectiveDateTimeUtc: effective,
        );

        final req = h.requests.single;
        expect(req.url.path, endsWith('/events/by_id/42/cancel'));
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['reason'], 'R');
        expect(body['effectiveDateTimeUtc'], effective.millisecondsSinceEpoch);
      },
    );

    test(
      'Issue 601: undoCancelSeries POSTs to /undo-cancel',
      () async {
        final h = _harness();

        await h.source.undoCancelSeries(42);

        final req = h.requests.single;
        expect(req.method, 'POST');
        expect(req.url.path, endsWith('/events/by_id/42/undo-cancel'));
      },
    );
  });
}
