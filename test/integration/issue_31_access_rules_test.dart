import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 31: access rules the server now enforces.
///
/// - An admin may not edit or soft-delete the super admin (403
///   `SUPER_ADMIN_PROTECTION`); the super admin still edits their own
///   profile, and ordinary members are edited and deleted as before.
/// - Accepting an invite, requesting to join, withdrawing and requesting
///   leave on a member's behalf is for the member, an admin, or the event's
///   organizer or assigned coaches. Any other coach gets 403. When staff act,
///   the audit log names the acting user.
/// - A refresh token is not an access token (401). Tokens issued before a
///   password change (self-service or admin reset) stop working, access and
///   refresh alike, and the SDK surfaces the 401 rather than looping.
/// - Changing a user's email to one another user holds is 409
///   `DUPLICATE_EMAIL`.
void main() {
  group('Issue 31: access rules', () {
    late SecureClient sudoClient; // the super admin
    late SecureClient adminClient; // a regular admin
    late SecureClient memberClient; // the member staff act for (section 3)
    late SecureClient organizerClient; // organizer of every section 3 event
    late SecureClient coachClient; // assigned coach on every section 3 event
    late SecureClient outsiderClient; // a coach linked to none of them

    const password = 'password123';
    const admin = 'test_i31_admin';
    const target = 'test_i31_target'; // edited and deleted by the admin
    const other = 'test_i31_other'; // holds the email that clashes
    const member = 'test_i31_member';
    const organizer = 'test_i31_organizer';
    const coach = 'test_i31_coach';
    const outsider = 'test_i31_outsider';
    const selfChanger = 'test_i31_selfchange';
    const resetUser = 'test_i31_reset';
    const tokenUser = 'test_i31_token';

    late int venueId;
    late int programmeId;
    late DateTime programmeStart;

    // Every one-off below lands on its own day, at an hour clear of the
    // programme's, so the member and the event staff never clash.
    var nextDay = 40;

    Future<void> register(String username, {String? role}) async {
      await registerAndApprove(
        client: sudoClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: 'User $username',
        phone: '0000000031',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.male,
      );
      if (role != null) await sudoClient.users.assignRole(username, role);
    }

    Future<SecureClient> loggedIn(String username, [String? pw]) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      await c.auth.login(username, pw ?? password);
      return c;
    }

    setUpAll(() async {
      sudoClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudoClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudoClient.auth.login(sudoUsername, sudoPassword);

      await register(admin, role: 'admin');
      await register(organizer, role: 'coach');
      await register(coach, role: 'coach');
      await register(outsider, role: 'coach');
      for (final u in [
        target,
        other,
        member,
        selfChanger,
        resetUser,
        tokenUser,
      ]) {
        await register(u);
      }

      venueId = (await sudoClient.venues.createVenue(
        name: 'test_i31_venue',
        address: '31 Rink Road',
      )).id;

      // Programme enrolment is credit-gated where that module is on.
      await seedEnrolmentCreditIfGated(sudoClient, [member]);

      // A weekly programme for the leave cases: each actor declares leave
      // for a different week.
      programmeStart = dayAt(30);
      programmeId = (await sudoClient.events.createEvent(
        title: 'test_i31_programme',
        description: 'leave on a member behalf',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: programmeStart,
        endTimeUtc: programmeStart.add(const Duration(hours: 1)),
        rrule: weeklyOn(programmeStart),
        organizerName: organizer,
        coachNames: [coach],
      )).id;
      await sudoClient.enrollments.assign(programmeId, member);

      adminClient = await loggedIn(admin);
      memberClient = await loggedIn(member);
      organizerClient = await loggedIn(organizer);
      coachClient = await loggedIn(coach);
      outsiderClient = await loggedIn(outsider);
    });

    tearDownAll(() async {
      for (final c in [
        adminClient,
        memberClient,
        organizerClient,
        coachClient,
        outsiderClient,
        sudoClient,
      ]) {
        try {
          await c.auth.logout();
        } on Exception {
          // already logged out or token revoked
        }
      }
    });

    /// A [ServerException] with this status (and code, when given).
    Matcher throwsServer(int status, [String? code]) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code ?? anything),
    );

    // =======================================================================
    // 1. Super admin profile
    // =======================================================================

    group('31.1: super admin profile', () {
      test('an admin changing the super admin email gets 403', () async {
        final before = await sudoClient.users.getUserPrivate(sudoUsername);

        await expectLater(
          adminClient.users.updateUser(
            sudoUsername,
            email: 'test_i31_takeover@test.com',
          ),
          throwsServer(403, SdkErrorCode.superAdminProtection),
        );

        final after = await sudoClient.users.getUserPrivate(sudoUsername);
        expect(after.email, before.email);
      });

      test('an admin changing any other super admin field gets 403', () async {
        final before = await sudoClient.users.getUserPrivate(sudoUsername);

        await expectLater(
          adminClient.users.updateUser(
            sudoUsername,
            firstName: () => 'Renamed',
          ),
          throwsServer(403, SdkErrorCode.superAdminProtection),
        );

        final after = await sudoClient.users.getUserPrivate(sudoUsername);
        expect(after.firstName, before.firstName);
      });

      test('the super admin still updates their own profile', () async {
        // A name rather than the email: the bootstrap super admin may have no
        // email, and the SDK cannot clear one once set, so an email change
        // could not be undone for the suites that follow.
        final original = (await sudoClient.users.getUserPrivate(
          sudoUsername,
        )).firstName;
        try {
          final updated = await sudoClient.users.updateUser(
            sudoUsername,
            firstName: () => 'Self Edited',
          );
          expect(updated.firstName, 'Self Edited');
        } finally {
          await sudoClient.users.updateUser(
            sudoUsername,
            firstName: () => original,
          );
        }
        final restored = await sudoClient.users.getUserPrivate(sudoUsername);
        expect(restored.firstName, original);
      });

      test('an admin still updates an ordinary member', () async {
        final updated = await adminClient.users.updateUser(
          target,
          email: 'test_i31_target_new@test.com',
          firstName: () => 'Edited',
        );
        expect(updated.email, 'test_i31_target_new@test.com');
        expect(updated.firstName, 'Edited');

        final read = await sudoClient.users.getUserPrivate(target);
        expect(read.email, 'test_i31_target_new@test.com');
        expect(read.firstName, 'Edited');
      });
    });

    // =======================================================================
    // 2. Super admin delete
    // =======================================================================

    group('31.2: super admin delete', () {
      test('an admin soft-deleting the super admin gets 403', () async {
        await expectLater(
          adminClient.users.deleteUser(sudoUsername),
          throwsServer(403, SdkErrorCode.superAdminProtection),
        );

        // The account is still live: it can log in and is not listed deleted.
        final fresh = await loggedIn(sudoUsername, sudoPassword);
        final me = await fresh.auth.getCurrentUser();
        expect(me.username, sudoUsername);
        expect(me.isSuperAdmin, isTrue);
        await fresh.auth.logout();

        final deleted = await sudoClient.users.getDeletedUsers(limit: 100);
        expect(
          deleted.items.map((u) => u.username),
          isNot(contains(sudoUsername)),
        );
      });

      test('an admin still soft-deletes an ordinary member', () async {
        await adminClient.users.deleteUser(target);

        final active = await sudoClient.users.getUsers(limit: 100);
        expect(active.items.map((u) => u.username), isNot(contains(target)));
        final deleted = await sudoClient.users.getDeletedUsers(limit: 100);
        expect(deleted.items.map((u) => u.username), contains(target));
      });
    });

    // =======================================================================
    // 3. Acting on a member's enrollment
    // =======================================================================

    group('31.3: acting for a member', () {
      // The allowed actors, by username; each acts for [member].
      late Map<String, SecureClient> allowed;

      setUpAll(() {
        allowed = {
          member: memberClient,
          admin: adminClient,
          organizer: organizerClient,
          coach: coachClient,
        };
      });

      /// A public one-off on a day of its own, organized by [organizer] and
      /// coached by [coach].
      Future<int> oneOff(String label) async {
        final start = dayAt(nextDay++, hour: 15);
        final event = await sudoClient.events.createEvent(
          title: 'test_i31_$label',
          description: 'acting for a member',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          organizerName: organizer,
          coachNames: [coach],
        );
        return event.id;
      }

      /// The audit row for [action] targeting [member] on [resource] names
      /// [actor] as the one who acted.
      Future<void> expectActor(
        String action,
        String actor,
        bool Function(Map<String, dynamic>? resource) resource,
      ) async {
        final page = await sudoClient.auditLog.list(
          username: member,
          action: action,
          limit: 200,
        );
        final rows = page.rows.where(
          (r) =>
              r.action == action &&
              r.target?.username == member &&
              resource(r.resource),
        );
        expect(rows, hasLength(1), reason: '$action by $actor');
        expect(rows.single.actor?.username, actor);
      }

      bool Function(Map<String, dynamic>?) onEvent(int id) =>
          (r) => r?['id'] == id;

      test('accept invite: member, admin, organizer, coach', () async {
        for (final MapEntry(key: actor, value: client) in allowed.entries) {
          final id = await oneOff('accept_$actor');
          await sudoClient.enrollments.invite(id, member);

          await client.myEvents.acceptInvite(member, id);

          expect(
            await sudoClient.enrollments.getEnrollmentStatus(id, member),
            EnrollmentStatus.accepted,
            reason: 'accepted by $actor',
          );
          await expectActor('enrollment_accepted', actor, onEvent(id));
        }
      });

      test('accept invite: an unlinked coach gets 403', () async {
        final id = await oneOff('accept_outsider');
        await sudoClient.enrollments.invite(id, member);

        await expectLater(
          outsiderClient.myEvents.acceptInvite(member, id),
          throwsServer(403, SdkErrorCode.insufficientPermission),
        );
        expect(
          await sudoClient.enrollments.getEnrollmentStatus(id, member),
          EnrollmentStatus.invited,
        );
      });

      test('request to join: member, admin, organizer, coach', () async {
        for (final MapEntry(key: actor, value: client) in allowed.entries) {
          final id = await oneOff('request_$actor');

          await client.myEvents.requestToJoin(member, id);

          expect(
            await sudoClient.enrollments.getEnrollmentStatus(id, member),
            EnrollmentStatus.requested,
            reason: 'requested by $actor',
          );
          await expectActor('enrollment_requested', actor, onEvent(id));
        }
      });

      test('request to join: an unlinked coach gets 403', () async {
        final id = await oneOff('request_outsider');

        await expectLater(
          outsiderClient.myEvents.requestToJoin(member, id),
          throwsServer(403, SdkErrorCode.insufficientPermission),
        );
        expect(
          await sudoClient.enrollments.getEnrollmentStatus(id, member),
          isNull,
        );
      });

      test('withdraw: member, admin, organizer, coach', () async {
        for (final MapEntry(key: actor, value: client) in allowed.entries) {
          final id = await oneOff('withdraw_$actor');
          await sudoClient.enrollments.assign(id, member);

          await client.myEvents.withdraw(member, id, reason: 'by $actor');

          expect(
            await sudoClient.enrollments.getEnrollmentStatus(id, member),
            EnrollmentStatus.withdrawRequested,
            reason: 'withdrawn by $actor',
          );
          await expectActor('withdrawal_requested', actor, onEvent(id));
        }
      });

      test('withdraw: an unlinked coach gets 403', () async {
        final id = await oneOff('withdraw_outsider');
        await sudoClient.enrollments.assign(id, member);

        await expectLater(
          outsiderClient.myEvents.withdraw(member, id, reason: 'outsider'),
          throwsServer(403, SdkErrorCode.insufficientPermission),
        );
        expect(
          await sudoClient.enrollments.getEnrollmentStatus(id, member),
          EnrollmentStatus.assigned,
        );
      });

      Future<AttendanceStatus?> leaveStatus(DateTime occurrence) async {
        final records = await sudoClient.attendance.getAttendanceForOccurrence(
          programmeId,
          occurrence,
        );
        final mine = records.where((r) => r.membername == member);
        return mine.isEmpty ? null : mine.single.status;
      }

      test('request leave: member, admin, organizer, coach', () async {
        var week = 1;
        for (final MapEntry(key: actor, value: client) in allowed.entries) {
          final occurrence = programmeStart.add(Duration(days: 7 * week++));

          await client.myEvents.requestLeave(
            member,
            programmeId,
            occurrence,
            reason: 'by $actor',
          );

          expect(
            await leaveStatus(occurrence),
            AttendanceStatus.onLeaveRequested,
            reason: 'leave requested by $actor',
          );
          await expectActor(
            'leave_requested',
            actor,
            (r) =>
                r?['eventId'] == programmeId &&
                r?['occurrenceTimeUtc'] == occurrence.millisecondsSinceEpoch,
          );
        }
      });

      test('request leave: an unlinked coach gets 403', () async {
        final occurrence = programmeStart.add(const Duration(days: 7 * 10));

        await expectLater(
          outsiderClient.myEvents.requestLeave(
            member,
            programmeId,
            occurrence,
            reason: 'outsider',
          ),
          throwsServer(403, SdkErrorCode.insufficientPermission),
        );
        expect(await leaveStatus(occurrence), isNull);
      });
    });

    // =======================================================================
    // 4. Tokens
    // =======================================================================

    group('31.4: tokens', () {
      test('a refresh token used as a bearer token gets 401', () async {
        final token = await (await createRemoteSecureClient(
          baseUrl: baseUrl,
        )).auth.login(tokenUser, password);
        expect(token.refreshToken, isNotNull);

        final withRefresh = await createRemoteSecureClient(
          baseUrl: baseUrl,
          authToken: token.refreshToken,
        );
        await expectLater(
          withRefresh.auth.getCurrentUser(),
          throwsServer(401, 'INVALID_TOKEN'),
        );
        await expectLater(
          withRefresh.myEvents.listMyEvents(tokenUser),
          throwsServer(401, 'INVALID_TOKEN'),
        );

        // The access token from the same login works.
        final withAccess = await createRemoteSecureClient(
          baseUrl: baseUrl,
          authToken: token.accessToken,
        );
        expect((await withAccess.auth.getCurrentUser()).username, tokenUser);
      });

      test('the SDK refreshes and retries when the access token is '
          'refused', () async {
        final token = await (await createRemoteSecureClient(
          baseUrl: baseUrl,
        )).auth.login(tokenUser, password);

        // A genuinely expired access token cannot be minted here without
        // waiting out its lifetime, so this sends a token with a broken
        // signature instead. The server treats both alike (the JWT fails to
        // decode: 401 INVALID_TOKEN), and the SDK refreshes on any 401 other
        // than INVALID_CREDENTIALS / ACCOUNT_BLOCKED, so the path exercised
        // is the one an expired token takes.
        final broken = '${token.accessToken}x';
        final c = await _refreshing(broken, token.refreshToken!);

        final me = await c.client.auth.getCurrentUser();
        expect(me.username, tokenUser);
        expect(c.refreshes(), 1);
      });

      test('after changing their password, old access and refresh tokens '
          'fail', () async {
        final session = await createRemoteSecureClient(baseUrl: baseUrl);
        final old = await session.auth.login(selfChanger, password);
        // The server compares a token's iat with password_changed_at to the
        // millisecond; the login and the change are separate round trips, so
        // the token is always strictly older.
        await session.auth.changePassword(
          currentPassword: password,
          newPassword: 'password456',
        );

        await _expectOldTokensRefused(old);

        final fresh = await loggedIn(selfChanger, 'password456');
        expect((await fresh.auth.getCurrentUser()).username, selfChanger);
      });

      test(
        'after an admin reset, old access and refresh tokens fail',
        () async {
          final old = await (await createRemoteSecureClient(
            baseUrl: baseUrl,
          )).auth.login(resetUser, password);

          final temporary = await adminClient.users.adminResetPassword(
            resetUser,
          );

          await _expectOldTokensRefused(old);

          final fresh = await loggedIn(resetUser, temporary);
          expect((await fresh.auth.getCurrentUser()).username, resetUser);
        },
      );
    });

    // =======================================================================
    // 5. Duplicate email on update
    // =======================================================================

    group('31.5: duplicate email on update', () {
      test('an admin setting a taken email gets 409 DUPLICATE_EMAIL', () async {
        const taken = '$other@test.com';
        final before = await sudoClient.users.getUserPrivate(member);

        await expectLater(
          adminClient.users.updateUser(member, email: taken),
          throwsServer(409, SdkErrorCode.duplicateEmail),
        );

        expect(
          (await sudoClient.users.getUserPrivate(member)).email,
          before.email,
        );
        expect((await sudoClient.users.getUserPrivate(other)).email, taken);
      });

      test(
        'a member setting their own email to a taken one gets 409',
        () async {
          await expectLater(
            memberClient.users.updateUser(member, email: '$other@test.com'),
            throwsServer(409, SdkErrorCode.duplicateEmail),
          );
        },
      );
    });
  });
}

