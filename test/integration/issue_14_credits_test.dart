import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 14: the credit system (`/credits`, `/mycredits`, club_server#294).
///
/// Credit applies to programmes only, and there is no top-up, no edit and
/// no delete: the balance derives from an append-only ledger, so more
/// credit is a new account and a correction is a reversal. These tests
/// exercise that shape end to end.
///
/// Runs against both stacks: `just sdk-test` (module off) asserts the 503,
/// `just sdk-test-modules` the behaviour.
void main() {
  group('Issue 14: credit system', () {
    late SecureClient admin;
    late SecureClient member;
    late bool creditsOn;
    late int programmeId;
    late int campId;

    const memberName = 'test_credit_member';
    const otherName = 'test_credit_other';

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      creditsOn = (await stackCapabilities(admin)).creditSystem;

      for (final name in [memberName, otherName]) {
        await registerAndApprove(
          client: admin,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: 'password123',
          phone: '+919000000001',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
      }

      final venue = await admin.venues.createVenue(
        name: 'test_credit_venue',
        address: '1 Rink Road',
      );

      final start = dayAt(21);
      final programme = await admin.events.createEvent(
        title: 'test_credit_programme',
        description: 'a credited programme',
        type: EventType.programme,
        venueId: venue.id,
        visibility: Visibility.public,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
      programmeId = programme.id;

      final campStart = dayAt(28);
      final camp = await admin.events.createEvent(
        title: 'test_credit_camp',
        description: 'a camp',
        type: EventType.camp,
        venueId: venue.id,
        visibility: Visibility.public,
        startTimeUtc: campStart,
        endTimeUtc: campStart.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=3',
      );
      campId = camp.id;

      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login(memberName, 'password123');
    });

    tearDownAll(() async {
      await admin.auth.logout();
      await member.auth.logout();
    });

    test('14.00: every route answers 503 where the module is off', () async {
      if (creditsOn) {
        markTestSkipped('credit system is on on this stack');
        return;
      }
      await expectLater(
        admin.credits.listAccounts(),
        throwsModuleDisabled(SdkErrorCode.creditSystemDisabled),
      );
      await expectLater(
        admin.credits.listEntries(),
        throwsModuleDisabled(SdkErrorCode.creditSystemDisabled),
      );
      await expectLater(
        admin.credits.listEventCredits(programmeId),
        throwsModuleDisabled(SdkErrorCode.creditSystemDisabled),
      );
      await expectLater(
        member.myCredits.listMyAccounts(memberName),
        throwsModuleDisabled(SdkErrorCode.creditSystemDisabled),
      );
    });

    test(
      '14.01: opening an account grants credit and opens a ledger',
      () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        final account = await admin.credits.openAccount(
          membername: memberName,
          credits: 10,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(120),
          reason: 'season grant',
          eventId: programmeId,
        );

        expect(account.membername, memberName);
        expect(account.balance, 10);
        expect(
          account.usable,
          isTrue,
          reason: 'validity opened yesterday and the balance is positive',
        );
        expect(account.kind, CreditAccountKind.event);
        expect(account.eventId, programmeId);
        expect(account.state, CreditAccountState.usable);
        expect(account.isTrial, isFalse);
        expect(account.accountId, hasLength(8));

        final fetched = await admin.credits.getAccount(account.accountId);
        expect(fetched, account);

        final entries = await admin.credits.listEntries(
          accountId: account.accountId,
        );
        expect(entries.items, hasLength(1));
        expect(entries.items.single.entryType, CreditEntryType.grant);
        expect(entries.items.single.amount, 10);
      },
    );

    test('14.02: a camp or one-off cannot hold credit', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      await expectLater(
        admin.credits.openAccount(
          membername: memberName,
          credits: 5,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(60),
          reason: 'camp grant',
          eventId: campId,
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.creditNotApplicable,
          ),
        ),
      );
    });

    test('14.03: a grant must be a positive whole number', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      await expectLater(
        admin.credits.openAccount(
          membername: memberName,
          credits: 0,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(60),
          reason: 'nothing',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidCreditAmount,
          ),
        ),
      );
    });

    test('14.04: a validity window cannot end before it starts', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      await expectLater(
        admin.credits.openAccount(
          membername: memberName,
          credits: 5,
          validFromUtc: dayAt(60),
          validUntilUtc: dayAt(30),
          reason: 'backwards',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidValidityWindow,
          ),
        ),
      );
    });

    test(
      '14.05: extending validity writes a zero-amount ledger entry',
      () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        final account = await admin.credits.openAccount(
          membername: memberName,
          credits: 4,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(30),
          reason: 'short grant',
        );

        final extended = await admin.credits.extendValidity(
          account.accountId,
          validUntilUtc: dayAt(90),
          reason: 'season extended',
        );
        expect(extended.validUntilUtc.isAfter(account.validUntilUtc), isTrue);
        expect(extended.balance, account.balance);

        final entries = await admin.credits.listEntries(
          accountId: account.accountId,
        );
        final extension = entries.items.firstWhere(
          (e) => e.entryType == CreditEntryType.validityExtended,
        );
        expect(extension.amount, 0);
      },
    );

    test('14.06: a grant is undone by reversal, never by editing', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      final account = await admin.credits.openAccount(
        membername: memberName,
        credits: 8,
        validFromUtc: dayAt(-1),
        validUntilUtc: dayAt(90),
        reason: 'mistaken grant',
      );

      final reversed = await admin.credits.reverseGrant(
        account.accountId,
        reason: 'granted twice',
        credits: 3,
      );
      expect(reversed.balance, 5);

      await expectLater(
        admin.credits.reverseGrant(
          account.accountId,
          reason: 'too much',
          credits: 99,
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.insufficientBalance,
          ),
        ),
      );

      final entries = await admin.credits.listEntries(
        accountId: account.accountId,
      );
      expect(
        entries.items.map((e) => e.entryType),
        contains(CreditEntryType.grantReversal),
      );
    });

    test(
      '14.07: transfer closes the account and opens the remainder',
      () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        final account = await admin.credits.openAccount(
          membername: memberName,
          credits: 10,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(30),
          reason: 'expiring grant',
          eventId: programmeId,
        );

        final result = await admin.credits.transfer(
          account.accountId,
          penalty: 2,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(180),
          reason: 'dropped out',
        );

        expect(result.source.accountId, account.accountId);
        expect(result.source.state, CreditAccountState.closed);
        expect(result.created, isNotNull);
        expect(result.created!.balance, 8);
        expect(result.created!.kind, CreditAccountKind.general);
        expect(result.created!.eventId, isNull);

        final entries = await admin.credits.listEntries(
          accountId: account.accountId,
        );
        final types = entries.items.map((e) => e.entryType).toSet();
        expect(types, containsAll([CreditEntryType.transferOut]));
        expect(types, contains(CreditEntryType.penalty));
      },
    );

    test('14.08: an unknown account code is a 404', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      await expectLater(
        admin.credits.getAccount('ZZZZZZZZ'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 404)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.creditAccountNotFound,
              ),
        ),
      );
    });

    test('14.09: listAccounts filters by member, event and state', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      final mine = await admin.credits.listAccounts(membername: memberName);
      expect(mine.items, isNotEmpty);
      expect(mine.items.every((a) => a.membername == memberName), isTrue);

      final onProgramme = await admin.credits.listAccounts(
        membername: memberName,
        eventId: programmeId,
      );
      expect(onProgramme.items, isNotEmpty);
      expect(onProgramme.items.every((a) => a.eventId == programmeId), isTrue);

      final closed = await admin.credits.listAccounts(
        membername: memberName,
        state: CreditAccountState.closed,
      );
      expect(
        closed.items.every((a) => a.state == CreditAccountState.closed),
        isTrue,
      );

      final none = await admin.credits.listAccounts(membername: otherName);
      expect(none.items, isEmpty);
    });

    test(
      '14.10: the roster carries the enrolled, not the merely invited',
      () async {
        if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

        // Credit gates enrolment: a member with no usable account cannot
        // even be invited to a credited programme.
        await expectLater(
          admin.enrollments.invite(programmeId, otherName),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.insufficientCredit,
            ),
          ),
        );
        await admin.enrollments.assign(programmeId, memberName);

        final roster = await admin.credits.listEventCredits(programmeId);
        final names = roster.items.map((r) => r.membername);
        expect(names, contains(memberName));
        expect(
          names,
          isNot(contains(otherName)),
          reason: 'the uncredited member was never enrolled',
        );

        final row = roster.items.firstWhere((r) => r.membername == memberName);
        expect(row.blocked, isFalse);
        expect(
          row.usableCredits,
          greaterThan(0),
          reason: 'this member holds a usable account on the programme',
        );
        expect(row.payingAccountId, isNotNull);
      },
    );

    test('14.11: a member reads their own accounts and statement', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      final accounts = await member.myCredits.listMyAccounts(memberName);
      expect(accounts, isNotEmpty);
      expect(accounts.every((a) => a.membername == memberName), isTrue);
      expect(
        accounts.any((a) => a.state == CreditAccountState.closed),
        isFalse,
        reason: 'closed accounts need includeClosed',
      );

      final withClosed = await member.myCredits.listMyAccounts(
        memberName,
        includeClosed: true,
      );
      expect(withClosed.length, greaterThanOrEqualTo(accounts.length));

      final one = await member.myCredits.getMyAccount(
        memberName,
        accounts.first.accountId,
      );
      expect(one.accountId, accounts.first.accountId);

      final statement = await member.myCredits.listMyEntries(memberName);
      expect(statement.items, isNotEmpty);
    });

    test("14.12: a member cannot read someone else's credit", () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      await expectLater(
        member.myCredits.listMyAccounts(otherName),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    });

    test('14.13: a member cannot open an account', () async {
      if (skipUnless(enabled: creditsOn, module: 'credit system')) return;

      await expectLater(
        member.credits.openAccount(
          membername: memberName,
          credits: 100,
          validFromUtc: dayAt(-1),
          validUntilUtc: dayAt(90),
          reason: 'self-service',
        ),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    });
  });
}
