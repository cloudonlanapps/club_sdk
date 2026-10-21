import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

const _password = 'password123';
const _admin = 'test_admin_i35';

/// Issue 35: the SDK no longer asserts the argument rules of createBroadcast
/// and auditLog.list; it sends the request and the server's 422 is the
/// answer, the same in debug and release builds.
void main() {
  group("Issue 35: argument rules are the server's", () {
    late SecureClient adminClient;

    setUpAll(() async {
      final setup = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: setup,
        username: sudoUsername,
        password: sudoPassword,
      );
      await setup.auth.login(sudoUsername, sudoPassword);
      await registerAndApprove(
        client: setup,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: _admin,
        email: '$_admin@test.com',
        password: _password,
        firstName: 'I35',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await setup.users.assignRole(_admin, 'admin');
      await setup.auth.logout();

      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await adminClient.auth.login(_admin, _password);
      expect((await adminClient.auth.getCurrentUser()).username, _admin);
    });

    tearDownAll(() async {
      try {
        await adminClient.auth.logout();
      } on Exception {
        /* ignore */
      }
    });

    test('Issue 35: a broadcast by email without a subject is the '
        "server's 422 and is not created", () async {
      const title = 'test_I35 email without subject';
      await expectLater(
        adminClient.broadcasts.createBroadcast(
          audienceSelector: const AudienceSelector.role('admin'),
          payload: const {
            'v': 1,
            'type': 'broadcast.message',
            'data': {'title': title},
          },
          email: true,
          emailBody: 'body only',
        ),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 422),
        ),
      );

      final page = await adminClient.broadcasts.listBroadcasts(limit: 100);
      expect(
        page.items.where(
          (b) => (b.payload['data'] as Map?)?['title'] == title,
        ),
        isEmpty,
      );
    });

    test('Issue 35: an audit-log read with only resourceType is the '
        "server's 422 INVALID_RESOURCE_SCOPE", () async {
      await expectLater(
        adminClient.auditLog.list(resourceType: 'event'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.invalidResourceScope,
              ),
        ),
      );
    });

    test('Issue 35: an audit-log read with only resourceId is the '
        "server's 422 INVALID_RESOURCE_SCOPE", () async {
      await expectLater(
        adminClient.auditLog.list(resourceId: '1'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.invalidResourceScope,
              ),
        ),
      );
    });
  });
}
