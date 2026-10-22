import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 53: deleteUser returns the user the DELETE answers with.
void main() {
  group('Issue 53: deleteUser', () {
    // The server answers DELETE /users/by_id/{username} with the
    // soft-deleted user (club_server routers/users.py:630,
    // response_model=UserInfoResponse). Any GET is a 503, so a follow-up
    // fetch shows up as a failure.
    test(
      'Issue 53: deleteUser returns the DELETE response, in one request',
      () async {
        final deletedAt = DateTime.utc(2026, 10, 22, 9);
        final requests = <String>[];
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          maxRetries: 0,
          client: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.method == 'DELETE') {
              return http.Response(
                jsonEncode({
                  'username': 'alice',
                  'roles': ['member'],
                  'deletedAtUtc': deletedAt.millisecondsSinceEpoch,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('', 503);
          }),
        );
        final client = await createRemoteSecureClient(
          baseUrl: 'https://example.test/v1',
          store: store,
        );

        final user = await client.users.deleteUser('alice');

        expect(user.username, 'alice');
        expect(user.deletedAtUtc, deletedAt);
        expect(requests, ['DELETE /v1/users/by_id/alice']);
      },
    );
  });
}
