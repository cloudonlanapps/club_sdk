import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/mock_seed_data.dart';
import '../utils/test_client.dart';

/// club_server#525: writing a system preference is recorded in the audit
/// log, with the actor and the key.
///
/// The server has not named the audit action yet, so the row is found as the
/// one newer than the write by the super admin, not by its action.
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

    test('Issue 525: one audit row names the actor and the key', () async {
      final key = '${testPrefix}i525_${DateTime.now().millisecondsSinceEpoch}';
      final before = (await sudoRows()).fold<int>(
        0,
        (m, r) => r.id > m ? r.id : m,
      );

      final written = await admin.admin.setPreference(key, {'on': true});
      expect(written.key, key);

      final rows = (await sudoRows()).where((r) => r.id > before).toList();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.actor?.username, sudoUsername);
      final recorded = jsonEncode({
        'resource': row.resource,
        'details': row.details,
      });
      expect(recorded, contains(key));
    });
  });
}
