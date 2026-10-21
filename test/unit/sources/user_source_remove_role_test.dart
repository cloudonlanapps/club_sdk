import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 42: removeRole returns the user the DELETE answers with.
void main() {
  group('Issue 42: removeRole', () {
    // The server answers DELETE .../roles/{role} with the updated user
    // (club_server routers/users.py:542, response_model=UserInfoResponse).
    // Any GET is a 503, so a follow-up fetch shows up as a failure.
    test(
      'Issue 42: removeRole returns the DELETE response, in one request',
      () async {
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

        final user = await client.users.removeRole('alice', 'coach');

        expect(user.username, 'alice');
        expect(requests, ['DELETE /v1/users/by_id/alice/roles/coach']);
      },
    );
  });
}
