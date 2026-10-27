import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// The integration suite runs on two stacks, following club_client's
/// (#86):
///
/// - `sdk_test_server1.conf` (`just test`, `just test-one`): identity
///   verification, the extended profile and applications on; the credit
///   system, evaluations and event marketing off.
/// - `sdk_test_server2.conf` (`just test-server2`): the credit system,
///   evaluations and event marketing on; identity verification, the
///   extended profile and applications off.
///
/// Every suite that branches on `/v1/capabilities` relies on the stack
/// being one of these two: each half of such a suite runs on one of them
/// and skips on the other. A stack of any other shape would leave cases
/// skipped on both, so this file fails on one.
void main() {
  test(
    'Issue 86: the stack is configured as one of the two test confs',
    () async {
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      final caps = await anon.capabilities.getCapabilities();
      final flags = {
        'identityVerification': caps.identityVerification,
        'extendedProfile': caps.extendedProfile,
        'applications': caps.applications,
        'creditSystem': caps.creditSystem,
        'evaluations': caps.evaluations,
        'eventMarketing': caps.eventMarketing,
      };
      const config1 = {
        'identityVerification': true,
        'extendedProfile': true,
        'applications': true,
        'creditSystem': false,
        'evaluations': false,
        'eventMarketing': false,
      };
      final config2 = {
        for (final e in config1.entries) e.key: !e.value,
      };
      expect(
        flags,
        anyOf(equals(config1), equals(config2)),
        reason: 'neither sdk_test_server1.conf nor sdk_test_server2.conf',
      );
    },
  );
}
