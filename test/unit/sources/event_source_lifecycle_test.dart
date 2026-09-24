import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:club_sdk_2/sdk/models/enums.dart';
import 'package:club_sdk_2/sdk/models/event_session.dart';
import 'package:club_sdk_2/sdk/models/gender.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 16: the lifecycle verbs, split and correction send the bodies the
/// server declares, to the routes it serves.
({RemoteEventSource source, List<http.Request> requests}) harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    final isList = request.url.path.endsWith('/schedules');
    final event = {
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
    };
    final schedule = {
      'id': 1,
      'eventId': 42,
      'effectiveFromUtc': DateTime.utc(2027).millisecondsSinceEpoch,
      'effectiveUntilUtc': null,
      'startTimeUtc': DateTime.utc(2027, 1, 4, 10).millisecondsSinceEpoch,
      'endTimeUtc': DateTime.utc(2027, 1, 4, 11).millisecondsSinceEpoch,
      'rrule': 'FREQ=WEEKLY;BYDAY=MO',
      'venueId': 1,
    };
    return http.Response(
      jsonEncode(isList ? [schedule] : event),
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
  final cutoff = DateTime.utc(2027, 3, 1, 10);

  group('Issue 16: lifecycle verbs', () {
    test('Issue 16: terminate posts reason and cutoff', () async {
      final h = harness();
      await h.source.terminate(42, reason: 'r', cutoffTimeUtc: cutoff);
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, endsWith('/events/by_id/42/terminate'));
      expect(bodyOf(r), {
        'reason': 'r',
        'cutoffTimeUtc': cutoff.millisecondsSinceEpoch,
      });
    });

    test('Issue 16: extend posts the cutoff and an optional reason', () async {
      final h = harness();
      await h.source.extend(42, cutoffTimeUtc: cutoff);
      expect(h.requests.single.url.path, endsWith('/events/by_id/42/extend'));
      expect(bodyOf(h.requests.single), {
        'cutoffTimeUtc': cutoff.millisecondsSinceEpoch,
      });
    });

    test('Issue 16: extendIndefinitely posts to its route', () async {
      final h = harness();
      await h.source.extendIndefinitely(42, reason: 'back on');
      expect(
        h.requests.single.url.path,
        endsWith('/events/by_id/42/extend-indefinitely'),
      );
      expect(bodyOf(h.requests.single), {'reason': 'back on'});
    });

    test('Issue 16: drop posts a reason, reinstate posts nothing', () async {
      final h = harness();
      await h.source.drop(42, reason: 'rain');
      await h.source.reinstate(42);
      expect(h.requests[0].url.path, endsWith('/events/by_id/42/drop'));
      expect(bodyOf(h.requests[0]), {'reason': 'rain'});
      expect(h.requests[1].url.path, endsWith('/events/by_id/42/reinstate'));
      expect(h.requests[1].method, 'POST');
    });

    test('Issue 16: listSchedules reads the timetable', () async {
      final h = harness();
      final schedules = await h.source.listSchedules(42);
      expect(
        h.requests.single.url.path,
        endsWith('/events/by_id/42/schedules'),
      );
      expect(schedules.single.rrule, 'FREQ=WEEKLY;BYDAY=MO');
      expect(schedules.single.isCurrent, isTrue);
    });
  });

  group('Issue 16: split and correction bodies', () {
    test(
      'Issue 16: split sends effectiveDateTimeUtc, staffing and sessions',
      () async {
        final h = harness();
        await h.source.updateEventForAllFuture(
          42,
          version: 3,
          effectiveDateTimeUtc: cutoff,
          venueId: 9,
          coachNames: () => ['c1'],
          sessions: () => const [EventSession(name: 'All', periodMinutes: 60)],
        );
        final body = bodyOf(h.requests.single);
        expect(body['version'], 3);
        expect(body['effectiveDateTimeUtc'], cutoff.millisecondsSinceEpoch);
        expect(body['venueId'], 9);
        expect(body['coachNames'], ['c1']);
        expect(body['sessions'], [
          {'name': 'All', 'periodMinutes': 60},
        ]);
        for (final forbidden in const ['title', 'description', 'visibility']) {
          expect(body.containsKey(forbidden), isFalse, reason: forbidden);
        }
      },
    );

    test('Issue 16: correction sends eligibility and presentation, never '
        'coachNames', () async {
      final h = harness();
      await h.source.correctionOnEvent(
        42,
        version: 3,
        title: 'T2',
        visibility: Visibility.private,
        gender: () => Gender.female,
        dobOnOrAfterUtc: () => DateTime.utc(2010),
        dobOnOrBeforeUtc: () => null,
        isFeatured: true,
        galleryUris: () => ['u1'],
      );
      final body = bodyOf(h.requests.single);
      expect(body['version'], 3);
      expect(body['title'], 'T2');
      expect(body['visibility'], 'private');
      expect(body['gender'], 'female');
      expect(
        body['dobOnOrAfterUtc'],
        DateTime.utc(2010).millisecondsSinceEpoch,
      );
      expect(body.containsKey('dobOnOrBeforeUtc'), isTrue);
      expect(body['dobOnOrBeforeUtc'], isNull);
      expect(body['isFeatured'], true);
      expect(body['galleryUris'], ['u1']);
      expect(body.containsKey('coachNames'), isFalse);
    });
  });
}
