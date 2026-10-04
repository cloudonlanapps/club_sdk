import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:club_sdk_2/remote_store/sources/broadcast_source.dart';
import 'package:club_sdk_2/sdk/models/broadcast.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Builds a [RemoteBroadcastSource] backed by a mock client that captures the
/// request and returns a minimal valid Broadcast JSON.
({RemoteBroadcastSource source, List<http.Request> requests}) _harness() {
  final requests = <http.Request>[];
  final mockClient = MockClient((request) async {
    requests.add(request);
    return http.Response(
      jsonEncode({
        'id': 7,
        'senderUsername': 'admin',
        'audienceSelector': {'kind': 'all_users'},
        'payload': {
          'v': 1,
          'type': 'broadcast.text',
          'data': {'text': 'hi'},
        },
        'sentAtUtc': DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        'status': 'sent',
        'recipientCount': 3,
      }),
      201,
      headers: {'content-type': 'application/json'},
    );
  });
  final store = RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: mockClient,
  );
  return (source: RemoteBroadcastSource(store), requests: requests);
}

const _payload = <String, dynamic>{
  'v': 1,
  'type': 'broadcast.text',
  'data': <String, dynamic>{'text': 'hi'},
};

void main() {
  group('RemoteBroadcastSource.createBroadcast', () {
    test('Issue 737: omits email keys when email is false (default)', () async {
      final h = _harness();

      await h.source.createBroadcast(
        audienceSelector: const AudienceSelector.allUsers(),
        payload: _payload,
      );

      final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
      expect(body.containsKey('email'), isFalse);
      expect(body.containsKey('emailSubject'), isFalse);
      expect(body.containsKey('emailBody'), isFalse);
    });

    test(
      'Issue 737: carries email/emailSubject/emailBody when email is true',
      () async {
        final h = _harness();

        await h.source.createBroadcast(
          audienceSelector: const AudienceSelector.group(5),
          payload: _payload,
          email: true,
          emailSubject: 'Message for U12',
          emailBody: 'See you on the ice.',
        );

        final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
        expect(body['email'], isTrue);
        expect(body['emailSubject'], 'Message for U12');
        expect(body['emailBody'], 'See you on the ice.');
      },
    );

    test(
      'Issue 737: asserts locally when email is true without subject',
      () async {
        final h = _harness();

        expect(
          () => h.source.createBroadcast(
            audienceSelector: const AudienceSelector.allUsers(),
            payload: _payload,
            email: true,
            emailBody: 'body only',
          ),
          throwsA(isA<AssertionError>()),
        );
        expect(h.requests, isEmpty, reason: 'must fail before the round-trip');
      },
    );

    test(
      'Issue 737: asserts locally when email is true without body',
      () async {
        final h = _harness();

        expect(
          () => h.source.createBroadcast(
            audienceSelector: const AudienceSelector.allUsers(),
            payload: _payload,
            email: true,
            emailSubject: 'subject only',
          ),
          throwsA(isA<AssertionError>()),
        );
        expect(h.requests, isEmpty, reason: 'must fail before the round-trip');
      },
    );
  });
}
