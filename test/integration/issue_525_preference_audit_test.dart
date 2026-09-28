import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/mock_seed_data.dart';
import '../utils/test_client.dart';

/// club_server#525: writing a system preference is recorded in the audit
/// log as `update_system_preference`, with the actor, the key and the
/// previous and new values (the previous is null for a key never written).
void main() {
  group('club_server#525: preference writes are audited', () {
    late SecureClient admin;

    Future<List<AuditLogRow>> sudoRows() async =>
        (await admin.auditLog.list(actor: sudoUsername, limit: 50)).rows;

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    Future<int> newestId() async =>
        (await sudoRows()).fold<int>(0, (m, r) => r.id > m ? r.id : m);

    Future<AuditLogRow> onlyRowAfter(int id) async {
      final rows = (await sudoRows()).where((r) => r.id > id).toList();
      expect(rows, hasLength(1));
      return rows.single;
    }

    test('Issue 525: the first write records the key, no previous value and '
        'the new value', () async {
      final key = '${testPrefix}i525_${DateTime.now().millisecondsSinceEpoch}';
      final before = await newestId();

      final written = await admin.admin.setPreference(key, {'on': true});
      expect(written.key, key);

      final row = await onlyRowAfter(before);
      expect(row.action, 'update_system_preference');
      expect(row.actor?.username, sudoUsername);
      expect(row.details?['key'], key);
      expect(row.details?['previousValue'], isNull);
      expect(row.details?['newValue'], contains('on'));
    });

    test('Issue 525: a second write records the previous value', () async {
      final key = '${testPrefix}i525b_${DateTime.now().millisecondsSinceEpoch}';
      await admin.admin.setPreference(key, {'level': 'first'});
      final before = await newestId();

      await admin.admin.setPreference(key, {'level': 'second'});

      final row = await onlyRowAfter(before);
      expect(row.action, 'update_system_preference');
      expect(row.details?['key'], key);
      expect(row.details?['previousValue'], contains('first'));
      expect(row.details?['newValue'], contains('second'));
    });
  });
}
