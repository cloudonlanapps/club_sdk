import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Diagnostic SDK integration test for the bug where an admin sees a join-
/// request notification attributed to the wrong user.
///
/// Reproduction scenario reported manually:
///   - Two members exist with similar-looking first names: `averystone` and
///     `averilstone`.
///   - `averystone` logs in and requests to join a manual group.
///   - The admin's notification panel attributes the request to
///     `averil stone` instead of `avery stone`.
///
/// This test exercises only the server + SDK path. If the server payload
/// already carries the wrong `requesterUsername`, the bug is server-side and
/// these expectations will fail. If they all pass, the server payload is
/// correct and the bug lives in the Flutter UI's display layer.
void main() {
  group('Bug: Group join request identity', () {
    late SecureClient adminClient;
    late SecureClient averyClient;

    const avery = 'test_averystone_bug';
    const averil = 'test_averilstone_bug';
    const password = 'password123';

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);

      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );

      await adminClient.auth.login(sudoUsername, sudoPassword);

      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: avery,
        email: '$avery@test.com',
        password: password,
        firstName: 'Avery',
        lastName: 'Stone',
        phone: '0000000001',
        dateOfBirthUtc: DateTime.utc(2014, 6, 15),
        gender: Gender.male,
      );

      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: averil,
        email: '$averil@test.com',
        password: password,
        firstName: 'Averil',
        lastName: 'Stone',
        phone: '0000000002',
        dateOfBirthUtc: DateTime.utc(2016, 4, 10),
        gender: Gender.female,
      );

      averyClient = await createRemoteSecureClient(baseUrl: baseUrl);
    });

    test(
      "admin notification for averystone's join request correctly identifies "
      'averystone (not averilstone)',
      () async {
        // Step 1: admin creates a manual group.
        final group = await adminClient.groups.createGroup(
          name: 'test_Bug Manual Group',
          description: 'Manual group for identity-bug repro',
        );
        expect(group.kind, GroupKind.manual);

        // Step 2: admin logs out so averystone can act as themselves.
        await adminClient.auth.logout();

        // Step 3: averystone logs in and confirms identity.
        await averyClient.auth.login(avery, password);
        final me = await averyClient.auth.getCurrentUser();
        expect(
          me.username,
          avery,
          reason: 'login should produce averystone session',
        );

        // Step 4: the manual group is listed as joinable.
        final eligible = await averyClient.myGroups.listEligible(avery);
        expect(
          eligible.any((g) => g.id == group.id),
          isTrue,
          reason: "manual group should appear in averystone's eligible list",
        );

        // Step 5: averystone submits a join request.
        final joinReq = await averyClient.myGroups.joinGroup(
          avery,
          group.id,
          reason: 'bug repro',
        );
        expect(
          joinReq.username,
          avery,
          reason:
              'JoinRequest returned to requester must carry '
              "averystone's username",
        );
        expect(joinReq.groupId, group.id);
        expect(joinReq.status, JoinRequestStatus.pending);

        // Double-verify via the user-facing my-requests list.
        final myReqs = await averyClient.myGroups.listMyRequests(avery);
        expect(
          myReqs.any((r) => r.id == joinReq.id && r.username == avery),
          isTrue,
        );

        // Step 6: averystone logs out, admin logs back in.
        await averyClient.auth.logout();
        await adminClient.auth.login(sudoUsername, sudoPassword);

        // Step 7: admin sees a notification for this join request and the
        // payload identifies averystone, NOT averilstone.
        final notifs = await adminClient.notifications.getNotifications(
          limit: 50,
        );
        final match = notifs.items.firstWhere(
          (n) =>
              n.pendingActionType == PendingActionType.groupJoinRequest &&
              n.pendingActionId == joinReq.id,
          orElse: () => throw TestFailure(
            'expected a groupJoinRequest notification linked to request '
            '${joinReq.id}, got: '
            '${notifs.items.map((n) => "${n.type}/${n.pendingActionType}/"
                "${n.pendingActionId}").join(", ")}',
          ),
        );

        // The recipient of the notification is the admin (sudo), not either
        // member — this just rules out a recipient mix-up.
        expect(match.username, sudoUsername);

        // The payload data carries the requester's identity. This is the
        // assertion that catches the reported bug.
        final data = match.payload['data'] as Map<String, dynamic>?;
        expect(
          data,
          isNotNull,
          reason: 'notification payload must carry a data envelope',
        );
        expect(
          data!['requesterUsername'],
          avery,
          reason:
              'notification must attribute the join request to averystone, '
              'not to a different user (bug: averilstone was shown)',
        );
        expect(
          data['requesterUsername'],
          isNot(averil),
          reason:
              'notification must not attribute the request to '
              'averilstone',
        );
        expect(data['groupId'], group.id);
        expect(data['groupName'], group.name);

        // Step 8: pending actions list surfaces the same request.
        final pending = await adminClient.notifications.listPendingActions(
          limit: 50,
        );
        final pendingMatch = pending.items.firstWhere(
          (n) =>
              n.pendingActionType == PendingActionType.groupJoinRequest &&
              n.pendingActionId == joinReq.id,
          orElse: () => throw TestFailure(
            'expected listPendingActions to surface join request '
            '${joinReq.id}',
          ),
        );
        final pendingData =
            pendingMatch.payload['data'] as Map<String, dynamic>?;
        expect(pendingData?['requesterUsername'], avery);

        // Step 9: admin-facing listRequests on the group sees the same
        // request, attributed to averystone.
        final reqs = await adminClient.groups.listRequests(
          group.id,
          status: JoinRequestStatus.pending,
        );
        final groupReq = reqs.firstWhere(
          (r) => r.id == joinReq.id,
          orElse: () => throw TestFailure(
            'group.listRequests missing request ${joinReq.id}',
          ),
        );
        expect(
          groupReq.username,
          avery,
          reason:
              'group.listRequests must attribute the request '
              'to averystone',
        );

        // Step 10: admin approves the request and averystone becomes a member.
        final approved = await adminClient.groups.approveRequest(
          group.id,
          joinReq.id,
        );
        expect(approved.status, JoinRequestStatus.approved);
        expect(approved.username, avery);

        final members = await adminClient.groups.getMembers(group.id);
        expect(
          members.any((m) => m.membername == avery),
          isTrue,
          reason: 'averystone should be a group member after approval',
        );
        expect(
          members.any((m) => m.membername == averil),
          isFalse,
          reason:
              'averilstone was never the requester and must not be '
              'added as a member',
        );
      },
    );

    tearDownAll(() async {
      try {
        await adminClient.auth.logout();
      } on Exception {
        // ignore
      }
      try {
        await averyClient.auth.logout();
      } on Exception {
        // ignore
      }
    });
  });
}
