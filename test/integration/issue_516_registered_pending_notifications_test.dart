import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// club_server#516: a registered or pending user can read the unread
/// count, mark a notification read, and read and set their notification
/// preferences — the same gate as listing their own feed.
///
/// A registered user exists only while identity verification is on; those
/// cases skip on a stack with it off.
void main() {
  group('club_server#516: notifications for registered and pending users', () {
    late SecureClient admin;
    late bool verificationOn;
    final clients = <String, SecureClient>{};
    final noticeIds = <String, int>{};

    const password = 'password123';
    const registered = 'test_i516_registered';
    const pending = 'test_i516_pending';

    Future<UserInfo> registerOnly(String username) => admin.auth.register(
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000516',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.male,
    );

    Future<void> notify(String username) async {
      final n = await admin.notifications.createNotification(
        username: username,
        type: 'test.generic',
        channel: 'inApp',
        payload: const {
          'v': 1,
          'type': 'test.generic',
          'data': {'title': 'test_i516 notice'},
        },
      );
      expect(n.username, username);
      noticeIds[username] = n.id;
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      verificationOn = (await stackCapabilities(admin)).identityVerification;

      if (verificationOn) {
        final reg = await registerOnly(registered);
        expect(reg.status, UserStatus.registered);
        await notify(registered);
      }
      final pen = await registerOnly(pending);
      await submitForReviewIfRequired(
        client: admin,
        registered: pen,
        password: password,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
      );
      expect(
        (await admin.users.getUserInfo(pending)).status,
        UserStatus.pending,
      );
      await notify(pending);

      for (final u in [if (verificationOn) registered, pending]) {
        final c = await createRemoteSecureClient(baseUrl: baseUrl);
        await c.auth.login(u, password);
        expect((await c.auth.getCurrentUser()).username, u);
        clients[u] = c;
      }
    });

    tearDownAll(() async {
      for (final c in clients.values) {
        try {
          await c.auth.logout();
        } on ServerException {
          // Refused for a user who is not active until club_server#510.
        }
      }
      await admin.auth.logout();
    });

    for (final (username, status) in [
      (registered, UserStatus.registered),
      (pending, UserStatus.pending),
    ]) {
      bool skipped() =>
          status == UserStatus.registered &&
          skipUnless(enabled: verificationOn, module: 'identity verification');

      group('a ${status.name} user', () {
        test('reads their unread count', () async {
          if (skipped()) return;
          final c = clients[username]!;
          final unread = await c.notifications.getNotifications(
            unreadOnly: true,
            limit: 100,
          );
          expect(unread.items, isNotEmpty);
          expect(await c.notifications.getUnreadCount(), unread.items.length);
        });

        test('marks a notification read', () async {
          if (skipped()) return;
          final c = clients[username]!;
          final id = noticeIds[username]!;
          await c.notifications.markRead(id);
          final feed = await c.notifications.getNotifications(limit: 100);
          expect(feed.items.singleWhere((n) => n.id == id).isRead, isTrue);
        });

        test('reads their preferences', () async {
          if (skipped()) return;
          final prefs = await clients[username]!.notifications.getPreferences();
          // Never written: the server's defaults.
          expect(
            prefs,
            const NotificationPref(
              emailEnabled: true,
              pushEnabled: true,
              smsEnabled: false,
            ),
          );
        });

        test('sets their preferences', () async {
          if (skipped()) return;
          final c = clients[username]!;
          final updated = await c.notifications.updatePreferences(
            emailEnabled: false,
          );
          expect(updated.emailEnabled, isFalse);
          expect(
            (await c.notifications.getPreferences()).emailEnabled,
            isFalse,
          );
        });
      });
    }
  });
}
