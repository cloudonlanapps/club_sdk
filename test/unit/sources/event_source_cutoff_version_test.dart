import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 1: the cutoff verbs (camp cancel and undo-cancel, programme
/// terminate, extend and extend-indefinitely) send the event version the
/// caller last loaded (club_server#13).
({RemoteEventSource source, List<http.Request> requests}) harness({
  http.Response? answer,
}) {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return answer ??
        http.Response(
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
  final cutoff = DateTime.utc(2027, 3, 1, 10);

  group('Issue 1: the cutoff verbs send the event version', () {
    test('Issue 1: cancelSeries posts the version with its reason and '
        'effective time', () async {
      final h = harness();
      await h.source.cancelSeries(
        42,
        version: 7,
        reason: 'r',
        effectiveDateTimeUtc: cutoff,
      );
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, endsWith('/events/by_id/42/cancel'));
      expect(bodyOf(r), {
        'version': 7,
        'reason': 'r',
        'effectiveDateTimeUtc': cutoff.millisecondsSinceEpoch,
      });
    });

    test('Issue 1: undoCancelSeries posts only the version', () async {
      final h = harness();
      await h.source.undoCancelSeries(42, version: 7);
      final r = h.requests.single;
      expect(r.method, 'POST');
      expect(r.url.path, endsWith('/events/by_id/42/undo-cancel'));
      expect(bodyOf(r), {'version': 7});
    });

    test(
      'Issue 1: terminate posts the version with its reason and cutoff',
      () async {
        final h = harness();
        await h.source.terminate(
          42,
          version: 7,
          reason: 'r',
          cutoffTimeUtc: cutoff,
        );
        final r = h.requests.single;
        expect(r.url.path, endsWith('/events/by_id/42/terminate'));
        expect(bodyOf(r), {
          'version': 7,
          'reason': 'r',
          'cutoffTimeUtc': cutoff.millisecondsSinceEpoch,
        });
      },
    );

    test('Issue 1: extend posts the version with its cutoff', () async {
      final h = harness();
      await h.source.extend(42, version: 7, cutoffTimeUtc: cutoff);
      final r = h.requests.single;
      expect(r.url.path, endsWith('/events/by_id/42/extend'));
      expect(bodyOf(r), {
        'version': 7,
        'cutoffTimeUtc': cutoff.millisecondsSinceEpoch,
      });
    });

    test('Issue 1: extend posts a reason when it is given one', () async {
      final h = harness();
      await h.source.extend(
        42,
        version: 7,
        cutoffTimeUtc: cutoff,
        reason: 'more weeks',
      );
      expect(bodyOf(h.requests.single), {
        'version': 7,
        'cutoffTimeUtc': cutoff.millisecondsSinceEpoch,
        'reason': 'more weeks',
      });
    });

    test('Issue 1: extendIndefinitely posts only the version', () async {
      final h = harness();
      await h.source.extendIndefinitely(42, version: 7);
      final r = h.requests.single;
      expect(r.url.path, endsWith('/events/by_id/42/extend-indefinitely'));
      expect(bodyOf(r), {'version': 7});
    });

    test('Issue 1: extendIndefinitely posts a reason when it is given '
        'one', () async {
      final h = harness();
      await h.source.extendIndefinitely(42, version: 7, reason: 'back on');
      expect(bodyOf(h.requests.single), {'version': 7, 'reason': 'back on'});
    });

    test(
      'Issue 1: a cutoff verb returns the event at its new version',
      () async {
        final h = harness();
        final event = await h.source.terminate(
          42,
          version: 7,
          reason: 'r',
          cutoffTimeUtc: cutoff,
        );
        expect(event.version, 8);
      },
    );
  });

  group('Issue 1: a cutoff verb at a stale version', () {
    final changedAt = DateTime.utc(2027, 2, 1, 9);
    http.Response stale() => http.Response(
      jsonEncode({
        'detail': {
          'code': 'STALE_VERSION',
          'message': 'The event was changed since you last loaded it',
          'version': 9,
          'updatedAt': changedAt.millisecondsSinceEpoch,
          'updatedBy': 'admin_2',
        },
      }),
      409,
      headers: {'content-type': 'application/json'},
    );

    Matcher throwsStale() => throwsA(
      isA<StaleVersionException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.code, 'code', SdkErrorCode.staleVersion)
          .having((e) => e.version, 'version', 9)
          .having((e) => e.updatedAtUtc, 'updatedAtUtc', changedAt)
          .having((e) => e.updatedBy, 'updatedBy', 'admin_2'),
    );

    test('Issue 1: cancelSeries throws StaleVersionException', () async {
      final h = harness(answer: stale());
      await expectLater(
        h.source.cancelSeries(
          42,
          version: 7,
          reason: 'r',
          effectiveDateTimeUtc: cutoff,
        ),
        throwsStale(),
      );
    });

    test('Issue 1: undoCancelSeries throws StaleVersionException', () async {
      final h = harness(answer: stale());
      await expectLater(
        h.source.undoCancelSeries(42, version: 7),
        throwsStale(),
      );
    });

    test('Issue 1: terminate throws StaleVersionException', () async {
      final h = harness(answer: stale());
      await expectLater(
        h.source.terminate(42, version: 7, reason: 'r', cutoffTimeUtc: cutoff),
        throwsStale(),
      );
    });

    test('Issue 1: extend throws StaleVersionException', () async {
      final h = harness(answer: stale());
      await expectLater(
        h.source.extend(42, version: 7, cutoffTimeUtc: cutoff),
        throwsStale(),
      );
    });

    test('Issue 1: extendIndefinitely throws StaleVersionException', () async {
      final h = harness(answer: stale());
      await expectLater(
        h.source.extendIndefinitely(42, version: 7),
        throwsStale(),
      );
    });
  });
}
