import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 33: credit rules the server enforces.
///
/// - A member whose trial ran out and who then buys a package rejoins as a
///   paying member: the enrollment is no longer a trial, and sessions draw
///   from the package, never from the spent trial account.
/// - A `CreditDisposition` whose window ends at or before it starts is a
///   422 `VALIDATION_ERROR` on `removeEnrollment` and `approveWithdraw`.
///   The window is validated where the admin states it, so the refusal is
///   the same whether the departure settles at once or is deferred to the
///   end of a session under way. A valid window settles as before.
///
/// No SDK code changes: these guard server behaviour. Runs on both stacks;
/// with the credit system off every case is skipped.
void main() {
  group('Issue 33: credit rules', () {
    late SecureClient admin;
    late bool creditsOn;
    late int futureProgrammeId;

    const password = 'password123';
    const rejoinerName = 'test_rule_rejoiner';
    const removedName = 'test_rule_removed';
    const leaverName = 'test_rule_leaver';
    const lapsedWindowName = 'test_rule_lapsed_window';
    const deferredRemovedName = 'test_rule_deferred_removed';
    const deferredLeaverName = 'test_rule_deferred_leaver';

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      creditsOn = (await stackCapabilities(admin)).creditSystem;

      for (final name in [
        rejoinerName,
        removedName,
        leaverName,
        lapsedWindowName,
        deferredRemovedName,
        deferredLeaverName,
      ]) {
        await registerAndApprove(
          client: admin,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: password,
          phone: '+919000000033',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
      }

      // A programme whose first session is weeks away: no session is
      // under way, so a departure settles at the call.
      final venue = await admin.venues.createVenue(
        name: 'test_rule_venue',
        address: '1 Rink Road',
      );
      final start = dayAt(21);
      final programme = await admin.events.createEvent(
        title: 'test_rule_programme',
        description: 'a credited programme',
        type: EventType.programme,
        venueId: venue.id,
        visibility: Visibility.public,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
      futureProgrammeId = programme.id;
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    // A weekly programme starting at [start], with its own venue and
    // organizer so two made in the same minute do not clash.
    Future<Event> createProgramme(String suffix, DateTime start) async {
      final organizer = 'test_rule_org_$suffix';
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: organizer,
        email: '$organizer@example.com',
        password: password,
        phone: '+919000000034',
        dateOfBirthUtc: DateTime.utc(1990),
        gender: Gender.female,
        firstName: 'Test',
        lastName: organizer,
      );
      final venue = await admin.venues.createVenue(
        name: 'test_rule_venue_$suffix',
        address: '2 Rink Road',
      );
      return admin.events.createEvent(
        title: 'test_rule_programme_$suffix',
        description: 'a programme for credit rules',
        type: EventType.programme,
        venueId: venue.id,
        visibility: Visibility.public,
        organizerName: organizer,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
    }

    Future<CreditAccount> openPackage(String name, int eventId) =>
        admin.credits.openAccount(
          membername: name,
          credits: 6,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(120),
          reason: 'season package',
          eventId: eventId,
        );

    Future<SecureClient> loginAs(String name) async {
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(name, password);
      addTearDown(client.auth.logout);
      expect((await client.auth.getCurrentUser()).username, name);
      return client;
    }

    final throwsValidationError = throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'status', 422)
          .having((e) => e.code, 'code', SdkErrorCode.validationError),
    );

    // Until exactly equal to from: an empty window.
    final emptyWindow = CreditDisposition(
      penalty: 0,
      validFromUtc: dayAt(30),
      validUntilUtc: dayAt(30),
      reason: 'empty window',
    );
    // Until before from: a backwards window.
    final backwardsWindow = CreditDisposition(
      penalty: 0,
      validFromUtc: dayAt(60),
      validUntilUtc: dayAt(30),
      reason: 'backwards window',
    );
    final validWindow = CreditDisposition(
      penalty: 1,
      validFromUtc: dayAt(-1),
      validUntilUtc: dayAt(180),
      reason: 'leaving the programme',
    );

    test(
      '33.01: a paid package after a spent trial rejoins as a paying member '
      'and pays from the package',
      () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        // Two sessions are needed: one to spend the trial, one to charge
        // the package. The programme's upcoming session starts 10 minutes
        // out (its register is open), and the one a week earlier is past.
        final upcoming = nowUtcMinute().add(const Duration(minutes: 10));
        final previous = upcoming.subtract(const Duration(days: 7));
        final programme = await createProgramme('rejoin', previous);

        final trial = await admin.credits.openAccount(
          membername: rejoinerName,
          credits: 1,
          validFromUtc: dayAt(-10),
          validUntilUtc: dayAt(60),
          reason: 'one trial session',
          eventId: programme.id,
          isTrial: true,
        );
        await admin.enrollments.assignTrial(programme.id, rejoinerName);
        expect(
          await admin.enrollments.getEnrollmentStatus(
            programme.id,
            rejoinerName,
          ),
          EnrollmentStatus.assignedTrial,
        );

        // The trial's one credit is spent on the past session. The admin
        // here is the super admin, whom the server lets mark a session
        // that predates the enrollment.
        final trialReport = await admin.attendance.markAttendance(
          programme.id,
          previous,
          [
            const AttendanceMarkRecord(
              membername: rejoinerName,
              status: AttendanceStatus.present,
            ),
          ],
        );
        expect(trialReport.marked.map((m) => m.membername), [rejoinerName]);
        expect(trialReport.trialEnded, [rejoinerName]);
        expect((await admin.credits.getAccount(trial.accountId)).balance, 0);
        expect(
          (await admin.myEvents.getMyEnrollment(
            rejoinerName,
            programme.id,
          )).status,
          EnrollmentStatus.removed,
        );

        // They buy a package and are assigned again.
        final package = await admin.credits.openAccount(
          membername: rejoinerName,
          credits: 5,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(120),
          reason: 'paid package',
          eventId: programme.id,
        );
        expect(package.isTrial, isFalse);
        await admin.enrollments.assign(programme.id, rejoinerName);

        final rejoiner = await loginAs(rejoinerName);
        for (final viewer in [admin, rejoiner]) {
          final enrollment = await viewer.myEvents.getMyEnrollment(
            rejoinerName,
            programme.id,
          );
          expect(enrollment.status, EnrollmentStatus.assigned);
          expect(
            enrollment.isTrial,
            isFalse,
            reason: 'the new stint is a paid one, not the old trial',
          );
          expect(enrollment.withdrawnAtUtc, isNull);
        }

        // The next mark draws from the package, not the trial account.
        final paidReport = await admin.attendance.markAttendance(
          programme.id,
          upcoming,
          [
            const AttendanceMarkRecord(
              membername: rejoinerName,
              status: AttendanceStatus.present,
            ),
          ],
        );
        expect(paidReport.marked.map((m) => m.membername), [rejoinerName]);
        expect(paidReport.refused, isEmpty);
        expect(paidReport.trialEnded, isEmpty);

        expect((await admin.credits.getAccount(package.accountId)).balance, 4);
        expect((await admin.credits.getAccount(trial.accountId)).balance, 0);

        final packageEntries = await admin.credits.listEntries(
          accountId: package.accountId,
          order: EntryOrder.oldestFirst,
        );
        expect(packageEntries.items.map((e) => e.entryType), [
          CreditEntryType.grant,
          CreditEntryType.sessionDeduction,
        ]);
        expect(packageEntries.items.last.amount, -1);
        expect(packageEntries.items.last.occurrenceTimeUtc, upcoming);

        final trialEntries = await admin.credits.listEntries(
          accountId: trial.accountId,
          order: EntryOrder.oldestFirst,
        );
        expect(
          trialEntries.items.map((e) => e.entryType),
          [CreditEntryType.grant, CreditEntryType.sessionDeduction],
          reason: 'the trial paid for the first session only',
        );
        expect(trialEntries.items.last.occurrenceTimeUtc, previous);

        expect(
          await admin.enrollments.getEnrollmentStatus(
            programme.id,
            rejoinerName,
          ),
          EnrollmentStatus.assigned,
          reason: 'a paid mark does not end the enrollment',
        );
      },
    );

    group('33.02: departure window, settled at the call', () {
      test('removeEnrollment refuses an empty or backwards window, then '
          'settles a valid one', () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        final package = await openPackage(removedName, futureProgrammeId);
        await admin.enrollments.assign(futureProgrammeId, removedName);

        for (final bad in [emptyWindow, backwardsWindow]) {
          await expectLater(
            admin.enrollments.removeEnrollment(
              futureProgrammeId,
              removedName,
              creditDisposition: bad,
            ),
            throwsValidationError,
            reason: bad.reason,
          );
        }
        expect(
          await admin.enrollments.getEnrollmentStatus(
            futureProgrammeId,
            removedName,
          ),
          EnrollmentStatus.assigned,
          reason: 'a refused removal leaves the member enrolled',
        );
        final untouched = await admin.credits.getAccount(package.accountId);
        expect(untouched.balance, 6);
        expect(untouched.state, isNot(CreditAccountState.closed));

        await admin.enrollments.removeEnrollment(
          futureProgrammeId,
          removedName,
          creditDisposition: validWindow,
        );

        expect(
          await admin.enrollments.getEnrollmentStatus(
            futureProgrammeId,
            removedName,
          ),
          EnrollmentStatus.removed,
        );
        final source = await admin.credits.getAccount(package.accountId);
        expect(source.state, CreditAccountState.closed);
        final general = await admin.credits.listAccounts(
          membername: removedName,
          kind: CreditAccountKind.general,
        );
        expect(general.items, hasLength(1));
        expect(
          general.items.single.balance,
          5,
          reason: 'six credits less the penalty of one',
        );
        expect(general.items.single.eventId, isNull);
      });

      test('approveWithdraw refuses an empty or backwards window, then '
          'settles a valid one', () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        final package = await openPackage(leaverName, futureProgrammeId);
        await admin.enrollments.assign(futureProgrammeId, leaverName);
        final leaver = await loginAs(leaverName);
        await leaver.myEvents.withdraw(leaverName, futureProgrammeId);
        expect(
          await admin.enrollments.getEnrollmentStatus(
            futureProgrammeId,
            leaverName,
          ),
          EnrollmentStatus.withdrawRequested,
        );

        for (final bad in [emptyWindow, backwardsWindow]) {
          await expectLater(
            admin.enrollments.approveWithdraw(
              futureProgrammeId,
              leaverName,
              creditDisposition: bad,
            ),
            throwsValidationError,
            reason: bad.reason,
          );
        }
        expect(
          await admin.enrollments.getEnrollmentStatus(
            futureProgrammeId,
            leaverName,
          ),
          EnrollmentStatus.withdrawRequested,
          reason: 'a refused approval leaves the request open',
        );
        expect((await admin.credits.getAccount(package.accountId)).balance, 6);

        await admin.enrollments.approveWithdraw(
          futureProgrammeId,
          leaverName,
          creditDisposition: validWindow,
        );

        expect(
          await admin.enrollments.getEnrollmentStatus(
            futureProgrammeId,
            leaverName,
          ),
          EnrollmentStatus.withdrawn,
        );
        final source = await admin.credits.getAccount(package.accountId);
        expect(source.state, CreditAccountState.closed);
        final general = await admin.credits.listAccounts(
          membername: leaverName,
          kind: CreditAccountKind.general,
        );
        expect(general.items.map((a) => a.balance), [5]);
      });

      test('a window that has already closed is refused too', () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        // Beyond the issue: the server also refuses a window whose end has
        // passed, since the remainder could never be spent.
        final package = await openPackage(lapsedWindowName, futureProgrammeId);
        await admin.enrollments.assign(futureProgrammeId, lapsedWindowName);

        await expectLater(
          admin.enrollments.removeEnrollment(
            futureProgrammeId,
            lapsedWindowName,
            creditDisposition: CreditDisposition(
              penalty: 0,
              validFromUtc: dayAt(-10),
              validUntilUtc: dayAt(-1),
              reason: 'closed window',
            ),
          ),
          throwsValidationError,
        );
        expect(
          await admin.enrollments.getEnrollmentStatus(
            futureProgrammeId,
            lapsedWindowName,
          ),
          EnrollmentStatus.assigned,
        );
        expect((await admin.credits.getAccount(package.accountId)).balance, 6);
      });
    });

    test(
      '33.03: departure window, deferred while a session is under way',
      () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        // A session that starts a few seconds from now. Members enrolled
        // before it starts stay chargeable for it, so a departure during
        // it is settled when it ends, not at the call.
        final now = DateTime.now().toUtc();
        final start = DateTime.utc(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        ).add(const Duration(seconds: 8));
        final programme = await createProgramme('deferred', start);

        final removedPackage = await openPackage(
          deferredRemovedName,
          programme.id,
        );
        final leaverPackage = await openPackage(
          deferredLeaverName,
          programme.id,
        );
        await admin.enrollments.assign(programme.id, deferredRemovedName);
        await admin.enrollments.assign(programme.id, deferredLeaverName);
        final leaver = await loginAs(deferredLeaverName);

        await Future<void>.delayed(
          start.difference(DateTime.now().toUtc()) + const Duration(seconds: 2),
        );
        expect(
          DateTime.now().toUtc().isAfter(start),
          isTrue,
          reason: 'the session must be under way',
        );
        await leaver.myEvents.withdraw(deferredLeaverName, programme.id);

        for (final bad in [emptyWindow, backwardsWindow]) {
          await expectLater(
            admin.enrollments.removeEnrollment(
              programme.id,
              deferredRemovedName,
              creditDisposition: bad,
            ),
            throwsValidationError,
            reason: 'remove: ${bad.reason}',
          );
          await expectLater(
            admin.enrollments.approveWithdraw(
              programme.id,
              deferredLeaverName,
              creditDisposition: bad,
            ),
            throwsValidationError,
            reason: 'approve-withdraw: ${bad.reason}',
          );
        }
        expect(
          await admin.enrollments.getEnrollmentStatus(
            programme.id,
            deferredRemovedName,
          ),
          EnrollmentStatus.assigned,
        );
        expect(
          await admin.enrollments.getEnrollmentStatus(
            programme.id,
            deferredLeaverName,
          ),
          EnrollmentStatus.withdrawRequested,
        );

        await admin.enrollments.removeEnrollment(
          programme.id,
          deferredRemovedName,
          creditDisposition: validWindow,
        );
        await admin.enrollments.approveWithdraw(
          programme.id,
          deferredLeaverName,
          creditDisposition: validWindow,
        );

        expect(
          await admin.enrollments.getEnrollmentStatus(
            programme.id,
            deferredRemovedName,
          ),
          EnrollmentStatus.removed,
        );
        expect(
          await admin.enrollments.getEnrollmentStatus(
            programme.id,
            deferredLeaverName,
          ),
          EnrollmentStatus.withdrawn,
        );

        // Deferred: the package stays open and bound until the session
        // ends, and no general account has been opened yet.
        for (final (name, package) in [
          (deferredRemovedName, removedPackage),
          (deferredLeaverName, leaverPackage),
        ]) {
          final account = await admin.credits.getAccount(package.accountId);
          expect(account.balance, 6, reason: name);
          expect(account.state, isNot(CreditAccountState.closed), reason: name);
          final general = await admin.credits.listAccounts(
            membername: name,
            kind: CreditAccountKind.general,
          );
          expect(general.items, isEmpty, reason: name);
        }
      },
    );
  });
}
