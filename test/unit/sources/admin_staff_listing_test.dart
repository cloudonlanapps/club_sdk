import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/admin_source.dart';
import 'package:club_sdk_2/remote_store/sources/public_source.dart';
import 'package:club_sdk_2/remote_store/sources/user_source.dart';
import 'package:club_sdk_2/sdk/models/gender.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 24: the staff-listing calls, `include_guests` on the public staff
/// list, and `isGuest` on admin create send what the server declares.
({RemoteStore store, List<http.Request> requests}) harness() {
  final requests = <http.Request>[];
  final client = MockClient((request) async {
    requests.add(request);
    final row = {
      'username': 'c1',
      'displayName': 'C',
      'isPublicProfile': true,
      'position': 1,
      'isGuest': true,
      'isHidden': false,
    };
    final user = {
      'username': 'c1',
      'publicId': 'p',
      'status': 'active',
      'isSuperAdmin': false,
      'roles': <String>[],
      'isGuest': true,
      'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
    };
    final profile = {'publicId': 'p', 'displayName': 'C', 'isGuest': true};
    final path = request.url.path;
    final body = path.endsWith('/staff')
        ? [profile]
        : path.endsWith('/staff-listing')
        ? [row]
        : path.contains('/staff-listing/')
        ? row
        : user;
    return http.Response(
      request.method == 'DELETE' ? '' : jsonEncode(body),
      request.method == 'DELETE' ? 204 : 200,
      headers: {'content-type': 'application/json'},
    );
  });
  return (
    store: RemoteStore(baseUrl: 'https://example.test/v1', client: client),
    requests: requests,
  );
}

void main() {
  group('Issue 24: staff listing', () {
    test('Issue 24: listStaffListing reads rows', () async {
      final h = harness();
      final rows = await RemoteAdminSource(h.store).listStaffListing();
      expect(h.requests.single.url.path, endsWith('/admin/staff-listing'));
      expect(rows.single.isGuest, isTrue);
    });

    test('Issue 24: setStaffListing PUTs only the given fields', () async {
      final h = harness();
      await RemoteAdminSource(
        h.store,
      ).setStaffListing('c1', position: () => null, isHidden: true);
      final r = h.requests.single;
      expect(r.method, 'PUT');
      expect(r.url.path, endsWith('/admin/staff-listing/c1'));
      expect(jsonDecode(r.body), {'position': null, 'isHidden': true});
    });

    test('Issue 24: clearStaffListing DELETEs the row', () async {
      final h = harness();
      await RemoteAdminSource(h.store).clearStaffListing('c1');
      expect(h.requests.single.method, 'DELETE');
      expect(h.requests.single.url.path, endsWith('/admin/staff-listing/c1'));
    });

    test('Issue 24: listPublicStaff asks for guests only when told', () async {
      final h = harness();
      final public = RemotePublicSource(h.store);
      await public.listPublicStaff();
      await public.listPublicStaff(includeGuests: true);
      expect(h.requests[0].url.queryParameters, isEmpty);
      expect(h.requests[1].url.queryParameters, {'include_guests': 'true'});
    });

    test('Issue 24: createUser sends isGuest', () async {
      final h = harness();
      final created = await RemoteUserSource(h.store).createUser(
        username: 'c1',
        email: 'c1@example.com',
        passwordHash: 'x',
        phone: '0',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
        isGuest: true,
      );
      final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
      expect(body['isGuest'], true);
      expect(created.isGuest, isTrue);
    });
  });
}
