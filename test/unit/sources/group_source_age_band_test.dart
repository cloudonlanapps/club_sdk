import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/group_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 7: group writes take the age band (club_server#16): `minAge`,
/// `maxAge` and `strictAge`. The two dates of birth are no longer sent; the
/// server answers 422 to either.
({RemoteGroupSource source, List<http.Request> requests}) _harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({
        'id': 5,
        'name': 'test_U12',
        'description': null,
        'kind': 'semi_auto',
        'minAge': {'years': 8, 'months': 0, 'days': 0},
        'maxAge': {'years': 12, 'months': 6, 'days': 0},
        'strictAge': true,
        'dobOnOrAfterUtc': DateTime.utc(2014, 4, 6).millisecondsSinceEpoch,
        'dobOnOrBeforeUtc': DateTime.utc(2018, 10, 6).millisecondsSinceEpoch,
        'eligibilityReferenceDayUtc': DateTime.utc(
          2026,
          10,
          6,
        ).millisecondsSinceEpoch,
        'memberCount': 0,
        'ineligibleMemberCount': 0,
        'createdAtUtc': DateTime.utc(2026, 10, 6, 9).millisecondsSinceEpoch,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteGroupSource(store), requests: requests);
}

Map<String, dynamic> _bodyOf(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

void main() {
  group('Issue 7: RemoteGroupSource.createGroup', () {
    test('sends minAge, maxAge and strictAge, and reads them back', () async {
      final h = _harness();

      final created = await h.source.createGroup(
        name: 'test_U12',
        minAge: const Age(years: 8),
        maxAge: const Age(years: 12, months: 6),
        strictAge: true,
        semiAuto: true,
      );

      final body = _bodyOf(h.requests.single);
      expect(h.requests.single.method, 'POST');
      expect(body['minAge'], {'years': 8, 'months': 0, 'days': 0});
      expect(body['maxAge'], {'years': 12, 'months': 6, 'days': 0});
      expect(body['strictAge'], isTrue);
      expect(body['semiAuto'], isTrue);
      expect(body.containsKey('dobOnOrAfterUtc'), isFalse);
      expect(body.containsKey('dobOnOrBeforeUtc'), isFalse);
      expect(created.maxAge, const Age(years: 12, months: 6));
      expect(created.dobOnOrAfterUtc, DateTime.utc(2014, 4, 6));
    });

    test('leaves the band out when none is given', () async {
      final h = _harness();

      await h.source.createGroup(name: 'test_manual');

      final body = _bodyOf(h.requests.single);
      expect(body, {'name': 'test_manual'});
    });
  });

  group('Issue 7: RemoteGroupSource.updateGroup', () {
    test('sends the bounds its getters return and strictAge', () async {
      final h = _harness();

      await h.source.updateGroup(
        5,
        minAge: () => const Age(years: 9, months: 3),
        maxAge: () => const Age(years: 13),
        strictAge: false,
      );

      final body = _bodyOf(h.requests.single);
      expect(h.requests.single.method, 'PATCH');
      expect(body, {
        'minAge': {'years': 9, 'months': 3, 'days': 0},
        'maxAge': {'years': 13, 'months': 0, 'days': 0},
        'strictAge': false,
      });
    });

    test('a getter returning null sends an explicit null, clearing the '
        'bound', () async {
      final h = _harness();

      await h.source.updateGroup(5, minAge: () => null);

      final body = _bodyOf(h.requests.single);
      expect(body, {'minAge': null});
    });

    test('leaves the band out when none is given', () async {
      final h = _harness();

      await h.source.updateGroup(5, name: 'test_renamed');

      expect(_bodyOf(h.requests.single), {'name': 'test_renamed'});
    });
  });
}
