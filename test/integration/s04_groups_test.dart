import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 4: Groups Test Suite.
///
/// Tests requirements from Section 4 (Groups):
/// - 4.01: Create Group
/// - 4.02: Update Group
/// - 4.03: Delete Group
/// - 4.04: List Groups
/// - 4.05: Get Group by ID
/// - 4.06: Add User to Group
/// - 4.07: Remove User from Group
/// - 4.08: List Group Members
/// - 4.09: Get My Groups
/// - 4.10: Bulk Add to Group
///
/// GroupSource coverage:
/// - [`x`] getGroups
/// - [`x`] getGroup
/// - [`x`] createGroup
/// - [`x`] updateGroup
/// - [`x`] deleteGroup
/// - [`x`] addMember
/// - [`x`] removeMember
/// - [`x`] getMembers
/// - [`x`] getMyGroups
/// - [`x`] addMembersBulk
/// - [ ] getDeletedGroups (covered in s02)
/// - [ ] restoreGroup (covered in s02)
/// - [ ] hardDeleteGroup (covered in s02)
void main() {
  group('Section 4: Groups', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean all test_ artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to seed test data
      await client.auth.login(sudoUsername, sudoPassword);

      // 3. Create users needed by group member tests
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_alice_s04',
        email: 'test_alice_s04@test.com',
        password: 'password123',
        firstName: 'Alice S04',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_bob_s04',
        email: 'test_bob_s04@test.com',
        password: 'password123',
        firstName: 'Bob S04',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_charlie_s04',
        email: 'test_charlie_s04@test.com',
        password: 'password123',
        firstName: 'Charlie S04',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // Users with specific DOB and gender for auto group tests.
      // boy1: male, DOB 2014-06-15
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_boy1_s04',
        email: 'test_boy1_s04@test.com',
        password: 'password123',
        firstName: 'Boy One',
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: DateTime.utc(2014, 6, 15),
      );

      // boy2: male, DOB 2018-03-01
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_boy2_s04',
        email: 'test_boy2_s04@test.com',
        password: 'password123',
        firstName: 'Boy Two',
        phone: '0000000000',
        gender: Gender.male,
        // ignore: but explicit DOB makes intent clearer
        dateOfBirthUtc: DateTime.utc(2018, 3, 1),
      );

      // girl1: female, DOB 2013-09-01
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_girl1_s04',
        email: 'test_girl1_s04@test.com',
        password: 'password123',
        firstName: 'Girl One',
        phone: '0000000000',
        gender: Gender.female,
        // ignore: but explicit DOB makes intent clearer
        dateOfBirthUtc: DateTime.utc(2013, 9, 1),
      );

      // adult: male, DOB 2000-01-01
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_adult_s04',
        email: 'test_adult_s04@test.com',
        password: 'password123',
        firstName: 'Adult One',
        phone: '0000000000',
        gender: Gender.male,
        // ignore: but explicit DOB makes intent clearer
        dateOfBirthUtc: DateTime.utc(2000, 1, 1),
      );

      // coach: adult male, DOB 1990-01-01, role coach.
      // Used to verify staff exemption from NOT_ELIGIBLE.
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_coach_s04',
        email: 'test_coach_s04@test.com',
        password: 'password123',
        firstName: 'Coach One',
        phone: '0000000000',
        gender: Gender.male,
        // Explicit DOB makes intent clearer.
        dateOfBirthUtc: DateTime.utc(1990, 1, 1),
      );
      await client.users.assignRole('test_coach_s04', 'coach');

      // 4. Logout sudo
      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // Not logged in — ignore
      }
    });

    group('4.01: Create Group', () {
      test('creates new group', () async {
        final group = await client.groups.createGroup(
          name: 'test_New Group 401',
          description: 'New description',
        );

        expect(group.id, isPositive);
        expect(group.name, 'test_New Group 401');
        expect(group.description, 'New description');

        // Double-verify via query
        final fetched = await client.groups.getGroup(group.id);
        expect(fetched.name, 'test_New Group 401');
      });
    });

    group('4.02: Update Group', () {
      test('modifies group name and description', () async {
        final created = await client.groups.createGroup(
          name: 'test_Original Name 402',
        );

        final updated = await client.groups.updateGroup(
          created.id,
          name: 'test_Updated Name 402',
          description: () => 'New description',
        );

        expect(updated.name, 'test_Updated Name 402');
        expect(updated.description, 'New description');

        // Double-verify via query
        final fetched = await client.groups.getGroup(created.id);
        expect(fetched.name, 'test_Updated Name 402');
        expect(fetched.description, 'New description');
      });
    });

    group('4.03: Delete Group', () {
      test('soft deletes group', () async {
        final created = await client.groups.createGroup(
          name: 'test_Delete Group 403',
        );

        await client.groups.deleteGroup(created.id);

        // Verify absent from active list
        final activeGroups = await client.groups.getGroups(limit: 100);
        expect(
          activeGroups.items.any((g) => g.id == created.id),
          isFalse,
        );

        // Verify present in deleted list
        final deletedGroups = await client.groups.getDeletedGroups();
        expect(
          deletedGroups.items.any((g) => g.id == created.id),
          isTrue,
        );
      });
    });

    group('4.04: List Groups', () {
      test('getGroups with pagination', () async {
        await client.groups.createGroup(name: 'test_Group 404a');
        await client.groups.createGroup(name: 'test_Group 404b');

        final page1 = await client.groups.getGroups(limit: 1);
        expect(page1.items.length, 1);

        final page2 = await client.groups.getGroups(limit: 1, offset: 1);
        expect(page2.items.length, greaterThanOrEqualTo(0));

        if (page2.items.isNotEmpty) {
          expect(page1.items.first.id, isNot(page2.items.first.id));
        }
      });
    });

    group('4.05: Get Group by ID', () {
      test('returns group by ID', () async {
        final created = await client.groups.createGroup(
          name: 'test_Test Group 405',
          description: 'Description 405',
        );

        final fetched = await client.groups.getGroup(created.id);
        expect(fetched.id, created.id);
        expect(fetched.name, 'test_Test Group 405');
        expect(fetched.description, 'Description 405');
      });

      test('throws for non-existent group', () async {
        expect(
          () => client.groups.getGroup(999999),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('4.06: Add User to Group', () {
      test('adds user to group', () async {
        final group = await client.groups.createGroup(
          name: 'test_Member Group 406',
        );

        await client.groups.addMember(group.id, 'test_alice_s04');

        final members = await client.groups.getMembers(group.id);
        expect(
          members.any((m) => m.membername == 'test_alice_s04'),
          isTrue,
        );
      });
    });

    group('4.07: Remove User from Group', () {
      test('removes user from group', () async {
        final group = await client.groups.createGroup(
          name: 'test_Member Group 407',
        );
        await client.groups.addMember(group.id, 'test_bob_s04');

        await client.groups.removeMember(group.id, 'test_bob_s04');

        final members = await client.groups.getMembers(group.id);
        expect(
          members.any((m) => m.membername == 'test_bob_s04'),
          isFalse,
        );
      });
    });

    group('4.08: List Group Members', () {
      test('returns all members of a group', () async {
        final group = await client.groups.createGroup(
          name: 'test_Member Group 408',
        );
        await client.groups.addMember(group.id, 'test_alice_s04');
        await client.groups.addMember(group.id, 'test_bob_s04');
        await client.groups.addMember(group.id, 'test_charlie_s04');

        final members = await client.groups.getMembers(group.id);
        expect(members.length, 3);
        expect(
          members.any((m) => m.membername == 'test_alice_s04'),
          isTrue,
        );
        expect(
          members.any((m) => m.membername == 'test_bob_s04'),
          isTrue,
        );
        expect(
          members.any((m) => m.membername == 'test_charlie_s04'),
          isTrue,
        );
      });
    });

    group('4.09: Get My Groups', () {
      test('returns groups user belongs to', () async {
        final group = await client.groups.createGroup(
          name: 'test_My Groups Test 409',
        );
        await client.groups.addMember(group.id, 'test_alice_s04');

        final myGroups = await client.groups.getMyGroups('test_alice_s04');
        expect(myGroups.any((g) => g.id == group.id), isTrue);
      });
    });

    group('4.10: Bulk Add to Group', () {
      test('adds multiple users and returns categorized result', () async {
        final group = await client.groups.createGroup(
          name: 'test_Bulk Add Group 410',
        );

        final result = await client.groups.addMembersBulk(
          group.id,
          ['test_alice_s04', 'test_bob_s04', 'test_charlie_s04'],
        );

        expect(
          result.added,
          containsAll(['test_alice_s04', 'test_bob_s04', 'test_charlie_s04']),
        );
        expect(result.alreadyMembers, isEmpty);
        expect(result.notFound, isEmpty);

        final members = await client.groups.getMembers(group.id);
        expect(members.length, 3);
        expect(
          members.any((m) => m.membername == 'test_alice_s04'),
          isTrue,
        );
        expect(
          members.any((m) => m.membername == 'test_bob_s04'),
          isTrue,
        );
        expect(
          members.any((m) => m.membername == 'test_charlie_s04'),
          isTrue,
        );
      });
    });

    // =========================================================================
    // 4.11: Auto Group Behavior
    // =========================================================================

    group('4.11: Auto Group Behavior', () {
      final dobAfter = DateTime.utc(2010);
      final dobBefore = DateTime.utc(2018, 12, 31);

      test('creating group with dobOnOrAfterUtc makes it auto', () async {
        final group = await client.groups.createGroup(
          name: 'test_Auto Age Group 411a',
          dobOnOrAfterUtc: dobAfter,
          dobOnOrBeforeUtc: dobBefore,
        );
        expect(group.kind, GroupKind.auto);
        expect(group.dobOnOrAfterUtc, dobAfter);
        expect(group.dobOnOrBeforeUtc, dobBefore);
      });

      test('creating group with gender makes it auto', () async {
        final group = await client.groups.createGroup(
          name: 'test_Auto Gender Group 411b',
          gender: Gender.male,
        );
        expect(group.kind, GroupKind.auto);
      });

      test('creating group without criteria is manual', () async {
        final group = await client.groups.createGroup(
          name: 'test_Manual Group 411c',
        );
        expect(group.kind, GroupKind.manual);
      });

      test(
        'creating group with criteria + semiAuto:true is semi_auto',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_SemiAuto Group 411i',
            dobOnOrAfterUtc: dobAfter,
            dobOnOrBeforeUtc: dobBefore,
            semiAuto: true,
          );
          expect(group.kind, GroupKind.semiAuto);
        },
      );

      test('creating group with criteria + semiAuto:false is auto', () async {
        final group = await client.groups.createGroup(
          name: 'test_Auto Explicit 411j',
          dobOnOrAfterUtc: dobAfter,
          dobOnOrBeforeUtc: dobBefore,
          semiAuto: false,
        );
        expect(group.kind, GroupKind.auto);
      });

      test(
        'creating group without criteria + semiAuto:true stays manual',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_Manual SemiAuto 411k',
            semiAuto: true,
          );
          expect(group.kind, GroupKind.manual);
        },
      );

      test(
        'updateGroup with semiAuto:true flips auto group to semi_auto',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_Flip Auto To Semi 411l',
            dobOnOrAfterUtc: dobAfter,
            dobOnOrBeforeUtc: dobBefore,
          );
          expect(group.kind, GroupKind.auto);

          final flipped = await client.groups.updateGroup(
            group.id,
            semiAuto: true,
          );
          expect(flipped.kind, GroupKind.semiAuto);

          final flippedBack = await client.groups.updateGroup(
            group.id,
            semiAuto: false,
          );
          expect(flippedBack.kind, GroupKind.auto);
        },
      );

      test('addMember to auto group throws', () async {
        final group = await client.groups.createGroup(
          name: 'test_Auto No Add 411d',
          dobOnOrAfterUtc: dobAfter,
        );

        expect(
          () => client.groups.addMember(group.id, 'test_alice_s04'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.autoGroupModificationNotAllowed,
            ),
          ),
        );
      });

      test('removeMember from auto group throws', () async {
        final group = await client.groups.createGroup(
          name: 'test_Auto No Remove 411e',
          gender: Gender.female,
        );

        expect(
          () => client.groups.removeMember(group.id, 'test_alice_s04'),
          throwsA(isA<ServerException>()),
        );
      });

      test(
        'server rejects manual -> auto conversion when members exist',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_Guard Manual 411f',
          );
          await client.groups.addMember(group.id, 'test_alice_s04');

          expect(
            () => client.groups.updateGroup(
              group.id,
              dobOnOrAfterUtc: () => dobAfter,
            ),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.membersExist,
              ),
            ),
          );
        },
      );

      test('SDK allows setting criteria on empty manual group', () async {
        final group = await client.groups.createGroup(
          name: 'test_Empty Manual 411g',
        );

        final updated = await client.groups.updateGroup(
          group.id,
          dobOnOrAfterUtc: () => dobAfter,
          dobOnOrBeforeUtc: () => dobBefore,
        );
        expect(updated.kind, GroupKind.auto);
        expect(updated.dobOnOrAfterUtc, dobAfter);
        expect(updated.dobOnOrBeforeUtc, dobBefore);
      });
    });

    // =========================================================================
    // 4.12: Auto Group Membership Queries
    // =========================================================================
    //
    // Users seeded in setUpAll:
    //   test_boy1_s04:  male,   DOB 2014-06-15
    //   test_boy2_s04:  male,   DOB 2018-03-01
    //   test_girl1_s04: female, DOB 2013-09-01
    //   test_adult_s04: male,   DOB 2000-01-01

    group('4.12: Auto Group Membership Queries', () {
      test('gender-only group returns matching gender', () async {
        final group = await client.groups.createGroup(
          name: 'test_Males 412a',
          gender: Gender.male,
        );

        final members = await client.groups.getMembers(group.id);
        final usernames = members.map((m) => m.membername).toList();

        expect(usernames, contains('test_boy1_s04'));
        expect(usernames, contains('test_boy2_s04'));
        expect(usernames, contains('test_adult_s04'));
        expect(usernames, isNot(contains('test_girl1_s04')));
      });

      test('DOB-only group returns members within DOB bounds', () async {
        final group = await client.groups.createGroup(
          name: 'test_Youth 2013-2018 412b',
          dobOnOrAfterUtc: DateTime.utc(2013),
          dobOnOrBeforeUtc: DateTime.utc(2018, 12, 31),
        );

        final members = await client.groups.getMembers(group.id);
        final usernames = members.map((m) => m.membername).toList();

        // boy1 (2014-06-15), boy2 (2018-03-01) and girl1 (2013-09-01) match
        expect(usernames, contains('test_boy1_s04'));
        expect(usernames, contains('test_boy2_s04'));
        expect(usernames, contains('test_girl1_s04'));
        // adult (2000-01-01) is outside the DOB range
        expect(usernames, isNot(contains('test_adult_s04')));
      });

      test('gender + DOB group returns intersection', () async {
        final group = await client.groups.createGroup(
          name: 'test_Boys 2014 412c',
          gender: Gender.male,
          dobOnOrAfterUtc: DateTime.utc(2014),
          dobOnOrBeforeUtc: DateTime.utc(2014, 12, 31),
        );

        final members = await client.groups.getMembers(group.id);
        final usernames = members.map((m) => m.membername).toList();

        // Only boy1 (male, born 2014-06-15) matches
        expect(usernames, contains('test_boy1_s04'));
        expect(usernames, isNot(contains('test_boy2_s04')));
        expect(usernames, isNot(contains('test_girl1_s04')));
        expect(usernames, isNot(contains('test_adult_s04')));
      });

      test(
        'dobOnOrAfter only matches members born on or after the bound',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_DOB After 2014 412d',
            dobOnOrAfterUtc: DateTime.utc(2014),
          );

          final members = await client.groups.getMembers(group.id);
          final usernames = members.map((m) => m.membername).toList();

          // boy1 (2014-06-15) and boy2 (2018-03-01) match
          expect(usernames, contains('test_boy1_s04'));
          expect(usernames, contains('test_boy2_s04'));
          // girl1 (2013-09-01) and adult (2000-01-01) are too old
          expect(usernames, isNot(contains('test_girl1_s04')));
          expect(usernames, isNot(contains('test_adult_s04')));
        },
      );
    });

    // =========================================================================
    // 4.13: Validation & authorization rules (issue #12)
    // =========================================================================

    group('4.13: Validation & authorization rules', () {
      test('manual -> semi_auto conversion with offending members returns '
          'MEMBERS_INELIGIBLE with membernames in details', () async {
        final group = await client.groups.createGroup(
          name: 'test_Semi Convert Block 413a',
        );
        // adult (DOB 2000) does NOT match a youth criteria.
        await client.groups.addMember(group.id, 'test_adult_s04');

        try {
          await client.groups.updateGroup(
            group.id,
            dobOnOrAfterUtc: () => DateTime.utc(2010),
            dobOnOrBeforeUtc: () => DateTime.utc(2018, 12, 31),
            semiAuto: true,
          );
          fail('Expected ServerException MEMBERS_INELIGIBLE');
        } on ServerException catch (e) {
          expect(e.statusCode, 422);
          expect(e.code, SdkErrorCode.membersIneligible);
          expect(e.details, isNotNull);
          final names = e.details!['membernames'];
          expect(names, isA<List<dynamic>>());
          expect(names as List, contains('test_adult_s04'));
        }
      });

      test(
        'direct add of ineligible non-staff to semi_auto -> NOT_ELIGIBLE',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_Semi Ineligible 413b',
            dobOnOrAfterUtc: DateTime.utc(2010),
            dobOnOrBeforeUtc: DateTime.utc(2018, 12, 31),
            semiAuto: true,
          );

          expect(
            () => client.groups.addMember(group.id, 'test_adult_s04'),
            throwsA(
              isA<ServerException>().having(
                (e) => e.code,
                'code',
                SdkErrorCode.notEligible,
              ),
            ),
          );
        },
      );

      test(
        'staff (coach) exempt from NOT_ELIGIBLE on semi_auto direct add',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_Semi Staff Exempt 413c',
            dobOnOrAfterUtc: DateTime.utc(2010),
            dobOnOrBeforeUtc: DateTime.utc(2018, 12, 31),
            semiAuto: true,
          );

          // Coach (born 1990) does NOT match the youth criteria, but is staff.
          await client.groups.addMember(group.id, 'test_coach_s04');

          final members = await client.groups.getMembers(group.id);
          expect(
            members.any((m) => m.membername == 'test_coach_s04'),
            isTrue,
          );
        },
      );

      test(
        'bulk add to semi_auto populates notEligible for ineligible users',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_Bulk Semi 413d',
            dobOnOrAfterUtc: DateTime.utc(2010),
            dobOnOrBeforeUtc: DateTime.utc(2018, 12, 31),
            semiAuto: true,
          );

          final result = await client.groups.addMembersBulk(
            group.id,
            [
              'test_boy1_s04', // matches criteria
              'test_adult_s04', // fails criteria — should land in notEligible
              // unknown user — should land in notFound
              'test_does_not_exist_s04',
            ],
          );

          expect(result.added, contains('test_boy1_s04'));
          expect(result.notEligible, contains('test_adult_s04'));
          expect(result.notFound, contains('test_does_not_exist_s04'));
          expect(result.alreadyMembers, isEmpty);

          // Double-verify via members listing.
          final members = await client.groups.getMembers(group.id);
          final usernames = members.map((m) => m.membername).toList();
          expect(usernames, contains('test_boy1_s04'));
          expect(usernames, isNot(contains('test_adult_s04')));
        },
      );

      test('direct add of super-admin returns 404 USER_NOT_FOUND', () async {
        final group = await client.groups.createGroup(
          name: 'test_SuperAdmin Direct 413e',
        );

        expect(
          () => client.groups.addMember(group.id, sudoUsername),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having((e) => e.code, 'code', SdkErrorCode.userNotFound),
          ),
        );
      });

      test('bulk add containing super-admin lists them in notFound', () async {
        final group = await client.groups.createGroup(
          name: 'test_SuperAdmin Bulk 413f',
        );

        final result = await client.groups.addMembersBulk(
          group.id,
          [sudoUsername, 'test_alice_s04'],
        );

        expect(result.notFound, contains(sudoUsername));
        expect(result.added, contains('test_alice_s04'));
      });

      test(
        'hardDeleteGroup on non-soft-deleted group returns NOT_DELETED',
        () async {
          final group = await client.groups.createGroup(
            name: 'test_Hard Not Deleted 413g',
          );

          expect(
            () => client.groups.hardDeleteGroup(group.id),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'statusCode', 422)
                  .having((e) => e.code, 'code', SdkErrorCode.notDeleted),
            ),
          );
        },
      );
    });
  });
}
