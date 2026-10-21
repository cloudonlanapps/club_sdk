import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart' show ServerException;
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

    for (final (label, subject, body) in [
      ('without a subject', null, 'body only'),
      ('without a body', 'subject only', null),
    ]) {
      test(
        'Issue 35: email $label is sent to the server, not asserted locally',
        () async {
          final h = _harness();

          await h.source.createBroadcast(
            audienceSelector: const AudienceSelector.allUsers(),
            payload: _payload,
            email: true,
            emailSubject: subject,
            emailBody: body,
          );

          final sent =
              jsonDecode(h.requests.single.body) as Map<String, dynamic>;
          expect(sent['email'], isTrue);
          expect(sent['emailSubject'], subject);
          expect(sent['emailBody'], body);
        },
      );
    }
  });

  // The server is the one judge of this rule: the SDK sends the request and
  // surfaces the server's 422, the same in debug and release builds.
  // Before #35 the call threw AssertionError before any request (debug only).
  group("Issue 35 (R8): the email rule is the server's", () {
    test(
      'Issue 35: email without a subject reaches the server and surfaces '
      'its 422',
      () async {
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'detail': [
                  {
                    'type': 'value_error',
                    'loc': ['body'],
                    'msg':
                        'Value error, emailSubject and emailBody are '
                        'required when email is true',
                  },
                ],
              }),
              422,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        await expectLater(
          RemoteBroadcastSource(store).createBroadcast(
            audienceSelector: const AudienceSelector.allUsers(),
            payload: const {'title': 'x'},
            email: true,
          ),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 422),
          ),
        );
      },
    );
  });
}
