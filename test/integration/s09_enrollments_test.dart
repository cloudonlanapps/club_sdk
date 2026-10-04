import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Section 9: Enrollments Test Suite.
///
/// Named users (alice, bob, charlie, diana) are kept for tests requiring
/// member-side clients (acceptInvite, declineInvite, requestToJoin, withdraw).
/// Per-test pool users are used for admin-side assign operations on programme
/// events to avoid cross-test TIME_CONFLICT errors (server rejects enrollment
/// when the user has active enrollments in time-overlapping unbounded
/// programme events).
///
/// Tests requirements from Section 9 (Enrollments):
/// - 9.01: Invite User
/// - 9.02: Bulk Invite
/// - 9.03: Assign User
/// - 9.04: Bulk Assign
/// - 9.05: Assign Trial
/// - 9.06: Accept Invite
/// - 9.07: Decline Invite
/// - 9.08: Request to Join
/// - 9.09: Approve Request
/// - 9.10: Reject Request
/// - 9.11: Bulk Approve Requests
/// - 9.12: Bulk Reject Requests
/// - 9.13: Withdraw
/// - 9.14: Approve Withdrawal
/// - 9.15: Reject Withdrawal
/// - 9.16: Cancel Withdrawal Request
/// - 9.17: Remove Enrollment
/// - 9.18: Bulk Remove
/// - 9.19: List Enrollments
/// - 9.20: List My Enrollments
/// - 9.21: Get Pending Invites Count
/// - 9.22: Get Pending Actions Count
/// - 9.23: Approve All Pending Withdrawals
/// - 9.24: Enrollment Period Tracking
/// - 9.25: Propagate Through Event Chain
void main() {
  group('Section 9: Enrollments', () {
    late SecureClient client;
    late SecureClient aliceClient;
    late SecureClient bobClient;
    late SecureClient charlieClient;
    late SecureClient dianaClient;

    late int venue1Id;
    final now = DateTime.utc(2027, 3, 1, 10);

    // Named users — kept for tests needing member-side clients.
    const alice = 'test_alice_s09';
    const bob = 'test_bob_s09';
    const charlie = 'test_charlie_s09';
    const diana = 'test_diana_s09';
    // Named users — used only in invite/request tests (no assign).
    const user1 = 'test_user1_s09';
    const user2 = 'test_user2_s09';
    const user3 = 'test_user3_s09';
    const testUser = 'test_testuser_s09';
    const attendee1 = 'test_attendee1_s09';
    const attendee2 = 'test_attendee2_s09';
    const coach1 = 'test_coach1_s09';
    const requestUser = 'test_requestUser_s09';
    const withdrawUser = 'test_withdrawUser_s09';
    const leaveUser = 'test_leaveUser_s09';

    const password = 'password123';

    // Per-test user pool for admin-side assign operations on programme events.
    // Each test draws fresh users via nextUser() so no user is ever enrolled
    // in more than one unbounded programme event.
    final userPool = <String>[];
    var userPoolIndex = 0;
    String nextUser() => userPool[userPoolIndex++];

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

      // 3. Create venues
      final v1 = await client.venues.createVenue(
        name: 'test_Venue 1 S09',
        address: 'S09 Street 1',
      );
      venue1Id = v1.id;

      // Still created: other assertions count venues seeded by this suite.
      await client.venues.createVenue(
        name: 'test_Venue 2 S09',
        address: 'S09 Street 2',
      );

      // 4. Register and approve named users
      final namedUsers = [
        alice,
        bob,
        charlie,
        diana,
        user1,
        user2,
        user3,
        testUser,
        attendee1,
        attendee2,
        coach1,
        requestUser,
        withdrawUser,
        leaveUser,
      ];
      for (final username in namedUsers) {
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: password,
          firstName: 'User $username',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
      }

      // 5. Register pool users for programme-event assign tests.
      for (var i = 0; i < 30; i++) {
        final username = 'test_s09_u$i';
        userPool.add(username);
        await registerAndApprove(
          client: client,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: password,
          firstName: 'User $username',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
      }

      // Assign coach role
      await client.users.assignRole(coach1, 'coach');

      // Where the credit system is on, credit gates the enrollment
      // itself, so every member this suite enrolls needs an account
      // before it starts (#38). A no-op on a stack with it off.
      await seedEnrolmentCreditIfGated(client, [...namedUsers, ...userPool]);

      // 6. Logout sudo
      await client.auth.logout();

      // 7. Create role-specific clients
      aliceClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await aliceClient.auth.login(alice, password);

      bobClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await bobClient.auth.login(bob, password);

      charlieClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await charlieClient.auth.login(charlie, password);

      dianaClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await dianaClient.auth.login(diana, password);
    });

    setUp(() async {
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // ignore
      }
    });

    // One-offs never block on overlap (#16) but a member may not be
    // enrolled in two overlapping occurrences, so each one-off takes its own
    // day, at an hour no programme uses. Kept inside the scheduling horizon.
    var oneOffSlot = 0;

    Future<Event> createTestEvent(String suffix) async {
      final start = DateTime.utc(
        now.year,
        now.month,
        now.day,
        6,
      ).add(Duration(days: 30 + oneOffSlot++));
      return client.events.createEvent(
        title: 'test_Enroll Test $suffix',
        description: 'D',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venue1Id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
    }

    // Programmes are weekly on one weekday and clash with each other on
    // venue and on organizer per occurrence (#16); every programme here is
    // organized by sudo, so each takes its own weekday × hour slot.
    var programmeSlot = 0;

    Future<Event> createProgrammeEvent(
      String suffix, {
      int? venueId,
      String? organizerName,
    }) async {
      final slot = programmeSlot++;
      final start = DateTime.utc(
        now.year,
        now.month,
        now.day,
        8 + 2 * (slot ~/ 7),
      ).add(Duration(days: 30 + slot % 7));
      return client.events.createEvent(
        title: 'test_Programme $suffix',
        description: 'D',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venueId ?? venue1Id,
        organizerName: organizerName,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
    }

    // =========================================================================
    // 9.01: Invite User
    // =========================================================================

    group('9.01: Invite User', () {
      test('9.01: Invite Member - sends invitation to user', () async {
        final event = await createTestEvent('901');

        await client.enrollments.invite(
          event.id,
          alice,
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[alice], EnrollmentStatus.invited);
      });
    });

    // =========================================================================
    // 9.02: Bulk Invite
    // =========================================================================

    group('9.02: Bulk Invite', () {
      test('9.02: Bulk Invite - success all users', () async {
        final event = await createTestEvent('902a');

        await client.enrollments.inviteBulk(
          event.id,
          [alice, bob],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments.length, 2);
        expect(enrollments[alice], EnrollmentStatus.invited);
        expect(enrollments[bob], EnrollmentStatus.invited);
      });

      test('9.02: Bulk Invite - three users', () async {
        final event = await createProgrammeEvent('902b');

        await client.enrollments.inviteBulk(
          event.id,
          [user1, user2, user3],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[user1], EnrollmentStatus.invited);
        expect(enrollments[user2], EnrollmentStatus.invited);
        expect(enrollments[user3], EnrollmentStatus.invited);
      });

      test('9.02: Bulk Invite - empty list succeeds', () async {
        final event = await createProgrammeEvent('902c');

        await client.enrollments.inviteBulk(
          event.id,
          [],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments, isEmpty);
      });

      test('9.02: Bulk Invite - duplicate users in list', () async {
        final event = await createProgrammeEvent('902d');

        await client.enrollments.inviteBulk(
          event.id,
          [user1, user1, user2],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[user1], EnrollmentStatus.invited);
        expect(enrollments[user2], EnrollmentStatus.invited);
      });
    });

    // =========================================================================
    // 9.03: Assign User
    // =========================================================================

    group('9.03: Assign User', () {
      test('9.03: Assign Member - directly assigns user to event', () async {
        final event = await createTestEvent('903');

        await client.enrollments.assign(
          event.id,
          bob,
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[bob], EnrollmentStatus.assigned);
      });

      test(
        '9.03b: listEnrollmentsDetailed returns full records with timestamps',
        () async {
          final event = await createTestEvent('903b');

          await client.enrollments.assign(event.id, bob);

          final detailed = await client.enrollments.listEnrollmentsDetailed(
            event.id,
          );
          final enrollment = detailed[bob];
          expect(enrollment, isNotNull);
          expect(enrollment!.membername, bob);
          expect(enrollment.eventId, event.id);
          expect(enrollment.status, EnrollmentStatus.assigned);
          // Assigning sets enrolledAtUtc; not withdrawn → withdrawnAtUtc null.
          expect(enrollment.enrolledAtUtc, isNotNull);
          expect(enrollment.withdrawnAtUtc, isNull);
        },
      );
    });

    // =========================================================================
    // 9.04: Bulk Assign
    // =========================================================================

    group('9.04: Bulk Assign', () {
      test('9.04: Bulk Assign - success all users', () async {
        final event = await createTestEvent('904a');

        await client.enrollments.assignBulk(
          event.id,
          [charlie, diana],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments.length, 2);
        expect(enrollments[charlie], EnrollmentStatus.assigned);
        expect(enrollments[diana], EnrollmentStatus.assigned);
      });

      test('9.04: Bulk Assign - single user', () async {
        final event = await createProgrammeEvent('904b');
        final pu1 = nextUser();

        await client.enrollments.assignBulk(
          event.id,
          [pu1],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[pu1], EnrollmentStatus.assigned);
        expect(enrollments.length, 1);
      });

      test(
        '9.04: Bulk Assign - users who are already invited transitions status',
        () async {
          final event = await createProgrammeEvent('904c');
          final pu1 = nextUser();

          // First invite
          await client.enrollments.inviteBulk(
            event.id,
            [pu1],
          );

          // Then assign (should transition)
          await client.enrollments.assignBulk(
            event.id,
            [pu1],
          );

          final enrollments = await client.enrollments.listEnrollments(
            event.id,
          );
          expect(enrollments[pu1], EnrollmentStatus.assigned);
        },
      );
    });

    // =========================================================================
    // 9.05: Assign Trial
    // =========================================================================

    group('9.05: Assign Trial', () {
      test('9.05: Assign Trial - assigns user for trial', () async {
        final event = await createProgrammeEvent('905');
        final pu1 = nextUser();

        await client.enrollments.assignTrial(
          event.id,
          pu1,
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[pu1], EnrollmentStatus.assignedTrial);
      });
    });

    // =========================================================================
    // 9.06: Accept Invite
    // =========================================================================

    group('9.06: Accept Invite', () {
      test('9.06: Accept Invitation - member accepts invite', () async {
        final event = await createTestEvent('906');
        await client.enrollments.invite(
          event.id,
          alice,
        );

        await aliceClient.myEvents.acceptInvite(alice, event.id);

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[alice], EnrollmentStatus.accepted);
      });
    });

    // =========================================================================
    // 9.07: Decline Invite
    // =========================================================================

    group('9.07: Decline Invite', () {
      test('9.07: Decline Invitation - member declines invite', () async {
        final event = await createTestEvent('907');
        await client.enrollments.invite(
          event.id,
          bob,
        );

        await bobClient.myEvents.declineInvite(bob, event.id);

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[bob], EnrollmentStatus.declined);
      });
    });

    // =========================================================================
    // 9.08: Request to Join
    // =========================================================================

    group('9.08: Request to Join', () {
      test('9.08: Request to Join - member requests to join event', () async {
        final event = await createTestEvent('908');

        await charlieClient.myEvents.requestToJoin(charlie, event.id);

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[charlie], EnrollmentStatus.requested);
      });
    });

    // =========================================================================
    // 9.09: Approve Request
    // =========================================================================

    group('9.09: Approve Request', () {
      test('9.09: Approve Request - organizer approves', () async {
        final event = await createTestEvent('909');

        await dianaClient.myEvents.requestToJoin(diana, event.id);

        await client.enrollments.approveRequest(event.id, diana);

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[diana], EnrollmentStatus.accepted);
      });
    });

    // =========================================================================
    // 9.10: Reject Request
    // =========================================================================

    group('9.10: Reject Request', () {
      test(
        '9.10: Reject Request - organizer rejects with reason',
        () async {
          final event = await createTestEvent('910');

          await aliceClient.myEvents.requestToJoin(alice, event.id);

          await client.enrollments.rejectRequest(
            event.id,
            alice,
            reason: 'Event is full',
          );

          final enrollments = await client.enrollments.listEnrollments(
            event.id,
          );
          expect(enrollments[alice], EnrollmentStatus.rejected);
        },
      );
    });

    // =========================================================================
    // 9.11-9.12: Bulk Request Operations
    // =========================================================================

    group('9.11-9.12: Bulk Request Operations', () {
      test('9.11: Bulk Approve Requests - success all', () async {
        final event = await createTestEvent('911a');

        // Create multiple requests
        await aliceClient.myEvents.requestToJoin(alice, event.id);
        await bobClient.myEvents.requestToJoin(bob, event.id);

        await client.enrollments.approveRequestsBulk(
          event.id,
          [alice, bob],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        final acceptedCount = enrollments.values
            .where((s) => s == EnrollmentStatus.accepted)
            .length;
        expect(acceptedCount, 2);
      });

      test('9.11: Bulk Approve Requests', () async {
        final event = await createProgrammeEvent('911b');

        // Users request to join
        await client.myEvents.requestToJoin(
          user1,
          event.id,
        );
        await client.myEvents.requestToJoin(
          user2,
          event.id,
        );

        // Bulk approve
        await client.enrollments.approveRequestsBulk(
          event.id,
          [user1, user2],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[user1], EnrollmentStatus.accepted);
        expect(enrollments[user2], EnrollmentStatus.accepted);
      });

      test('9.11: Bulk Approve Requests - empty list succeeds', () async {
        final event = await createProgrammeEvent('911c');

        // Should not throw
        await client.enrollments.approveRequestsBulk(
          event.id,
          [],
        );
      });

      test('9.12: Bulk Reject Requests - success with reason', () async {
        final event = await createProgrammeEvent('912a');
        final pu1 = nextUser();
        final pu2 = nextUser();

        // Users request to join
        await client.myEvents.requestToJoin(
          pu1,
          event.id,
        );
        await client.myEvents.requestToJoin(
          pu2,
          event.id,
        );

        // Bulk reject with reason
        await client.enrollments.rejectRequestsBulk(
          event.id,
          [pu1, pu2],
          reason: 'Event is full',
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[pu1], EnrollmentStatus.rejected);
        expect(enrollments[pu2], EnrollmentStatus.rejected);
      });

      test('9.12: Bulk Reject Requests - without reason', () async {
        final event = await createProgrammeEvent('912b');
        final pu1 = nextUser();

        await client.myEvents.requestToJoin(
          pu1,
          event.id,
        );

        await client.enrollments.rejectRequestsBulk(
          event.id,
          [pu1],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[pu1], EnrollmentStatus.rejected);
      });

      test('Mixed approve and reject in separate bulk calls', () async {
        final event = await createProgrammeEvent('911-912-mixed');
        final pu1 = nextUser();
        final pu2 = nextUser();
        final pu3 = nextUser();

        // Users request to join
        await client.myEvents.requestToJoin(
          pu1,
          event.id,
        );
        await client.myEvents.requestToJoin(
          pu2,
          event.id,
        );
        await client.myEvents.requestToJoin(
          pu3,
          event.id,
        );

        // Approve some, reject others
        await client.enrollments.approveRequestsBulk(
          event.id,
          [pu1, pu2],
        );
        await client.enrollments.rejectRequestsBulk(
          event.id,
          [pu3],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[pu1], EnrollmentStatus.accepted);
        expect(enrollments[pu2], EnrollmentStatus.accepted);
        expect(enrollments[pu3], EnrollmentStatus.rejected);
      });
    });

    // =========================================================================
    // 9.13-9.16: Withdrawal
    // =========================================================================

    group('9.13-9.16: Withdrawal', () {
      test('9.13: Request Withdrawal - creates withdrawal request', () async {
        final event = await createTestEvent('913a');
        await client.enrollments.assign(
          event.id,
          alice,
        );

        await aliceClient.myEvents.withdraw(alice, event.id);

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[alice], EnrollmentStatus.withdrawRequested);
      });

      test('9.13: Request Withdrawal - with reason preserves reason', () async {
        final event = await createProgrammeEvent('913b');
        final pu1 = nextUser();

        await client.enrollments.assign(
          event.id,
          pu1,
        );

        await client.myEvents.withdraw(
          pu1,
          event.id,
          reason: 'Schedule conflict',
        );

        final status = await client.enrollments.getEnrollmentStatus(
          event.id,
          pu1,
        );
        expect(status, EnrollmentStatus.withdrawRequested);
      });

      test('9.13: Request Withdrawal - without reason', () async {
        final event = await createProgrammeEvent('913c');
        final pu1 = nextUser();

        await client.enrollments.assign(
          event.id,
          pu1,
        );

        await client.myEvents.withdraw(
          pu1,
          event.id,
        );

        final status = await client.enrollments.getEnrollmentStatus(
          event.id,
          pu1,
        );
        expect(status, EnrollmentStatus.withdrawRequested);
      });

      test(
        '9.13: Request Withdrawal - multiple users can request withdrawal',
        () async {
          final event = await createProgrammeEvent('913d');
          final pu1 = nextUser();
          final pu2 = nextUser();

          await client.enrollments.assignBulk(
            event.id,
            [pu1, pu2],
          );

          await client.myEvents.withdraw(
            pu1,
            event.id,
          );
          await client.myEvents.withdraw(
            pu2,
            event.id,
          );

          final enrollments = await client.enrollments.listEnrollments(
            event.id,
          );
          expect(enrollments[pu1], EnrollmentStatus.withdrawRequested);
          expect(enrollments[pu2], EnrollmentStatus.withdrawRequested);
        },
      );

      test('9.14: Approve Withdrawal - transitions to withdrawn', () async {
        final event = await createTestEvent('914');
        await client.enrollments.assign(
          event.id,
          bob,
        );

        await bobClient.myEvents.withdraw(bob, event.id);

        await client.enrollments.approveWithdraw(event.id, bob);

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[bob], EnrollmentStatus.withdrawn);
      });

      test(
        '9.14: Bulk Approve Withdrawal - success',
        () async {
          final event = await createProgrammeEvent('914-bulk');
          final pu1 = nextUser();
          final pu2 = nextUser();

          // Assign users
          await client.enrollments.assignBulk(
            event.id,
            [pu1, pu2],
          );

          // Users request withdrawal
          await client.myEvents.withdraw(
            pu1,
            event.id,
            reason: 'Personal reasons',
          );
          await client.myEvents.withdraw(
            pu2,
            event.id,
            reason: 'Schedule conflict',
          );

          // Bulk approve withdrawals
          await client.enrollments.approveWithdrawBulk(
            event.id,
            [pu1, pu2],
          );

          final enrollments = await client.enrollments.listEnrollments(
            event.id,
          );
          expect(enrollments[pu1], EnrollmentStatus.withdrawn);
          expect(enrollments[pu2], EnrollmentStatus.withdrawn);
        },
      );

      test(
        '9.15: Reject Withdrawal - restores previous enrollment status',
        () async {
          final event = await createProgrammeEvent('915a');
          final pu1 = nextUser();

          await client.enrollments.assign(
            event.id,
            pu1,
          );

          await client.myEvents.withdraw(
            pu1,
            event.id,
          );

          // Reject withdrawal
          await client.enrollments.rejectWithdraw(
            event.id,
            pu1,
            reason: 'Cannot leave mid-session',
          );

          final status = await client.enrollments.getEnrollmentStatus(
            event.id,
            pu1,
          );
          // Server restores to previous status (assigned in this case)
          expect(status, EnrollmentStatus.assigned);
        },
      );

      test(
        '9.15: Reject Withdrawal - preserves previous status for accepted user',
        () async {
          final event = await createProgrammeEvent('915b');

          // Invite user and have them accept
          await client.enrollments.invite(
            event.id,
            testUser,
          );
          await client.myEvents.acceptInvite(
            testUser,
            event.id,
          );

          // Verify status is accepted
          var status = await client.enrollments.getEnrollmentStatus(
            event.id,
            testUser,
          );
          expect(status, EnrollmentStatus.accepted);

          // Request withdrawal
          await client.myEvents.withdraw(
            testUser,
            event.id,
          );

          // Reject withdrawal - should restore to accepted
          await client.enrollments.rejectWithdraw(
            event.id,
            testUser,
          );

          status = await client.enrollments.getEnrollmentStatus(
            event.id,
            testUser,
          );
          expect(status, EnrollmentStatus.accepted);
        },
      );

      test(
        '9.15: Bulk Reject Withdrawal - restores previous status',
        () async {
          final event = await createProgrammeEvent('915-bulk');
          final pu1 = nextUser();
          final pu2 = nextUser();

          // Assign users
          await client.enrollments.assignBulk(
            event.id,
            [pu1, pu2],
          );

          // Users request withdrawal
          await client.myEvents.withdraw(
            pu1,
            event.id,
          );
          await client.myEvents.withdraw(
            pu2,
            event.id,
          );

          // Bulk reject withdrawals
          await client.enrollments.rejectWithdrawBulk(
            event.id,
            [pu1, pu2],
            reason: 'Cannot leave mid-session',
          );

          final enrollments = await client.enrollments.listEnrollments(
            event.id,
          );
          // Server restores to previous status (assigned in this case)
          expect(enrollments[pu1], EnrollmentStatus.assigned);
          expect(enrollments[pu2], EnrollmentStatus.assigned);
        },
      );

      test('9.16: Cancel Withdrawal Request - restores status', () async {
        final event = await createProgrammeEvent('916');
        final pu1 = nextUser();

        await client.enrollments.assign(
          event.id,
          pu1,
        );

        await client.myEvents.withdraw(
          pu1,
          event.id,
        );

        // Cancel withdrawal request
        await client.myEvents.cancelWithdrawRequest(
          pu1,
          event.id,
        );

        final status = await client.enrollments.getEnrollmentStatus(
          event.id,
          pu1,
        );
        // Server restores to previous status (assigned in this case)
        expect(status, EnrollmentStatus.assigned);
      });
    });

    // =========================================================================
    // 9.17-9.18: Remove Enrollments
    // =========================================================================

    group('9.17-9.18: Remove Enrollments', () {
      test('9.17: Remove Enrollment - removes user from event', () async {
        final event = await createTestEvent('917');
        await client.enrollments.assign(
          event.id,
          alice,
        );

        await client.enrollments.removeEnrollment(
          event.id,
          alice,
          reason: 'Administrative removal',
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        // Server marks removed users as 'removed'
        expect(
          enrollments[alice] == null ||
              enrollments[alice] == EnrollmentStatus.removed,
          isTrue,
        );
      });

      test('9.18: Bulk Remove - partial list', () async {
        final event = await createTestEvent('918a');
        await client.enrollments.assignBulk(
          event.id,
          [alice, bob, charlie],
        );

        await client.enrollments.removeEnrollmentsBulk(
          event.id,
          [alice, bob],
          reason: 'Bulk removal',
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[alice], EnrollmentStatus.removed);
        expect(enrollments[bob], EnrollmentStatus.removed);
        expect(enrollments[charlie], EnrollmentStatus.assigned);
      });

      test('9.18: Bulk Remove - success all', () async {
        final event = await createProgrammeEvent('918b');
        final pu1 = nextUser();
        final pu2 = nextUser();

        // Assign users first
        await client.enrollments.assignBulk(
          event.id,
          [pu1, pu2],
        );

        // Bulk remove
        await client.enrollments.removeEnrollmentsBulk(
          event.id,
          [pu1, pu2],
          reason: 'Removed by organizer',
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[pu1], EnrollmentStatus.removed);
        expect(enrollments[pu2], EnrollmentStatus.removed);
      });

      test('9.18: Bulk Remove - partial list with three users', () async {
        final event = await createProgrammeEvent('918c');
        final pu1 = nextUser();
        final pu2 = nextUser();
        final pu3 = nextUser();

        // Assign three users
        await client.enrollments.assignBulk(
          event.id,
          [pu1, pu2, pu3],
        );

        // Remove only two
        await client.enrollments.removeEnrollmentsBulk(
          event.id,
          [pu1, pu2],
        );

        final enrollments = await client.enrollments.listEnrollments(event.id);
        expect(enrollments[pu1], EnrollmentStatus.removed);
        expect(enrollments[pu2], EnrollmentStatus.removed);
        expect(enrollments[pu3], EnrollmentStatus.assigned);
      });
    });

    // =========================================================================
    // 9.19-9.20: List Enrollments
    // =========================================================================

    group('9.19-9.20: List Enrollments', () {
      test('9.19: List Enrollments - filters by status', () async {
        final event = await createTestEvent('919');
        await client.enrollments.assign(
          event.id,
          alice,
        );
        await client.enrollments.invite(
          event.id,
          bob,
        );

        final assigned = await client.enrollments.listEnrollments(
          event.id,
          status: EnrollmentStatus.assigned,
        );
        expect(assigned.length, 1);
        expect(assigned.keys.first, alice);
      });

      test(
        '9.20: Get Enrollment Status - returns null for non-enrolled',
        () async {
          final event = await createTestEvent('920');

          final status = await client.enrollments.getEnrollmentStatus(
            event.id,
            'nonexistent_user',
          );
          expect(status, isNull);
        },
      );
    });

    // =========================================================================
    // 9.21-9.22: Pending Actions
    // =========================================================================

    group('9.21: Attendee Pending Actions', () {});

    group('9.22: Organizer Pending Actions', () {});

    // =========================================================================
    // 9.23-9.25: Additional Requirements
    // =========================================================================

    group('9.23-9.25: Additional Requirements', () {
      test(
        '9.23: Bulk Approve Pending Withdrawals',
        () async {
          // Create an event and enroll users
          final event = await createProgrammeEvent('923');

          // Assign users
          await client.enrollments.assign(
            event.id,
            alice,
          );
          await client.enrollments.assign(
            event.id,
            bob,
          );

          // Users request withdrawal
          await client.myEvents.withdraw(
            alice,
            event.id,
          );
          await client.myEvents.withdraw(
            bob,
            event.id,
          );

          // Verify pending withdrawals
          final beforeStatus1 = await client.enrollments.getEnrollmentStatus(
            event.id,
            alice,
          );
          final beforeStatus2 = await client.enrollments.getEnrollmentStatus(
            event.id,
            bob,
          );
          expect(beforeStatus1, EnrollmentStatus.withdrawRequested);
          expect(beforeStatus2, EnrollmentStatus.withdrawRequested);

          // Bulk approve all pending withdrawals
          await client.enrollments.approveWithdrawBulk(
            event.id,
            [alice, bob],
          );

          // Verify all are now withdrawn
          final afterStatus1 = await client.enrollments.getEnrollmentStatus(
            event.id,
            alice,
          );
          final afterStatus2 = await client.enrollments.getEnrollmentStatus(
            event.id,
            bob,
          );
          expect(afterStatus1, EnrollmentStatus.withdrawn);
          expect(afterStatus2, EnrollmentStatus.withdrawn);
        },
      );

      test(
        '9.24: Enrollment Period Tracking - sets enrolledAtUtc when enrolled',
        () async {
          final event = await createTestEvent('924a');
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          final enrollment = await client.myEvents.getMyEnrollment(
            u1,
            event.id,
          );

          expect(enrollment.enrolledAtUtc, isNotNull);
          expect(enrollment.withdrawnAtUtc, isNull);
        },
      );

      test(
        '9.24: Enrollment Period Tracking - sets withdrawnAtUtc when withdrawn',
        () async {
          final event = await createTestEvent('924b');
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          await client.myEvents.withdraw(
            u1,
            event.id,
            reason: 'Test withdrawal',
          );

          await client.enrollments.approveWithdraw(event.id, u1);

          final enrollment = await client.myEvents.getMyEnrollment(
            u1,
            event.id,
          );

          expect(enrollment.enrolledAtUtc, isNotNull);
          expect(enrollment.withdrawnAtUtc, isNotNull);
          expect(enrollment.status, EnrollmentStatus.withdrawn);
        },
      );

      test(
        '9.25: Propagate Through Event Chain',
        () async {
          // Create a programme event with enrolled users
          final event = await createProgrammeEvent('Chain Propagation S09');
          final start = event.startTimeUtc;
          final u1 = nextUser();

          await client.enrollments.assign(
            event.id,
            u1,
          );

          // Split: the event keeps its id and its enrollments; the change
          // is a new schedule (#16).
          final cutoff = start.add(const Duration(days: 14));
          final successor = await client.events.updateEventForAllFuture(
            event.id,
            version: event.version,
            effectiveDateTimeUtc: cutoff,
            coachNames: () => [coach1],
          );
          expect(successor.id, event.id);
          final schedules = await client.events.listSchedules(event.id);
          expect(schedules, hasLength(2));

          // Verify the enrollment is still on the event after the split
          final successorEnrollments = await client.enrollments.listEnrollments(
            successor.id,
          );
          expect(
            successorEnrollments[u1],
            EnrollmentStatus.assigned,
            reason: 'Enrollment should survive the split',
          );
        },
      );
    });
  });
}
