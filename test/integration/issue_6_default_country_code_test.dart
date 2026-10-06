import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Issue 6: `GET /capabilities` reports the club's country calling code
/// (club_server#15). Both test confs set `default_country_code = 91`.
void main() {
  group('Issue 6: default country code', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(sudoUsername, sudoPassword);
      final me = await client.auth.getCurrentUser();
      expect(me.username, sudoUsername);
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    test("Issue 6: a signed-in user reads the deployment's code", () async {
      final caps = await client.capabilities.getCapabilities();
      expect(caps.defaultCountryCode, '91');
    });

    test('Issue 6: a client that has not logged in reads the same '
        'code', () async {
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      final caps = await anon.capabilities.getCapabilities();
      expect(caps.defaultCountryCode, '91');
    });
  });
}
