import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 651 — server contract for a pending join request that outlives the
/// requester's eligibility.
///
/// A member requests to join a MANUAL group; an admin then flips the group to
/// SEMI-AUTO with a criterion the member fails. The group drops out of the
/// member's eligible list (and the app hides the request — #649), but the
/// pending request still exists server-side. This pins how the admin can
/// resolve it:
///   - approve → refused with `ServerException(NOT_ELIGIBLE)`: an ineligible
///     user cannot be force-added via approval;
///   - reject  → succeeds, leaving the member a non-member.
///
/// Confirms the client-side decision to simply hide such a request (#649)
/// does not orphan it: the admin can always reject it.
void main() {
  group('Issue 651: approving a now-ineligible pending request is refused', () {
    late SecureClient adminClient;
    late SecureClient memberClient;

    const member = 'test_651_member';
    const memberPwd = 'password123';

    final createdGroupIds = <int>[];
    var groupCounter = 0;

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      memberClient = await createRemoteSecureClient(baseUrl: baseUrl);

      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await adminClient.auth.login(sudoUsername, sudoPassword);

      // A non-staff female member: staff are exempt from semi-auto
      // eligibility, and the male-only criterion applied later excludes her.
      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: member,
        email: '$member@test.com',
        password: memberPwd,
        firstName: 'Issue651',
        phone: '0000000000',
        gender: Gender.female,
        dateOfBirthUtc: DateTime.utc(2012, 6, 15),
      );
      // registerAndApprove leaves the admin session active.
      await adminClient.auth.logout();
    });

    tearDown(() async {
      try {
        await memberClient.auth.logout();
      } on Exception {
        /* ignore */
      }
    });

    tearDownAll(() async {
      await adminClient.auth.login(sudoUsername, sudoPassword);
      for (final id in createdGroupIds) {
        try {
          await adminClient.groups.deleteGroup(id);
        } on Exception {
          /* best-effort */
        }
      }
      try {
        await adminClient.users.deleteUser(member);
      } on Exception {
        /* best-effort */
      }
      try {
        await adminClient.users.hardDeleteUser(member);
      } on Exception {
        /* best-effort */
      }
      await adminClient.auth.logout();
    });

    /// Creates a fresh manual group, has [member] request to join, then flips
    /// the group to semi-auto with a male-only criterion the (female) member
    /// fails. Asserts the group then drops out of the member's eligible list
    /// while the pending request survives. Returns the (groupId, requestId).
    Future<({int groupId, int requestId})>
    setUpIneligiblePendingRequest() async {
      groupCounter += 1;
      final groupName = 'test_651_group_$groupCounter';

      await adminClient.auth.login(sudoUsername, sudoPassword);
      final group = await adminClient.groups.createGroup(name: groupName);
      createdGroupIds.add(group.id);
      expect(
        group.kind,
        GroupKind.manual,
        reason: 'a group created with no criteria is manual',
      );
      await adminClient.auth.logout();

      // Member requests to join while the group is still manual.
      await memberClient.auth.login(member, memberPwd);
      final request = await memberClient.myGroups.joinGroup(member, group.id);
      expect(request.status, JoinRequestStatus.pending);
      await memberClient.auth.logout();

      // Admin tightens the group: manual → semi-auto, male-only.
      await adminClient.auth.login(sudoUsername, sudoPassword);
      final flipped = await adminClient.groups.updateGroup(
        group.id,
        semiAuto: true,
        gender: () => Gender.male,
      );
      expect(flipped.kind, GroupKind.semiAuto);
      await adminClient.auth.logout();

      // The member (female) is now ineligible: the group drops out of the
      // eligible list, but the pending request survives.
      await memberClient.auth.login(member, memberPwd);
      final eligible = await memberClient.myGroups.listEligible(member);
      expect(
        eligible.where((g) => g.id == group.id),
        isEmpty,
        reason: 'an ineligible member must not see the group as eligible',
      );
      final pending = (await memberClient.myGroups.listMyRequests(
        member,
      )).where((r) => r.groupId == group.id).toList();
      expect(pending, hasLength(1));
      expect(
        pending.single.status,
        JoinRequestStatus.pending,
        reason: 'the pending request survives the eligibility change',
      );
      await memberClient.auth.logout();

      return (groupId: group.id, requestId: request.id);
    }

    test(
      'Issue 651: an admin cannot approve a now-ineligible pending request '
      '(NOT_ELIGIBLE); reject resolves it and the member is never added',
      () async {
        final (:groupId, :requestId) = await setUpIneligiblePendingRequest();

        // ── Case A — approve is refused for the now-ineligible user. ──
        await adminClient.auth.login(sudoUsername, sudoPassword);
        await expectLater(
          adminClient.groups.approveRequest(groupId, requestId),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.notEligible,
            ),
          ),
          reason:
              'approving a semi-auto group request for an ineligible user '
              'must be refused',
        );
        await adminClient.auth.logout();

        // The refused approval added nothing: no membership, request pending.
        await memberClient.auth.login(member, memberPwd);
        expect(
          (await memberClient.myGroups.listGroups(
            member,
          )).where((g) => g.id == groupId),
          isEmpty,
          reason: 'a refused approval must not add the member to the group',
        );
        expect(
          (await memberClient.myGroups.listMyRequests(
            member,
          )).singleWhere((r) => r.groupId == groupId).status,
          JoinRequestStatus.pending,
          reason: 'the request stays pending after a refused approval',
        );
        await memberClient.auth.logout();

        // ── Case B — reject resolves the request. ──
        await adminClient.auth.login(sudoUsername, sudoPassword);
        final rejected = await adminClient.groups.rejectRequest(
          groupId,
          requestId,
          reason: 'no longer meets the group criteria',
        );
        expect(rejected.status, JoinRequestStatus.rejected);
        await adminClient.auth.logout();

        // The member is still not a member, and the request is now rejected.
        await memberClient.auth.login(member, memberPwd);
        expect(
          (await memberClient.myGroups.listGroups(
            member,
          )).where((g) => g.id == groupId),
          isEmpty,
          reason: 'a rejected request never makes the member a group member',
        );
        expect(
          (await memberClient.myGroups.listMyRequests(
            member,
          )).singleWhere((r) => r.groupId == groupId).status,
          JoinRequestStatus.rejected,
        );
        await memberClient.auth.logout();
      },
    );
  });
}
