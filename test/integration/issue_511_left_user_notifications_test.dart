import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#511: a user who has left receives no notification of any
/// kind, while an active user in the same audience still does.
///
/// A left user cannot log in, so each notice is sent while they are left and
/// their feed is read after an admin reactivates them (reactivation sends
/// nothing itself). A broadcast is also checked through its recipient list.
/// One case per type family: a named-user notice (`user.role_changed`), a
/// group notice (`group.settings_changed`) and a broadcast.
void main() {
  group('club_server#511: notifications to a user who has left', () {
    late SecureClient admin;
    late SecureClient leftClient;
    late SecureClient activeClient;
    late int groupId;
    late int broadcastId;
    late List<AppNotification> leftFeed;
    late List<AppNotification> activeFeed;

    const password = 'password123';
    const left = 'test_i511_left';
    const active = 'test_i511_active';
    const groupName = 'test_i511_group';
    const renamed = 'test_i511_group renamed';

    Future<void> approved(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000511',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.male,
    );

    /// Every notification [client] holds, newest first.
    Future<List<AppNotification>> feedOf(SecureClient client) async {
      final all = <AppNotification>[];
      const limit = 100;
      for (var offset = 0; ; offset += limit) {
        final page = await client.notifications.getNotifications(
          offset: offset,
          limit: limit,
        );
        all.addAll(page.items);
        if (page.items.length < limit) break;
      }
      return all;
    }

    bool isRoleChange(AppNotification n) =>
        n.type == NotificationType.userRoleChanged;

    bool isRename(AppNotification n) =>
        n.type == NotificationType.groupSettingsChanged &&
        (n.payload['data'] as Map?)?['groupId'] == groupId;

    bool isBroadcast(AppNotification n) =>
        n.type == NotificationType.broadcastMessage &&
        n.broadcastId == broadcastId;

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);

      await approved(left);
      await approved(active);

      final g = await admin.groups.createGroup(name: groupName);
      groupId = g.id;
      await admin.groups.addMember(groupId, left);
      await admin.groups.addMember(groupId, active);
      final members = await admin.groups.getMembers(groupId);
      expect(
        members.map((m) => m.membername),
        containsAll(<String>[left, active]),
      );

      final marked = await admin.users.markLeft(left);
      expect(marked.status, UserStatus.left);

      // Every notice below is sent while `left` has left.
      await admin.users.assignRole(left, 'coach');
      await admin.users.assignRole(active, 'coach');
      final g2 = await admin.groups.updateGroup(groupId, name: renamed);
      expect(g2.name, renamed);
      final b = await admin.broadcasts.createBroadcast(
        audienceSelector: AudienceSelector.group(groupId),
        payload: const {
          'v': 1,
          'type': 'broadcast.message',
          'data': {'title': 'test_i511 broadcast'},
        },
      );
      broadcastId = b.id;

      final back = await admin.users.reactivateUser(left);
      expect(back.status, UserStatus.active);

      leftClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await leftClient.auth.login(left, password);
      expect((await leftClient.auth.getCurrentUser()).username, left);
      activeClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await activeClient.auth.login(active, password);
      expect((await activeClient.auth.getCurrentUser()).username, active);

      leftFeed = await feedOf(leftClient);
      activeFeed = await feedOf(activeClient);
    });

    tearDownAll(() async {
      try {
        await admin.broadcasts.revokeBroadcast(broadcastId);
      } on ServerException {
        // Already revoked or never created; nothing left to clean up.
      }
      await leftClient.auth.logout();
      await activeClient.auth.logout();
      await admin.auth.logout();
    });

    group('a user who has left', () {
      test('receives no named-user notice (user.role_changed)', () {
        expect(leftFeed.where(isRoleChange), isEmpty);
      });

      test('receives no group notice (group.settings_changed)', () {
        expect(leftFeed.where(isRename), isEmpty);
      });

      test('is not a recipient of a broadcast to their group', () async {
        final recipients = await admin.broadcasts.listRecipients(broadcastId);
        expect(recipients.items.map((r) => r.username), isNot(contains(left)));
      });

      test('has no broadcast in their feed', () {
        expect(leftFeed.where(isBroadcast), isEmpty);
      });
    });

    group('an active user in the same audience', () {
      test('receives the named-user notice', () {
        final notices = activeFeed.where(isRoleChange).toList();
        expect(notices, hasLength(1));
        expect(
          (notices.single.payload['data'] as Map)['added'],
          <String>['coach'],
        );
      });

      test('receives the group notice', () {
        expect(activeFeed.where(isRename), hasLength(1));
      });

      test('is a recipient of the broadcast', () async {
        final recipients = await admin.broadcasts.listRecipients(broadcastId);
        expect(recipients.items.map((r) => r.username), contains(active));
        expect(activeFeed.where(isBroadcast), hasLength(1));
      });
    });
  });
}
