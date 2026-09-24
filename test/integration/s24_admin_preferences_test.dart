import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Section 24: System preferences.
///
/// AdminSource coverage:
/// - [`x`] listPreferences
/// - [`x`] getPreference
/// - [`x`] setPreference
void main() {
  group('Section 24: System preferences', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(sudoUsername, sudoPassword);
    });

    test('24.01: list returns the preference set', () async {
      final prefs = await client.admin.listPreferences();
      expect(prefs, isA<List<SystemPreference>>());
      for (final p in prefs) {
        expect(p.key, isNotEmpty);
      }
    });

    test('24.02: set then read back returns the written value', () async {
      final prefs = await client.admin.listPreferences();
      if (prefs.isEmpty) {
        markTestSkipped('server exposes no preferences to write');
        return;
      }
      final key = prefs.first.key;
      final original = prefs.first.value;

      final written = await client.admin.setPreference(key, original);
      expect(written.key, key);
      expect(written.value, original);

      // Verify through the read path too, not just the write response.
      final read = await client.admin.getPreference(key);
      expect(read.key, key);
      expect(read.value, original);
      expect(read.updatedAtUtc.isUtc, isTrue);
    });

    test(
      '24.03: attendance report accepts a window and returns records',
      () async {
        final from = DateTime.utc(2020);
        final to = DateTime.utc(2020, 1, 2);
        final records = await client.attendance.listAttendanceInRange(
          fromTimeUtc: from,
          toTimeUtc: to,
        );
        // A window with no events is legitimately empty; the assertion is that
        // the call resolves and parses, which the removed /attendance/summary
        // endpoint never did.
        expect(records, isA<List<AttendanceRecord>>());
      },
    );
  });
}
