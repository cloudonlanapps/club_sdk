import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/event_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 7: event writes take the age band (club_server#16): `minAge`,
/// `maxAge` and `strictAge`. The two dates of birth are no longer sent; the
/// server answers 422 to either.
({RemoteEventSource source, List<http.Request> requests}) _harness() {
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
        'createdAtUtc': DateTime.utc(2026, 1, 1, 9).millisecondsSinceEpoch,
        'updatedAtUtc': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        'minAge': {'years': 8, 'months': 0, 'days': 0},
        'maxAge': {'years': 12, 'months': 6, 'days': 0},
        'strictAge': true,
        'eligibilityReferenceDayUtc': DateTime.utc(2027).millisecondsSinceEpoch,
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

Map<String, dynamic> _bodyOf(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

void _expectNoDateBounds(Map<String, dynamic> body) {
  expect(body.containsKey('dobOnOrAfterUtc'), isFalse);
  expect(body.containsKey('dobOnOrBeforeUtc'), isFalse);
}

void main() {
  final start = DateTime.utc(2027, 1, 1, 10);
  final end = DateTime.utc(2027, 1, 1, 11);

  group('Issue 7: RemoteEventSource.createEvent', () {
    test('sends minAge, maxAge and strictAge, and reads them back', () async {
      final h = _harness();

      final event = await h.source.createEvent(
        title: 'T',
        description: 'D',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: 1,
        startTimeUtc: start,
        endTimeUtc: end,
        minAge: const Age(years: 8),
        maxAge: const Age(years: 12, months: 6),
        strictAge: true,
      );

      final body = _bodyOf(h.requests.single);
      expect(h.requests.single.method, 'POST');
      expect(body['minAge'], {'years': 8, 'months': 0, 'days': 0});
      expect(body['maxAge'], {'years': 12, 'months': 6, 'days': 0});
      expect(body['strictAge'], isTrue);
      _expectNoDateBounds(body);
      expect(event.minAge, const Age(years: 8));
      expect(event.strictAge, isTrue);
    });

    test('leaves the band out when none is given', () async {
      final h = _harness();

      await h.source.createEvent(
        title: 'T',
        description: 'D',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: 1,
        startTimeUtc: start,
        endTimeUtc: end,
      );

      final body = _bodyOf(h.requests.single);
      expect(body.containsKey('minAge'), isFalse);
      expect(body.containsKey('maxAge'), isFalse);
      expect(body.containsKey('strictAge'), isFalse);
      _expectNoDateBounds(body);
    });
  });

  group('Issue 7: RemoteEventSource.updateEvent', () {
    test('sends the bounds its getters return and strictAge', () async {
      final h = _harness();

      await h.source.updateEvent(
        42,
        version: 1,
        minAge: () => const Age(years: 9, days: 1),
        maxAge: () => const Age(years: 13),
        strictAge: false,
      );

      final body = _bodyOf(h.requests.single);
      expect(h.requests.single.method, 'PATCH');
      expect(body['minAge'], {'years': 9, 'months': 0, 'days': 1});
      expect(body['maxAge'], {'years': 13, 'months': 0, 'days': 0});
      expect(body['strictAge'], isFalse);
      _expectNoDateBounds(body);
    });

    test('a getter returning null sends an explicit null, clearing the '
        'bound', () async {
      final h = _harness();

      await h.source.updateEvent(42, version: 1, maxAge: () => null);

      final body = _bodyOf(h.requests.single);
      expect(body.containsKey('maxAge'), isTrue);
      expect(body['maxAge'], isNull);
      expect(body.containsKey('minAge'), isFalse);
      expect(body.containsKey('strictAge'), isFalse);
    });

    test('leaves the band out when none is given', () async {
      final h = _harness();

      await h.source.updateEvent(42, version: 1, title: 'T2');

      final body = _bodyOf(h.requests.single);
      expect(body.containsKey('minAge'), isFalse);
      expect(body.containsKey('maxAge'), isFalse);
      expect(body.containsKey('strictAge'), isFalse);
    });
  });

  group('Issue 7: RemoteEventSource.correctionOnEvent', () {
    test('sends the bounds its getters return and strictAge', () async {
      final h = _harness();

      await h.source.correctionOnEvent(
        42,
        version: 2,
        minAge: () => const Age(years: 8),
        maxAge: () => null,
        strictAge: true,
      );

      final body = _bodyOf(h.requests.single);
      expect(body['minAge'], {'years': 8, 'months': 0, 'days': 0});
      expect(body.containsKey('maxAge'), isTrue);
      expect(body['maxAge'], isNull);
      expect(body['strictAge'], isTrue);
      _expectNoDateBounds(body);
    });

    test('leaves the band out when none is given', () async {
      final h = _harness();

      await h.source.correctionOnEvent(42, version: 2, title: 'T2');

      final body = _bodyOf(h.requests.single);
      expect(body.containsKey('minAge'), isFalse);
      expect(body.containsKey('maxAge'), isFalse);
      expect(body.containsKey('strictAge'), isFalse);
    });
  });
}
