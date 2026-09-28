import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#524: adding a member directly while they have a pending
/// join request resolves the request as approved and deletes the admins'
/// `group.join_request` notices, exactly as approving the request does
/// (notifications:R36). Covered for the single and the bulk add.
void main() {
  group('club_server#524: a direct add clears the join-request notices', () {
    late SecureClient admin;
    late SecureClient staffClient;
    final memberClients = <String, SecureClient>{};
    final requestIds = <String, int>{};
    late int groupId;

    const password = 'password123';
    const staff = 'test_i524_admin';
    const single = 'test_i524_single';
    const bulk = 'test_i524_bulk';

    Future<void> approved(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000524',
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

    /// [client]'s join-request notices for [member]'s request.
    Future<List<AppNotification>> joinNotices(
      SecureClient client,
      String member,
    ) async => (await feedOf(client))
        .where(
          (n) =>
              n.type == NotificationType.groupJoinRequest &&
              n.pendingActionId == requestIds[member],
        )
        .toList();

    Future<JoinRequest> requestOf(String member) async {
      final all = await admin.groups.listRequests(groupId);
      return all.singleWhere((r) => r.id == requestIds[member]);
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);

      await approved(staff);
      await admin.users.assignRole(staff, 'admin');
      await approved(single);
      await approved(bulk);

      final g = await admin.groups.createGroup(name: 'test_i524_group');
      groupId = g.id;

      staffClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await staffClient.auth.login(staff, password);
      expect((await staffClient.auth.getCurrentUser()).username, staff);

      for (final m in [single, bulk]) {
        final c = await createRemoteSecureClient(baseUrl: baseUrl);
        await c.auth.login(m, password);
        expect((await c.auth.getCurrentUser()).username, m);
        memberClients[m] = c;
        final req = await c.myGroups.joinGroup(m, groupId);
        expect(req.status, JoinRequestStatus.pending);
        requestIds[m] = req.id;
        expect(await joinNotices(staffClient, m), hasLength(1));
      }

      await admin.groups.addMember(groupId, single);
      await admin.groups.addMembersBulk(groupId, [bulk]);
      final members = await admin.groups.getMembers(groupId);
      expect(
        members.map((m) => m.membername),
        containsAll(<String>[single, bulk]),
      );
    });

    tearDownAll(() async {
      for (final c in [staffClient, ...memberClients.values]) {
        await c.auth.logout();
      }
      await admin.auth.logout();
    });

    for (final (member, how) in [(single, 'addMember'), (bulk, 'bulk add')]) {
      group('after $how', () {
        test('the request reads approved', () async {
          expect((await requestOf(member)).status, JoinRequestStatus.approved);
        });

        test("no admin's feed holds the join-request notice", () async {
          expect(await joinNotices(staffClient, member), isEmpty);
        });

        test("the super admin's feed holds no join-request notice", () async {
          expect(await joinNotices(admin, member), isEmpty);
        });
      });
    }
  });
}
