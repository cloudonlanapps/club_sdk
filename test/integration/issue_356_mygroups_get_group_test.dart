import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue #356 — `MyGroupsSource.getGroup` surfaces server #97's
/// `GET /v1/mygroups/by_id/{username}/group/{group_id}` for member-side
/// single-group fetch.
///
/// The endpoint returns a group's info when the caller is a member of, or
/// has any join request against, that group. It returns `GROUP_NOT_FOUND`
/// (404) otherwise.
void main() {
  group('Issue 356: MyGroupsSource.getGroup', () {
    late SecureClient adminClient;
    late SecureClient memberClient;
    late SecureClient outsiderClient;

    const member = 'test_356_member';
    const outsider = 'test_356_outsider';
    const password = 'password123';
    const memberGroupName = 'test_356_member_group';
    const semiGroupName = 'test_356_semi_group';
    const otherGroupName = 'test_356_other_group';

    late int memberGroupId;
    late int semiGroupId;
    late int otherGroupId;

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      memberClient = await createRemoteSecureClient(baseUrl: baseUrl);
      outsiderClient = await createRemoteSecureClient(baseUrl: baseUrl);

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
        password: password,
        firstName: 'Member 356',
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: DateTime.utc(2012, 6, 15),
      );

      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: outsider,
        email: '$outsider@test.com',
        password: password,
        firstName: 'Outsider 356',
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: DateTime.utc(2012, 6, 15),
      );

      final memberGroup = await adminClient.groups.createGroup(
        name: memberGroupName,
      );
      memberGroupId = memberGroup.id;
      await adminClient.groups.addMember(memberGroupId, member);

      final semi = await adminClient.groups.createGroup(
        name: semiGroupName,
        dobOnOrAfterUtc: DateTime.utc(2010),
        dobOnOrBeforeUtc: DateTime.utc(2014),
        gender: Gender.male,
        semiAuto: true,
      );
      semiGroupId = semi.id;

      final other = await adminClient.groups.createGroup(name: otherGroupName);
      otherGroupId = other.id;

      await adminClient.auth.logout();

      await memberClient.auth.login(member, password);
      // Submit a join request against the semi-auto group so the member
      // has a non-membership relation to it as well.
      await memberClient.myGroups.joinGroup(member, semiGroupId);

      await outsiderClient.auth.login(outsider, password);
    });

    tearDownAll(() async {
      try {
        await memberClient.auth.logout();
      } on Exception {
        /* ignore */
      }
      try {
        await outsiderClient.auth.logout();
      } on Exception {
        /* ignore */
      }
    });

    test('Issue 356: member can fetch a group they belong to', () async {
      final group = await memberClient.myGroups.getGroup(member, memberGroupId);
      expect(group.id, memberGroupId);
      expect(group.name, memberGroupName);
    });

    test(
      'Issue 356: user with a pending join request can fetch the group',
      () async {
        final group = await memberClient.myGroups.getGroup(member, semiGroupId);
        expect(group.id, semiGroupId);
        expect(group.name, semiGroupName);
      },
    );

    test(
      'Issue 356: 404 GROUP_NOT_FOUND when caller has no relation to group',
      () async {
        expect(
          () => outsiderClient.myGroups.getGroup(outsider, otherGroupId),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having(
                  (e) => e.code,
                  'code',
                  SdkErrorCode.groupNotFound,
                ),
          ),
        );
      },
    );
  });
}
