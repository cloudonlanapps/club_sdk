import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 519 — SDK pin for server PR
/// `club_server#146` (issue #145).
///
/// `group_join_requests` now has a plain unique constraint on
/// `(group_id, username)`. `joinGroup` after a terminal state revives
/// the existing row instead of inserting a new one — `id` is reused.
/// `listMyRequests` therefore returns at most one row per
/// `(user, group)` regardless of how many join/cancel cycles ran.
///
/// Mirrors server tests `test_issue_145_*` at the SDK layer so a
/// regression in the wire decode (or a server-side schema revert)
/// trips here, not only at the app layer (#518).
void main() {
  group(
    'Issue 519: join-request row is reused across request/cancel cycles',
    () {
      late SecureClient adminClient;
      late SecureClient memberClient;

      const member = 'test_issue519_member';
      const memberPwd = 'password123';
      const groupName = 'test_issue519_group';

      late int groupId;

      setUpAll(() async {
        adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
        memberClient = await createRemoteSecureClient(baseUrl: baseUrl);

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
          username: member,
          email: '$member@test.com',
          password: memberPwd,
          firstName: 'Issue519',
          phone: '0000000000',
          gender: Gender.male,
          dateOfBirthUtc: DateTime.utc(2012, 6, 15),
        );

        final g = await adminClient.groups.createGroup(name: groupName);
        groupId = g.id;

        await adminClient.auth.logout();
      });

      setUp(() async {
        await memberClient.auth.login(member, memberPwd);
      });

      tearDown(() async {
        try {
          await memberClient.auth.logout();
        } on Exception {
          // ignore
        }
      });

      test(
        'Issue 519: request after cancel reuses the same join-request id',
        () async {
          final first = await memberClient.myGroups.joinGroup(member, groupId);
          expect(first.status, JoinRequestStatus.pending);

          final cancelled = await memberClient.myGroups.cancelRequest(
            member,
            first.id,
          );
          expect(cancelled.id, first.id);
          expect(cancelled.status, JoinRequestStatus.cancelled);

          final second = await memberClient.myGroups.joinGroup(member, groupId);
          expect(
            second.id,
            first.id,
            reason: 're-requesting after cancel must revive the existing row',
          );
          expect(second.status, JoinRequestStatus.pending);
          expect(second.decidedAt, isNull);
          expect(second.decidedBy, isNull);

          final listing = await memberClient.myGroups.listMyRequests(member);
          final mine = listing.where((r) => r.groupId == groupId).toList();
          expect(
            mine,
            hasLength(1),
            reason: 'listMyRequests must return one row per (user, group)',
          );
          expect(mine.first.id, first.id);
          expect(mine.first.status, JoinRequestStatus.pending);

          // Cleanup: leave the request cancelled so the cycle test below
          // starts from a clean state.
          await memberClient.myGroups.cancelRequest(member, first.id);
        },
      );

      test(
        'Issue 519: three request/cancel cycles keep a single row',
        () async {
          int? firstId;
          for (var i = 0; i < 3; i++) {
            final created = await memberClient.myGroups.joinGroup(
              member,
              groupId,
            );
            firstId ??= created.id;
            expect(
              created.id,
              firstId,
              reason: "cycle ${i + 1}: id must equal the first row's id",
            );
            expect(created.status, JoinRequestStatus.pending);

            final cancelled = await memberClient.myGroups.cancelRequest(
              member,
              created.id,
            );
            expect(cancelled.id, firstId);
            expect(cancelled.status, JoinRequestStatus.cancelled);

            final listing = await memberClient.myGroups.listMyRequests(member);
            final mine = listing.where((r) => r.groupId == groupId).toList();
            expect(
              mine,
              hasLength(1),
              reason:
                  'cycle ${i + 1}: listMyRequests must collapse to '
                  'one row',
            );
          }
        },
      );

      tearDownAll(() async {
        await adminClient.auth.login(sudoUsername, sudoPassword);
        try {
          await adminClient.groups.deleteGroup(groupId);
        } on Exception {
          // ignore — leftover cleanup
        }
        await adminClient.auth.logout();
      });
    },
  );
}
