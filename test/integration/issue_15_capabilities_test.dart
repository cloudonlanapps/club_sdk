import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Issue 15: `GET /capabilities` (club_server#339, #302, #410). Passes on
/// a stack with the modules on or off; the module suites assert the
/// specific answer for their conf.
void main() {
  group('Issue 15: capabilities', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createTestClient();
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    test(
      'Issue 15: any authenticated user can read the capabilities',
      () async {
        final caps = await client.capabilities.getCapabilities();
        expect(
          caps.toMap().keys,
          containsAll(['creditSystem', 'evaluations', 'eventMarketing']),
        );

        final member = await createRemoteSecureClient(baseUrl: baseUrl);
        await member.auth.login('test_alice', 'password123');
        expect(await member.capabilities.getCapabilities(), caps);
        await member.auth.logout();
      },
    );

    test('Issue 15: an anonymous caller is refused', () async {
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      await expectLater(
        anon.capabilities.getCapabilities(),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 401),
        ),
      );
    });
  });
}
