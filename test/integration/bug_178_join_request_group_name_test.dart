import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Bug #178 — My Groups joinable section showed `Group #<id>` instead of
/// the real group name.
///
/// Server-side fix (server #97 / PR #98) added:
///   * `groupName` on every `JoinRequestResponse`.
///   * `requested: bool` on `GroupResponse`, with `list_eligible_groups`
///     now including pending-request groups tagged true.
///
/// This SDK integration test pins both contracts so a server-side
/// regression in the member-facing payload trips immediately.
void main() {
  group('Bug 178: join-request payload exposes group name', () {
    late SecureClient adminClient;
    late SecureClient memberClient;

    const member = 'test_bug178_member';
    const memberPwd = 'password123';
    const semiName = 'test_bug178_semi_group';
    const manualName = 'test_bug178_manual_group';

    late int semiId;
    late int manualId;

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
        firstName: 'Bug178',
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: DateTime.utc(2012, 6, 15),
      );

      final semi = await adminClient.groups.createGroup(
        name: semiName,
        dobOnOrAfterUtc: DateTime.utc(2010),
        dobOnOrBeforeUtc: DateTime.utc(2014),
        gender: Gender.male,
        semiAuto: true,
      );
      semiId = semi.id;

      final manual = await adminClient.groups.createGroup(name: manualName);
      manualId = manual.id;

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

    test('Issue 178: joinGroup response carries groupName', () async {
      final req = await memberClient.myGroups.joinGroup(member, semiId);
      expect(req.groupId, semiId);
      expect(
        req.groupName,
        semiName,
        reason: 'server #97 must populate groupName on JoinRequestResponse',
      );
    });

    test('Issue 178: listMyRequests entries carry groupName', () async {
      // Submit a request against the manual group (semi-auto was hit in
      // the previous test; both groups have pending requests now).
      await memberClient.myGroups.joinGroup(member, manualId);

      final requests = await memberClient.myGroups.listMyRequests(member);
      expect(requests, isNotEmpty);
      for (final r in requests) {
        expect(
          r.groupName,
          isNotEmpty,
          reason: 'every JoinRequest must expose its groupName',
        );
      }
      final byId = {for (final r in requests) r.groupId: r};
      expect(byId[semiId]?.groupName, semiName);
      expect(byId[manualId]?.groupName, manualName);
    });

    test(
      'Issue 178: eligible list includes pending-request groups with '
      'requested=true',
      () async {
        final eligible = await memberClient.myGroups.listEligible(member);
        final byId = {for (final g in eligible) g.id: g};

        expect(
          byId[semiId]?.requested,
          isTrue,
          reason: 'semi-auto pending request must be flagged requested',
        );
        expect(
          byId[manualId]?.requested,
          isTrue,
          reason: 'manual pending request must be flagged requested',
        );
        // Names must round-trip — this is what the UI now uses.
        expect(byId[semiId]?.name, semiName);
        expect(byId[manualId]?.name, manualName);
      },
    );
  });
}
