import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#512: a blocked user receives only notices about their own
/// account (`user.blocked`, `user.role_changed`, …), never club activity
/// (group notices, broadcasts, events, …).
///
/// A blocked user cannot log in, so the notices are sent while they are
/// blocked and their feed is read after an admin unblocks them. A broadcast
/// is also checked through its recipient list.
void main() {
  group('club_server#512: notifications to a blocked user', () {
    late SecureClient admin;
    late SecureClient blockedClient;
    late SecureClient activeClient;
    late int groupId;
    late int broadcastId;
    late List<AppNotification> blockedFeed;
    late List<AppNotification> activeFeed;

    const password = 'password123';
    const blocked = 'test_i512_blocked';
    const active = 'test_i512_active';
    const groupName = 'test_i512_group';
    const renamed = 'test_i512_group renamed';

    Future<void> approved(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000512',
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

      await approved(blocked);
      await approved(active);

      final g = await admin.groups.createGroup(name: groupName);
      groupId = g.id;
      await admin.groups.addMember(groupId, blocked);
      await admin.groups.addMember(groupId, active);
      final members = await admin.groups.getMembers(groupId);
      expect(
        members.map((m) => m.membername),
        containsAll(<String>[blocked, active]),
      );

      final b1 = await admin.users.blockUser(blocked);
      expect(b1.status, UserStatus.blocked);

      // Every notice below is sent while `blocked` is blocked.
      await admin.users.assignRole(blocked, 'coach');
      final g2 = await admin.groups.updateGroup(groupId, name: renamed);
      expect(g2.name, renamed);
      final b = await admin.broadcasts.createBroadcast(
        audienceSelector: AudienceSelector.group(groupId),
        payload: const {
          'v': 1,
          'type': 'broadcast.message',
          'data': {'title': 'test_i512 broadcast'},
        },
      );
      broadcastId = b.id;

      final back = await admin.users.unblockUser(blocked);
      expect(back.status, UserStatus.active);

      blockedClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await blockedClient.auth.login(blocked, password);
      expect((await blockedClient.auth.getCurrentUser()).username, blocked);
      activeClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await activeClient.auth.login(active, password);
      expect((await activeClient.auth.getCurrentUser()).username, active);

      blockedFeed = await feedOf(blockedClient);
      activeFeed = await feedOf(activeClient);
    });

    tearDownAll(() async {
      try {
        await admin.broadcasts.revokeBroadcast(broadcastId);
      } on ServerException {
        // Already revoked or never created; nothing left to clean up.
      }
      await blockedClient.auth.logout();
      await activeClient.auth.logout();
      await admin.auth.logout();
    });

    group('a blocked user', () {
      test('receives the notice of the block (user.blocked)', () {
        expect(
          blockedFeed.where((n) => n.type == NotificationType.userBlocked),
          hasLength(1),
        );
      });

      test('receives an account notice (user.role_changed)', () {
        final notices = blockedFeed
            .where((n) => n.type == NotificationType.userRoleChanged)
            .toList();
        expect(notices, hasLength(1));
        expect(
          (notices.single.payload['data'] as Map)['added'],
          <String>['coach'],
        );
      });

      test('receives no group notice (group.settings_changed)', () {
        expect(blockedFeed.where(isRename), isEmpty);
      });

      test('is not a recipient of a broadcast to their group', () async {
        final recipients = await admin.broadcasts.listRecipients(broadcastId);
        expect(
          recipients.items.map((r) => r.username),
          isNot(contains(blocked)),
        );
      });

      test('has no broadcast in their feed', () {
        expect(blockedFeed.where(isBroadcast), isEmpty);
      });
    });

    group('an active user in the same audience', () {
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
