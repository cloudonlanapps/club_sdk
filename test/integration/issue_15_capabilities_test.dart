import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Issue 15: `GET /capabilities` (club_server#339, #302, #410). Passes on
/// a stack with the modules on or off; the module suites assert the
/// specific answer for their conf. Issue 18: the server answers it before
/// login too (club_server#443), so a signup page can read it.
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

    test('Issue 18: a client that has not logged in reads the same '
        'capabilities as a signed-in one', () async {
      final signedIn = await client.capabilities.getCapabilities();
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      final caps = await anon.capabilities.getCapabilities();
      expect(caps, signedIn);
      expect(
        caps.toMap().keys,
        containsAll(['creditSystem', 'identityVerification']),
      );
    });
  });
}
