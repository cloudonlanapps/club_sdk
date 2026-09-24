import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 2: User Management Test Suite.
///
/// Tests requirements from Section 2 (User Management):
/// - 2.01: Create User
/// - 2.02: Update User Status
/// - 2.03: Assign Roles
/// - 2.04: Transfer Super Admin
/// - 2.05: List Users
/// - 2.06: Get User by ID
/// - 2.07: Get User by Username
/// - 2.08: Update Own Profile
/// - 2.09: Update User Profile (Admin)
/// - 2.10: Set Privacy Preference
/// - 2.11: Set Nickname
/// - 2.12: Search Users
/// - 2.13: Get Users by Status
/// - 2.14: Get Users by Role
/// - 2.15: Get Public Profile
/// - 2.16: Deactivate User
/// - 2.17: Approve User
/// - 2.18: Block User
/// - 2.19: Super Admin Protection
/// - 2.20: Hard Delete Data
/// - 2.21: Config Recovery
/// - 2.22: Get Deleted Users
///
/// Cross-entity soft-delete / restore / hard-delete:
/// - 2.23: Venue Delete Lifecycle
/// - 2.24: Group Delete Lifecycle
/// - 2.25: Event Delete Lifecycle
void main() {
  group('Section 2: User Management', () {
    late SecureClient client;
    late SecureClient adminClient;
    late int sharedVenueId;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      // 1. Clean all test_ artifacts
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      // 2. Login as sudo to seed shared data
      await client.auth.login(sudoUsername, sudoPassword);

      // 3. Seed shared users needed by list/search/filter tests
      // test_alice — active user with coach role (for search, role filter)
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_alice',
        email: 'test_alice@test.com',
        password: 'password123',
        firstName: 'Alice Smith',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_alice', 'coach');

      // test_bob — active member (for list/status filter tests)
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_bob',
        email: 'test_bob@test.com',
        password: 'password123',
        firstName: 'Bob Jones',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // test_admin_s02 — admin user for hard-delete permission tests
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_admin_s02',
        email: 'test_admin_s02@test.com',
        password: 'password123',
        firstName: 'Admin S02',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await client.users.assignRole('test_admin_s02', 'admin');

      // Shared venue (needed for event creation in delete lifecycle tests)
      final venue = await client.venues.createVenue(
        name: 'test_venue_s02',
        address: '123 Test St',
      );
      sharedVenueId = venue.id;

      // 4. Logout sudo
      await client.auth.logout();

      // 5. Create persistent admin client for permission tests
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await adminClient.auth.login('test_admin_s02', 'password123');
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

    group('2.01: Create User', () {
      test('creates user with required fields', () async {
        final user = await client.users.createUser(
          username: 'test_new_user_201',
          email: 'test_newuser_201@test.com',
          passwordHash: 'hash123',
          firstName: 'New',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        expect(user.username, 'test_new_user_201');
        expect(user.email, 'test_newuser_201@test.com');
        expect(user.status, UserStatus.pending);

        // Double-verify via query
        final fetched = await client.users.getUserPrivate('test_new_user_201');
        expect(fetched.username, 'test_new_user_201');
        expect(fetched.firstName, 'New');
        expect(fetched.lastName, 'User');
      });
    });

    group('2.02: Update User Status', () {
      test('unblockUser unblocks blocked user', () async {
        await client.users.createUser(
          username: 'test_unblock_user_202',
          email: 'test_unblockuser_202@test.com',
          passwordHash: 'hash123',
          firstName: 'Unblock',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.approveUser('test_unblock_user_202');
        await client.users.blockUser('test_unblock_user_202');

        final unblocked = await client.users.unblockUser(
          'test_unblock_user_202',
        );
        expect(unblocked.status, UserStatus.active);
      });

      test('reactivateUser reactivates left user', () async {
        await client.users.createUser(
          username: 'test_reactivate_user_202',
          email: 'test_reactivateuser_202@test.com',
          passwordHash: 'hash123',
          firstName: 'Reactivate',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.approveUser('test_reactivate_user_202');
        await client.users.markLeft('test_reactivate_user_202');

        final reactivated = await client.users.reactivateUser(
          'test_reactivate_user_202',
        );
        expect(reactivated.status, UserStatus.active);
      });
    });

    group('2.03: Assign Roles', () {
      test('assignRole adds role to user', () async {
        await client.users.createUser(
          username: 'test_role_user_203a',
          email: 'test_roleuser_203a@test.com',
          passwordHash: 'hash123',
          firstName: 'Role',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.approveUser('test_role_user_203a');

        final updated = await client.users.assignRole(
          'test_role_user_203a',
          'coach',
        );
        expect(updated.roles.isCoach, isTrue);

        // Double-verify via query
        final fetched = await client.users.getUserInfo('test_role_user_203a');
        expect(fetched.roles.isCoach, isTrue);
      });

      test('removeRole removes role from user', () async {
        await client.users.createUser(
          username: 'test_role_user_203b',
          email: 'test_roleuser_203b@test.com',
          passwordHash: 'hash123',
          firstName: 'Role',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.approveUser('test_role_user_203b');
        await client.users.assignRole('test_role_user_203b', 'coach');

        final updated = await client.users.removeRole(
          'test_role_user_203b',
          'coach',
        );
        expect(updated.roles.isCoach, isFalse);

        // Double-verify via query
        final fetched = await client.users.getUserInfo('test_role_user_203b');
        expect(fetched.roles.isCoach, isFalse);
      });
    });

    group('2.04: Transfer Super Admin', () {
      test('transfers super admin role', () async {
        // Register with known password so we can login as this user later
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: 'test_new_super_204',
          email: 'test_newsuper_204@test.com',
          password: 'password123',
          firstName: 'New Super Admin',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.assignRole('test_new_super_204', 'admin');

        final newSuperAdmin = await client.users.transferSuperAdmin(
          'test_new_super_204',
        );
        expect(newSuperAdmin.isSuperAdmin, isTrue);

        // Transfer back to sudo so later tests are not affected
        await client.auth.login('test_new_super_204', 'password123');
        final currentUser = await client.auth.getCurrentUser();
        expect(currentUser.isSuperAdmin, isTrue);

        final restored = await client.users.transferSuperAdmin(sudoUsername);
        expect(restored.isSuperAdmin, isTrue);

        // Log back in as sudo
        await client.auth.login(sudoUsername, sudoPassword);
      });
    });

    group('2.05: List Users', () {
      test('getUsers returns paginated list', () async {
        final page1 = await client.users.getUsers(limit: 5);
        expect(page1.items.length, lessThanOrEqualTo(5));
        expect(page1.items, isNotEmpty);

        if (page1.items.length == 5) {
          final page2 = await client.users.getUsers(limit: 5, offset: 5);
          final page1Ids = page1.items.map((u) => u.username).toSet();
          final page2Ids = page2.items.map((u) => u.username).toSet();
          expect(page1Ids.intersection(page2Ids).isEmpty, isTrue);
        }
      });
    });

    group('2.06: Get User by ID', () {
      test('getUserPrivate returns private profile', () async {
        final user = await client.users.getUserPrivate('test_alice');
        expect(user.username, 'test_alice');
        expect(user.email, isNotNull);
      });
    });

    group('2.07: Get User by Username', () {
      test('returns user profile for existing user', () async {
        final user = await client.users.getUserPrivate('test_alice');
        expect(user.username, 'test_alice');
      });

      test('throws ServerException for non-existent user', () async {
        expect(
          () => client.users.getUserPrivate('test_nonexistent_user_207'),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('2.08: Update Own Profile', () {
      test('updateUser modifies profile fields', () async {
        await client.users.createUser(
          username: 'test_update_user_208',
          email: 'test_updateuser_208@test.com',
          passwordHash: 'hash123',
          firstName: 'Update',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        final updated = await client.users.updateUser(
          'test_update_user_208',
          firstName: () => 'Updated',
          lastName: () => 'Name',
          bio: () => 'New bio',
        );

        expect(updated.firstName, 'Updated');
        expect(updated.lastName, 'Name');
        expect(updated.bio, 'New bio');

        // Double-verify via query
        final fetched = await client.users.getUserPrivate(
          'test_update_user_208',
        );
        expect(fetched.firstName, 'Updated');
        expect(fetched.bio, 'New bio');
      });
    });

    group('2.09: Update User Profile (Admin)', () {
      test('admin can update any user profile', () async {
        await client.users.createUser(
          username: 'test_admin_update_209',
          email: 'test_adminupdate_209@test.com',
          passwordHash: 'hash123',
          firstName: 'Admin Update',
          lastName: 'Target',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        final updated = await client.users.updateUser(
          'test_admin_update_209',
          firstName: () => 'Admin Changed',
          lastName: () => 'Target Updated',
          phone: () => '+1234567890',
        );

        expect(updated.firstName, 'Admin Changed');
        expect(updated.lastName, 'Target Updated');
        expect(updated.phone, '+1234567890');
      });
    });

    group('2.10: Set Privacy Preference', () {
      test('toggles useNamePublicly', () async {
        await client.users.createUser(
          username: 'test_privacy_user_210',
          email: 'test_privacyuser_210@test.com',
          passwordHash: 'hash123',
          firstName: 'Privacy',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        final updated = await client.users.updateUser(
          'test_privacy_user_210',
          useNamePublicly: false,
        );
        expect(updated.useNamePublicly, isFalse);

        final updated2 = await client.users.updateUser(
          'test_privacy_user_210',
          useNamePublicly: true,
        );
        expect(updated2.useNamePublicly, isTrue);
      });
    });

    group('2.11: Set Nickname', () {
      test('sets and clears nickname', () async {
        await client.users.createUser(
          username: 'test_nickname_user_211',
          email: 'test_nicknameuser_211@test.com',
          passwordHash: 'hash123',
          firstName: 'Nickname',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        final updated = await client.users.updateUser(
          'test_nickname_user_211',
          nickname: () => 'NickName Pro',
          useNamePublicly: false,
        );
        expect(updated.nickname, 'NickName Pro');
        expect(updated.useNamePublicly, isFalse);

        // Clear nickname
        final updated2 = await client.users.updateUser(
          'test_nickname_user_211',
          nickname: () => null,
        );
        expect(updated2.nickname, isNull);
      });
    });

    group('2.12: Search Users', () {
      test('search by term finds matching user', () async {
        final results = await client.users.getUsers(searchTerm: 'Alice');
        expect(results.items.any((u) => u.username == 'test_alice'), isTrue);
      });
    });

    group('2.13: Get Users by Status', () {
      test('filter by active status returns only active users', () async {
        final activeUsers = await client.users.getUsers(
          status: UserStatus.active,
        );
        expect(activeUsers.items, isNotEmpty);
        for (final user in activeUsers.items) {
          expect(user.status, UserStatus.active);
        }
      });
    });

    group('2.14: Get Users by Role', () {
      test('filter by coach role returns only coaches', () async {
        final coaches = await client.users.getUsers(role: 'coach');
        expect(coaches.items, isNotEmpty);
        for (final user in coaches.items) {
          expect(user.roles.isCoach, isTrue);
        }
      });
    });

    group('2.15: Get Public Profile', () {
      test('getUserInfo returns public profile', () async {
        final user = await client.users.getUserInfo('test_alice');
        expect(user.username, 'test_alice');
        expect(user.status, UserStatus.active);
      });
    });

    group('2.16: Deactivate User', () {
      test('deleteUser soft deletes user', () async {
        await client.users.createUser(
          username: 'test_delete_user_216',
          email: 'test_deleteuser_216@test.com',
          passwordHash: 'hash123',
          firstName: 'Delete',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.approveUser('test_delete_user_216');

        await client.users.deleteUser('test_delete_user_216');

        // Verify user appears in deleted users list
        final deletedUsers = await client.users.getDeletedUsers();
        expect(
          deletedUsers.items.any(
            (u) => u.username == 'test_delete_user_216',
          ),
          isTrue,
        );

        // Verify user no longer appears in active users list
        final activeUsers = await client.users.getUsers(
          status: UserStatus.active,
          searchTerm: 'test_delete_user_216',
        );
        expect(
          activeUsers.items.any(
            (u) => u.username == 'test_delete_user_216',
          ),
          isFalse,
        );
      });

      test(
        'restoreUser restores soft-deleted user to previous status',
        () async {
          await client.users.createUser(
            username: 'test_restore_user_216',
            email: 'test_restoreuser_216@test.com',
            passwordHash: 'hash123',
            firstName: 'Restore',
            lastName: 'User',
            phone: '0000000000',
            dateOfBirthUtc: DateTime.utc(2000),
            gender: Gender.male,
          );
          await client.users.approveUser('test_restore_user_216');
          await client.users.deleteUser('test_restore_user_216');

          // Confirm user is in deleted list before restore
          final deletedBefore = await client.users.getDeletedUsers();
          expect(
            deletedBefore.items.any(
              (u) => u.username == 'test_restore_user_216',
            ),
            isTrue,
          );

          final restored = await client.users.restoreUser(
            'test_restore_user_216',
          );
          expect(restored.username, 'test_restore_user_216');

          // Verify user is accessible via normal query
          final fetched = await client.users.getUserInfo(
            'test_restore_user_216',
          );
          expect(fetched.username, 'test_restore_user_216');

          // Verify user no longer appears in deleted list
          final deletedAfter = await client.users.getDeletedUsers();
          expect(
            deletedAfter.items.any(
              (u) => u.username == 'test_restore_user_216',
            ),
            isFalse,
          );
        },
      );

      test('markLeft marks user as left', () async {
        await client.users.createUser(
          username: 'test_left_user_216',
          email: 'test_leftuser_216@test.com',
          passwordHash: 'hash123',
          firstName: 'Left',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.approveUser('test_left_user_216');

        final left = await client.users.markLeft('test_left_user_216');
        expect(left.status, UserStatus.left);
      });
    });

    group('2.17: Approve User', () {
      test('transitions pending to active', () async {
        await client.users.createUser(
          username: 'test_approve_user_217',
          email: 'test_approveuser_217@test.com',
          passwordHash: 'hash123',
          firstName: 'Approve',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        final approved = await client.users.approveUser(
          'test_approve_user_217',
        );
        expect(approved.status, UserStatus.active);

        // Double-verify via query
        final fetched = await client.users.getUserInfo('test_approve_user_217');
        expect(fetched.status, UserStatus.active);
      });
    });

    group('2.18: Block User', () {
      test('blocks active user', () async {
        await client.users.createUser(
          username: 'test_block_user_218',
          email: 'test_blockuser_218@test.com',
          passwordHash: 'hash123',
          firstName: 'Block',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.approveUser('test_block_user_218');

        final blocked = await client.users.blockUser('test_block_user_218');
        expect(blocked.status, UserStatus.blocked);
      });
    });

    group('2.19: Super Admin Protection', () {
      test('cannot block super admin', () async {
        expect(
          () => client.users.blockUser(sudoUsername),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.superAdminProtection,
            ),
          ),
        );
      });

      test('cannot hard delete super admin', () async {
        expect(
          () => client.users.hardDeleteUser(sudoUsername),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.superAdminProtection,
            ),
          ),
        );
      });
    });

    group('2.20: Hard Delete Data', () {
      test('super admin can hard delete user', () async {
        await client.users.createUser(
          username: 'test_hard_delete_220',
          email: 'test_harddelete_220@test.com',
          passwordHash: 'hash123',
          firstName: 'Hard Delete',
          lastName: 'User',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );

        // Server requires soft-delete before hard-delete
        await client.users.deleteUser('test_hard_delete_220');
        await client.users.hardDeleteUser('test_hard_delete_220');

        expect(
          () => client.users.getUserPrivate('test_hard_delete_220'),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.userNotFound,
            ),
          ),
        );
      });
    });

    group('2.21: Config Recovery', () {
      test('detects config — getCurrentUser returns super admin', () async {
        final user = await client.auth.getCurrentUser();
        expect(user, isNotNull);
        expect(user.isSuperAdmin, isTrue);
      });
    });

    group('2.22: Get Deleted Users', () {
      test('getDeletedUsers lists soft-deleted users', () async {
        // Create and soft-delete a user
        await client.users.createUser(
          username: 'test_deleted_list_222',
          email: 'test_deletedlist_222@test.com',
          passwordHash: 'hash123',
          firstName: 'Deleted',
          lastName: 'ListUser',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        await client.users.deleteUser('test_deleted_list_222');

        // Query deleted users
        final deletedUsers = await client.users.getDeletedUsers();
        expect(deletedUsers.items, isNotEmpty);
        expect(
          deletedUsers.items.any(
            (u) => u.username == 'test_deleted_list_222',
          ),
          isTrue,
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // Cross-entity Delete Lifecycle Tests
    // ════════════════════════════════════════════════════════════════════════

    group('2.23: Venue Delete Lifecycle', () {
      test('soft delete removes venue from getVenues', () async {
        final venue = await client.venues.createVenue(
          name: 'test_venue_del_223',
          address: '100 Delete St',
        );

        await client.venues.deleteVenue(venue.id);

        // Verify absent from active list
        final activeVenues = await client.venues.getVenues(limit: 100);
        expect(
          activeVenues.items.any((v) => v.id == venue.id),
          isFalse,
        );

        // Verify present in deleted list
        final deletedVenues = await client.venues.getDeletedVenues();
        expect(
          deletedVenues.items.any((v) => v.id == venue.id),
          isTrue,
        );
      });

      test('restore returns venue to getVenues', () async {
        final venue = await client.venues.createVenue(
          name: 'test_venue_restore_223',
          address: '200 Restore Ave',
        );
        await client.venues.deleteVenue(venue.id);

        // Confirm in deleted list before restore
        final deletedBefore = await client.venues.getDeletedVenues();
        expect(
          deletedBefore.items.any((v) => v.id == venue.id),
          isTrue,
        );

        final restored = await client.venues.restoreVenue(venue.id);
        expect(restored.id, venue.id);
        expect(restored.name, 'test_venue_restore_223');

        // Verify back in active list
        final activeVenues = await client.venues.getVenues(limit: 100);
        expect(
          activeVenues.items.any((v) => v.id == venue.id),
          isTrue,
        );

        // Verify absent from deleted list
        final deletedAfter = await client.venues.getDeletedVenues();
        expect(
          deletedAfter.items.any((v) => v.id == venue.id),
          isFalse,
        );
      });

      test('super admin can hard delete venue', () async {
        final venue = await client.venues.createVenue(
          name: 'test_venue_hard_223',
          address: '300 Hard Delete Blvd',
        );
        await client.venues.deleteVenue(venue.id);
        await client.venues.hardDeleteVenue(venue.id);

        // Verify gone from both active and deleted lists
        final activeVenues = await client.venues.getVenues(limit: 100);
        expect(
          activeVenues.items.any((v) => v.id == venue.id),
          isFalse,
        );

        final deletedVenues = await client.venues.getDeletedVenues();
        expect(
          deletedVenues.items.any((v) => v.id == venue.id),
          isFalse,
        );
      });

      test('regular admin cannot hard delete venue', () async {
        final venue = await adminClient.venues.createVenue(
          name: 'test_venue_noperm_223',
          address: '400 No Perm Rd',
        );
        await adminClient.venues.deleteVenue(venue.id);

        expect(
          () => adminClient.venues.hardDeleteVenue(venue.id),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('2.24: Group Delete Lifecycle', () {
      test('soft delete removes group from getGroups', () async {
        final group = await client.groups.createGroup(
          name: 'test_group_del_224',
          description: 'Group for delete test',
        );

        await client.groups.deleteGroup(group.id);

        // Verify absent from active list
        final activeGroups = await client.groups.getGroups(limit: 100);
        expect(
          activeGroups.items.any((g) => g.id == group.id),
          isFalse,
        );

        // Verify present in deleted list
        final deletedGroups = await client.groups.getDeletedGroups();
        expect(
          deletedGroups.items.any((g) => g.id == group.id),
          isTrue,
        );
      });

      test('restore returns group to getGroups', () async {
        final group = await client.groups.createGroup(
          name: 'test_group_restore_224',
          description: 'Group for restore test',
        );
        await client.groups.deleteGroup(group.id);

        // Confirm in deleted list before restore
        final deletedBefore = await client.groups.getDeletedGroups();
        expect(
          deletedBefore.items.any((g) => g.id == group.id),
          isTrue,
        );

        final restored = await client.groups.restoreGroup(group.id);
        expect(restored.id, group.id);
        expect(restored.name, 'test_group_restore_224');

        // Verify back in active list
        final activeGroups = await client.groups.getGroups(limit: 100);
        expect(
          activeGroups.items.any((g) => g.id == group.id),
          isTrue,
        );

        // Verify absent from deleted list
        final deletedAfter = await client.groups.getDeletedGroups();
        expect(
          deletedAfter.items.any((g) => g.id == group.id),
          isFalse,
        );
      });

      test('super admin can hard delete group', () async {
        final group = await client.groups.createGroup(
          name: 'test_group_hard_224',
          description: 'Group for hard delete test',
        );
        await client.groups.deleteGroup(group.id);
        await client.groups.hardDeleteGroup(group.id);

        // Verify gone from both active and deleted lists
        final activeGroups = await client.groups.getGroups(limit: 100);
        expect(
          activeGroups.items.any((g) => g.id == group.id),
          isFalse,
        );

        final deletedGroups = await client.groups.getDeletedGroups();
        expect(
          deletedGroups.items.any((g) => g.id == group.id),
          isFalse,
        );
      });

      test('regular admin cannot hard delete group', () async {
        final group = await adminClient.groups.createGroup(
          name: 'test_group_noperm_224',
          description: 'Group for permission test',
        );
        await adminClient.groups.deleteGroup(group.id);

        expect(
          () => adminClient.groups.hardDeleteGroup(group.id),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('2.25: Event Delete Lifecycle', () {
      test('soft delete removes event from listEvents', () async {
        final event = await client.events.createEvent(
          title: 'test_event_del_225',
          description: 'Event for delete test',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: sharedVenueId,
          startTimeUtc: DateTime.now().add(const Duration(days: 30)),
          endTimeUtc: DateTime.now().add(const Duration(days: 30, hours: 2)),
        );

        await client.events.deleteEvent(event.id);

        // Verify absent from active list
        final activeEvents = await client.events.listEvents(
          limit: 100,
        );
        expect(
          activeEvents.items.any((e) => e.id == event.id),
          isFalse,
        );

        // Verify present in deleted list
        final deletedEvents = await client.events.listDeletedEvents(
          limit: 100,
        );
        expect(
          deletedEvents.any((e) => e.id == event.id),
          isTrue,
        );
      });

      test('restore returns event to listEvents', () async {
        final event = await client.events.createEvent(
          title: 'test_event_restore_225',
          description: 'Event for restore test',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: sharedVenueId,
          startTimeUtc: DateTime.now().add(const Duration(days: 31)),
          endTimeUtc: DateTime.now().add(const Duration(days: 31, hours: 2)),
        );
        await client.events.deleteEvent(event.id);

        // Confirm in deleted list before restore
        final deletedBefore = await client.events.listDeletedEvents(
          limit: 100,
        );
        expect(
          deletedBefore.any((e) => e.id == event.id),
          isTrue,
        );

        final restored = await client.events.restoreEvent(event.id);
        expect(restored.id, event.id);
        expect(restored.title, 'test_event_restore_225');

        // Verify back in active list
        final activeEvents = await client.events.listEvents(
          limit: 100,
        );
        expect(
          activeEvents.items.any((e) => e.id == event.id),
          isTrue,
        );

        // Verify absent from deleted list
        final deletedAfter = await client.events.listDeletedEvents(
          limit: 100,
        );
        expect(
          deletedAfter.any((e) => e.id == event.id),
          isFalse,
        );
      });

      test('super admin can hard delete event', () async {
        final event = await client.events.createEvent(
          title: 'test_event_hard_225',
          description: 'Event for hard delete test',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: sharedVenueId,
          startTimeUtc: DateTime.now().add(const Duration(days: 32)),
          endTimeUtc: DateTime.now().add(const Duration(days: 32, hours: 2)),
        );
        await client.events.deleteEvent(event.id);
        await client.events.hardDeleteEvent(event.id);

        // Verify gone from both active and deleted lists
        final activeEvents = await client.events.listEvents(
          limit: 100,
        );
        expect(
          activeEvents.items.any((e) => e.id == event.id),
          isFalse,
        );

        final deletedEvents = await client.events.listDeletedEvents(
          limit: 100,
        );
        expect(
          deletedEvents.any((e) => e.id == event.id),
          isFalse,
        );
      });

      test('regular admin cannot hard delete event', () async {
        final event = await adminClient.events.createEvent(
          title: 'test_event_noperm_225',
          description: 'Event for permission test',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: sharedVenueId,
          startTimeUtc: DateTime.now().add(const Duration(days: 33)),
          endTimeUtc: DateTime.now().add(const Duration(days: 33, hours: 2)),
        );
        await adminClient.events.deleteEvent(event.id);

        expect(
          () => adminClient.events.hardDeleteEvent(event.id),
          throwsA(isA<ServerException>()),
        );
      });
    });
  });
}
