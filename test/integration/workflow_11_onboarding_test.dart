import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Workflow 11: how every kind of account comes into being, on a stack with
/// identity verification on (`just test`) and one with it off
/// (`just test-modules`).
///
/// Accounts an admin creates never touch identity verification: they start
/// `pending` and an admin approves them, on either stack. Roles are a
/// separate admin action on an existing user, not a step of onboarding.
/// Self-registration is where the stacks differ: with verification on the
/// user waits at `registered` until they attach a document and submit, and
/// only then are admins asked; with it off they are `pending` at once.
void main() {
  group('Workflow 11: onboarding', () {
    late SecureClient admin;
    late bool verificationOn;
    final opened = <SecureClient>[];
    const password = 'password123';

    Future<SecureClient> loginAs(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(c);
      await c.auth.login(username, password);
      expect((await c.auth.getCurrentUser()).username, username);
      return c;
    }

    Future<UserPrivate> adminCreate(String username) => admin.users.createUser(
      username: username,
      email: '$username@test.com',
      passwordHash: password,
      firstName: username,
      lastName: 'Onboarding',
      phone: '0000000000',
      dateOfBirthUtc: DateTime.utc(1995, 6, 15),
      gender: Gender.female,
    );

    /// An admin-created account, approved, with [roles] assigned one by one.
    Future<UserInfo> staff(String username, List<String> roles) async {
      await adminCreate(username);
      var user = await admin.users.approveUser(username);
      for (final role in roles) {
        user = await admin.users.assignRole(username, role);
      }
      return user;
    }

    Future<UserInfo> register(String username) => admin.auth.register(
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000000',
      gender: Gender.male,
      dateOfBirthUtc: DateTime.utc(1995, 6, 15),
    );

    /// The highest notification id in the admin's inbox, so a case counts
    /// only the approval requests it caused.
    Future<int> inboxHighWater() async {
      final inbox = await admin.notifications.getNotifications(limit: 100);
      return inbox.items.fold<int>(0, (m, e) => e.id > m ? e.id : m);
    }

    Future<List<AppNotification>> approvalsFor(
      String username, {
      required int after,
    }) async {
      final inbox = await admin.notifications.getNotifications(limit: 100);
      return inbox.items
          .where(
            (e) =>
                e.id > after &&
                e.pendingActionType == PendingActionType.userApproval &&
                e.pendingActionKey == username,
          )
          .toList();
    }

    Matcher refusedWith(int status) => throwsA(
      isA<ServerException>().having((e) => e.statusCode, 'status', status),
    );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(admin);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      verificationOn = (await stackCapabilities(admin)).identityVerification;
    });

    tearDownAll(() async {
      for (final c in opened) {
        try {
          await c.auth.logout();
        } on Exception {
          /* already out, or never active */
        }
      }
    });

    group('11.01: accounts an admin creates', () {
      test('start pending and ask no admin for approval', () async {
        final before = await inboxHighWater();
        final user = await adminCreate('test_w11_created');
        expect(user.status, UserStatus.pending);
        final readback = await admin.users.getUserPrivate(user.username);
        expect(readback.status, UserStatus.pending);
        expect(await approvalsFor(user.username, after: before), isEmpty);
      });

      test('are approved with no identity document, whatever the stack '
          'requires of self-registration', () async {
        await adminCreate('test_w11_nodoc');
        final approved = await admin.users.approveUser('test_w11_nodoc');
        expect(approved.status, UserStatus.active);
        final readback = await admin.users.getUserPrivate('test_w11_nodoc');
        expect(readback.status, UserStatus.active);
      });
    });

    group('11.02: roles', () {
      test('admin1 is an admin and not a coach', () async {
        await staff('test_w11_admin1', ['admin']);
        final readback = await admin.users.getUserInfo('test_w11_admin1');
        expect(readback.status, UserStatus.active);
        expect(readback.roles.isAdmin, isTrue);
        expect(readback.roles.isCoach, isFalse);
      });

      test('admin1 can approve a pending user', () async {
        final admin1 = await loginAs('test_w11_admin1');
        await adminCreate('test_w11_by_admin1');
        final approved = await admin1.users.approveUser('test_w11_by_admin1');
        expect(approved.status, UserStatus.active);
      });

      test('coach1 is a coach and not an admin', () async {
        await staff('test_w11_coach1', ['coach']);
        final readback = await admin.users.getUserInfo('test_w11_coach1');
        expect(readback.status, UserStatus.active);
        expect(readback.roles.isCoach, isTrue);
        expect(readback.roles.isAdmin, isFalse);
      });

      test('coach1 cannot approve a user', () async {
        final coach1 = await loginAs('test_w11_coach1');
        await adminCreate('test_w11_by_coach1');
        await expectLater(
          coach1.users.approveUser('test_w11_by_coach1'),
          refusedWith(403),
        );
        final readback = await admin.users.getUserPrivate('test_w11_by_coach1');
        expect(readback.status, UserStatus.pending);
      });

      test('admincoach1 holds both roles', () async {
        await staff('test_w11_admincoach1', ['admin', 'coach']);
        final readback = await admin.users.getUserInfo('test_w11_admincoach1');
        expect(readback.status, UserStatus.active);
        expect(readback.roles.isAdmin, isTrue);
        expect(readback.roles.isCoach, isTrue);
        final self = await loginAs('test_w11_admincoach1');
        final me = await self.auth.getCurrentUser();
        expect(me.roles.isAdmin, isTrue);
        expect(me.roles.isCoach, isTrue);
      });

      test('user0 is active with no role and cannot approve', () async {
        await staff('test_w11_user0', []);
        final readback = await admin.users.getUserInfo('test_w11_user0');
        expect(readback.status, UserStatus.active);
        expect(readback.roles.isAdmin, isFalse);
        expect(readback.roles.isCoach, isFalse);
        final user0 = await loginAs('test_w11_user0');
        await adminCreate('test_w11_by_user0');
        await expectLater(
          user0.users.approveUser('test_w11_by_user0'),
          refusedWith(403),
        );
      });
    });

    group('11.03: self-registration with verification on', () {
      test('user1 waits at registered, and no admin is asked', () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final before = await inboxHighWater();
        final user = await register('test_w11_user1');
        expect(user.status, UserStatus.registered);
        final self = await loginAs('test_w11_user1');
        expect(
          (await self.auth.getCurrentUser()).status,
          UserStatus.registered,
        );
        expect(await approvalsFor('test_w11_user1', after: before), isEmpty);
      });

      test('user1 cannot be approved before submitting', () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        await expectLater(
          admin.users.approveUser('test_w11_user1'),
          refusedWith(422),
        );
        final readback = await admin.users.getUserPrivate('test_w11_user1');
        expect(readback.status, UserStatus.registered);
      });

      test('user2 uploading a document alone asks no admin', () async {
        if (skipUnless(
          enabled: verificationOn,
          module: 'identity verification',
        )) {
          return;
        }
        final before = await inboxHighWater();
        await register('test_w11_user2');
        final self = await loginAs('test_w11_user2');
        await attachIdentityDocument(self, 'test_w11_user2');
        expect(
          (await self.auth.getCurrentUser()).status,
          UserStatus.registered,
        );
        expect(await approvalsFor('test_w11_user2', after: before), isEmpty);
      });

      test(
        'user2 submitting asks the admins once, and is then approved',
        () async {
          if (skipUnless(
            enabled: verificationOn,
            module: 'identity verification',
          )) {
            return;
          }
          final before = await inboxHighWater();
          final self = await loginAs('test_w11_user2');
          final submitted = await self.users.submitForReview();
          expect(submitted.status, UserStatus.pending);
          expect(
            await approvalsFor('test_w11_user2', after: before),
            hasLength(1),
          );

          final approved = await admin.users.approveUser('test_w11_user2');
          expect(approved.status, UserStatus.active);
          final readback = await admin.users.getUserPrivate('test_w11_user2');
          expect(readback.status, UserStatus.active);
        },
      );
    });

    group('11.04: self-registration with verification off', () {
      test('user3 is pending at once and the admins are asked once', () async {
        if (skipIf(enabled: verificationOn, feature: 'identity verification')) {
          return;
        }
        final before = await inboxHighWater();
        final user = await register('test_w11_user3');
        expect(user.status, UserStatus.pending);
        expect(
          await approvalsFor('test_w11_user3', after: before),
          hasLength(1),
        );
      });

      test('user3 is approved with no document', () async {
        if (skipIf(enabled: verificationOn, feature: 'identity verification')) {
          return;
        }
        final approved = await admin.users.approveUser('test_w11_user3');
        expect(approved.status, UserStatus.active);
        final readback = await admin.users.getUserPrivate('test_w11_user3');
        expect(readback.status, UserStatus.active);
      });
    });
  });
}