/// A client that refreshes the way an app does: on a 401 its store trades
/// [refreshToken] for a new access token through a separate, bare client,
/// and gives up (null) when the refresh is refused. Routing the refresh
/// through the same store would re-enter the callback on the refresh
/// endpoint's own 401. `refreshes` counts the callback's calls.
Future<({SecureClient client, int Function() refreshes})> _refreshing(
  String accessToken,
  String refreshToken,
) async {
  var calls = 0;
  final store = RemoteStore(
    baseUrl: baseUrl,
    onTokenExpired: () async {
      calls++;
      final bare = await createRemoteSecureClient(baseUrl: baseUrl);
      try {
        return (await bare.auth.refreshToken(refreshToken)).accessToken;
      } on ServerException {
        return null;
      }
    },
  )..authToken = accessToken;
  final client = await createRemoteSecureClient(baseUrl: baseUrl, store: store);
  return (client: client, refreshes: () => calls);
}

/// Both tokens of [old] are refused, and a refreshing client holding them
/// surfaces the 401 after one refresh attempt instead of looping.
Future<void> _expectOldTokensRefused(AuthToken old) async {
  final withAccess = await createRemoteSecureClient(
    baseUrl: baseUrl,
    authToken: old.accessToken,
  );
  await expectLater(
    withAccess.auth.getCurrentUser(),
    throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.code, 'code', 'INVALID_TOKEN'),
    ),
  );

  final bare = await createRemoteSecureClient(baseUrl: baseUrl);
  await expectLater(
    bare.auth.refreshToken(old.refreshToken!),
    throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.code, 'code', SdkErrorCode.invalidRefreshToken),
    ),
  );

  // The SDK path: the 401 triggers one refresh, the refresh is refused, and
  // the original 401 reaches the caller. The timeout turns a loop into a
  // failure rather than a hang.
  final c = await _refreshing(old.accessToken, old.refreshToken!);
  await expectLater(
    c.client.auth.getCurrentUser().timeout(const Duration(seconds: 20)),
    throwsA(
      isA<ServerException>().having((e) => e.statusCode, 'statusCode', 401),
    ),
  );
  expect(c.refreshes(), 1);
}
