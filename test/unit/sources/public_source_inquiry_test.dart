import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/public_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 22: an inquiry may be submitted without a message
/// (club_server#41).
({RemotePublicSource source, List<http.Request> requests}) harness() {
  final requests = <http.Request>[];
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: MockClient((request) async {
      requests.add(request);
      return http.Response('', 202);
    }),
    maxRetries: 0,
  );
  return (source: RemotePublicSource(store), requests: requests);
}

void main() {
  group('submitInquiry', () {
    test('Issue 22: without a message sends no message key', () async {
      final h = harness();

      await h.source.submitInquiry(
        kind: InquiryKind.interest,
        name: 'test_person',
        email: 'test_person@test.com',
        token: 't',
      );

      final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
      expect(body.containsKey('message'), isFalse);
      expect(body['kind'], 'interest');
    });

    test('Issue 22: with a message sends it', () async {
      final h = harness();

      await h.source.submitInquiry(
        kind: InquiryKind.contact,
        name: 'test_person',
        email: 'test_person@test.com',
        message: 'Hello',
        token: 't',
      );

      final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
      expect(body['message'], 'Hello');
    });
  });
}
