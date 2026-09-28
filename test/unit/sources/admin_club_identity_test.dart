import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/admin_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 90: getClubIdentity and setClubIdentity go through the `club_info`
/// preference endpoint.
({RemoteStore store, List<http.Request> requests}) harness(Object? stored) {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    final value = request.method == 'PATCH'
        ? (jsonDecode(request.body) as Map<String, dynamic>)['value']
        : stored;
    return http.Response(
      jsonEncode({
        'key': 'club_info',
        'value': value,
        'updatedAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
        'updatedBy': 'admin',
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return (
    store: RemoteStore(baseUrl: 'https://example.test/v1', client: client),
    requests: requests,
  );
}

void main() {
  group('Issue 90: AdminSource club identity', () {
    test('Issue 90: getClubIdentity reads the club_info preference', () async {
      final h = harness({
        'name': 'My Example Club',
        'contact': {'email': 'hello@myexampleclub.com'},
      });
      final identity = await RemoteAdminSource(h.store).getClubIdentity();

      expect(h.requests.single.method, 'GET');
      expect(
        h.requests.single.url.path,
        '/v1/admin/preferences/club_info',
      );
      expect(identity.name, 'My Example Club');
      expect(identity.contact!.email, 'hello@myexampleclub.com');
    });

    test('Issue 90: getClubIdentity reads an unset preference as an empty '
        'identity', () async {
      final h = harness(null);
      final identity = await RemoteAdminSource(h.store).getClubIdentity();
      expect(identity, const ClubIdentity());
    });

    test('Issue 90: setClubIdentity patches the whole document, unknown keys '
        'included', () async {
      final h = harness(null);
      const identity = ClubIdentity(
        name: 'My Example Club',
        shortName: 'MEC',
        contact: ClubContactDetails(
          tagline: LocalizedText('Skate with us', {'mr': 'स्केट'}),
        ),
        extra: {'story': 'Founded on a pond.'},
      );

      final written = await RemoteAdminSource(h.store).setClubIdentity(
        identity,
      );

      final request = h.requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.path, '/v1/admin/preferences/club_info');
      expect(jsonDecode(request.body), {
        'value': {
          'story': 'Founded on a pond.',
          'name': 'My Example Club',
          'shortName': 'MEC',
          'contact': {
            'tagline': {'default': 'Skate with us', 'mr': 'स्केट'},
          },
        },
      });
      expect(written, identity);
    });
  });
}
