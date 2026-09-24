import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/user_source.dart';
import 'package:club_sdk_2/sdk/models/gender.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 26: every request body the server declares is `extra="forbid"`
/// (club_server#325), so a key the server does not know is a 422, not a
/// silently dropped field. These tests pin the exact keys sent.
({RemoteUserSource source, List<http.Request> requests}) harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({
        'username': 'u1',
        'publicId': 'p1',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': <String>[],
        'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteUserSource(store), requests: requests);
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  group('Issue 26: RemoteUserSource request bodies', () {
    test('Issue 26: createUser sends camelCase name keys', () async {
      final h = harness();
      await h.source.createUser(
        username: 'u1',
        email: 'u1@example.test',
        passwordHash: 'hash',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
        firstName: 'First',
        middleName: 'Mid',
        lastName: 'Last',
      );
      final body = bodyOf(h.requests.single);
      expect(body['firstName'], 'First');
      expect(body['middleName'], 'Mid');
      expect(body['lastName'], 'Last');
      expect(body.keys, isNot(contains('first_name')));
      expect(body.keys, isNot(contains('middle_name')));
      expect(body.keys, isNot(contains('last_name')));
    });

    test('Issue 26: reapply sends camelCase name keys', () async {
      final h = harness();
      await h.source.reapply(
        'u1',
        firstName: 'First',
        middleName: 'Mid',
        lastName: 'Last',
      );
      final body = bodyOf(h.requests.single);
      expect(body, {
        'firstName': 'First',
        'middleName': 'Mid',
        'lastName': 'Last',
      });
    });

    test('Issue 26: updateUser sends camelCase name keys', () async {
      final h = harness();
      await h.source.updateUser(
        'u1',
        firstName: () => 'First',
        middleName: () => null,
        lastName: () => 'Last',
      );
      final body = bodyOf(h.requests.single);
      expect(body, {
        'firstName': 'First',
        'middleName': null,
        'lastName': 'Last',
      });
    });

    test('Issue 26: updateUser never sends displayOrder', () async {
      final h = harness();
      await h.source.updateUser('u1', email: 'x@example.test');
      final body = bodyOf(h.requests.single);
      expect(body.keys, isNot(contains('displayOrder')));
    });
  });
}
