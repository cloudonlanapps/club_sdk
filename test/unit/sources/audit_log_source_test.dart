import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// RemoteAuditLogSource request and response handling, via MockClient.
void main() {
  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  // The server is the one judge of this rule: the SDK sends the request and
  // surfaces the server's 422, the same in debug and release builds.
  // Before #35 the call threw AssertionError before any request (debug only).
  group("Issue 35 (R8): the audit-log scope rule is the server's", () {
    test(
      'Issue 35: a half audit-log scope surfaces INVALID_RESOURCE_SCOPE',
      () async {
        final requests = <Uri>[];
        final store = RemoteStore(
          baseUrl: 'https://example.test/v1',
          maxRetries: 0,
          client: MockClient((request) async {
            requests.add(request.url);
            return json({
              'detail': {
                'code': 'INVALID_RESOURCE_SCOPE',
                'message':
                    'resource_type and resource_id must be provided together',
              },
            }, 422);
          }),
        );
        final client = await createRemoteSecureClient(
          baseUrl: 'https://example.test/v1',
          store: store,
        );

        await expectLater(
          client.auditLog.list(resourceType: 'event'),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'status', 422)
                .having(
                  (e) => e.code,
                  'code',
                  SdkErrorCode.invalidResourceScope,
                ),
          ),
        );
        expect(requests.single.queryParameters['resource_type'], 'event');
        expect(
          requests.single.queryParameters.containsKey('resource_id'),
          isFalse,
        );
      },
    );
  });
}
