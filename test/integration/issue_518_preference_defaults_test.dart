import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/mock_seed_data.dart';
import '../utils/test_client.dart';

/// club_server#518: a preference the server has a default for reports that
/// default until it is written.
///
/// A never-written preference has no "last updated" time: the server returns
/// its default if it has one, otherwise an empty value, and
/// [SystemPreference.updatedAtUtc] is `null`.
void main() {
  group('club_server#518: preference defaults', () {
    late SecureClient admin;
    const retentionKey = 'notification_info_retention_days';
    const retentionDefault = 90;

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      // Leave the sweep on its default for the rest of the stack's run.
      await admin.admin.setPreference(retentionKey, retentionDefault);
      await admin.auth.logout();
    });

    test('Issue 518: the retention preference reads its default before any '
        'write, with no updated-at', () async {
      final pref = await admin.admin.getPreference(retentionKey);
      expect(pref.key, retentionKey);
      expect(pref.value, retentionDefault);
      expect(pref.updatedAtUtc, isNull);
      expect(pref.updatedBy, isNull);
    });

    test('Issue 518: a key with no server default reads an empty value '
        'with no updated-at', () async {
      final key = '${testPrefix}i518_${DateTime.now().millisecondsSinceEpoch}';
      final pref = await admin.admin.getPreference(key);
      expect(pref.key, key);
      expect(pref.value, isNull);
      expect(pref.updatedAtUtc, isNull);
    });

    test('Issue 518: the retention preference reads the written value, '
        'stamped, after a write', () async {
      final before = DateTime.now().toUtc().subtract(
        const Duration(minutes: 1),
      );
      final written = await admin.admin.setPreference(retentionKey, 45);
      expect(written.value, 45);

      final pref = await admin.admin.getPreference(retentionKey);
      expect(pref.value, 45);
      expect(pref.updatedAtUtc, isNotNull);
      expect(pref.updatedAtUtc!.isAfter(before), isTrue);
      expect(pref.updatedBy, sudoUsername);
    });
  });
}
