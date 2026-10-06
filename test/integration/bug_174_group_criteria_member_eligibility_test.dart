import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/age_dates.dart';
import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Bug #174 — Server: reject group criteria change/clear when existing
/// members become ineligible.
///
/// Server-side contract (club_server #93):
///   * On a semi_auto group, editing the criteria fields must re-evaluate
///     every approved member against the *new* criteria. If any member
///     becomes ineligible, the server rejects the update with 422
///     `MEMBERS_INELIGIBLE` and the group state must remain unchanged.
///   * `semi_auto → manual` (clearing all criteria) is intentionally not
///     validated: a manual group has no rules, so any existing member is
///     trivially eligible.
void main() {
  group('Bug 174: Group criteria edit member-eligibility', () {
    late SecureClient client;

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);

      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );

      await client.auth.login(sudoUsername, sudoPassword);

      // Single approved member used across the three tests. Aged 12 and a
      // half, in the middle of the initial 10-to-14 band, so we have room
      // to both narrow (still in the band) and narrow past them
      // (ineligible) within the same fixture. The age is counted back from
      // today: a group's window moves forward each day (club_server#16).
      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_bug174_member',
        email: 'test_bug174_member@test.com',
        password: 'password123',
        firstName: 'Bug174',
        phone: '0000000000',
        gender: Gender.male,
        dateOfBirthUtc: bornAgo(years: 12, months: 6),
      );

      await client.auth.logout();
    });

    setUp(() async {
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDown(() async {
      try {
        await client.auth.logout();
      } on Exception {
        // Not logged in — ignore.
      }
    });

    /// Creates a fresh semi_auto group admitting ages 10 to 14, strictly,
    /// and adds `test_bug174_member` as an approved member. Each test gets
    /// its own group so we don't leak state across tests.
    Future<Group> createSemiAutoGroupWithMember(String name) async {
      final group = await client.groups.createGroup(
        name: name,
        minAge: const Age(years: 10),
        maxAge: const Age(years: 14),
        strictAge: true,
        semiAuto: true,
      );
      expect(group.kind, GroupKind.semiAuto);
      await client.groups.addMember(group.id, 'test_bug174_member');
      return group;
    }

    test(
      'Issue 174: semi_auto criteria edit rejects when an approved member '
      'becomes ineligible',
      () async {
        final group = await createSemiAutoGroupWithMember('test_bug174_reject');

        // Lower the maximum age to 11 — below the member's 12 and a half
        // → member becomes ineligible → server must reject.
        await expectLater(
          () => client.groups.updateGroup(
            group.id,
            maxAge: () => const Age(years: 11),
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.membersIneligible,
            ),
          ),
        );

        // Group state must be unchanged on rejection.
        final fresh = await client.groups.getGroup(group.id);
        expect(fresh.kind, GroupKind.semiAuto);
        expect(fresh.minAge, const Age(years: 10));
        expect(fresh.maxAge, const Age(years: 14));
        expect(fresh.strictAge, isTrue);
      },
    );

    test(
      'Issue 174: semi_auto criteria edit succeeds when all members still '
      'match the new criteria',
      () async {
        final group = await createSemiAutoGroupWithMember('test_bug174_accept');

        // Lower the maximum age to 13 — still above the member's 12 and a
        // half → member remains eligible → accept.
        final updated = await client.groups.updateGroup(
          group.id,
          maxAge: () => const Age(years: 13),
        );
        expect(updated.kind, GroupKind.semiAuto);
        expect(updated.maxAge, const Age(years: 13));
        expect(updated.minAge, const Age(years: 10));

        // Double-verify via GET.
        final fresh = await client.groups.getGroup(group.id);
        expect(fresh.maxAge, const Age(years: 13));
      },
    );

    test(
      'Issue 174: semi_auto to manual (clearing criteria) succeeds without '
      'eligibility check and retains members',
      () async {
        final group = await createSemiAutoGroupWithMember('test_bug174_clear');

        // Clear every criterion. Manual groups have no rules, so the
        // member's eligibility is moot and the server must accept.
        final updated = await client.groups.updateGroup(
          group.id,
          minAge: () => null,
          maxAge: () => null,
          gender: () => null,
          semiAuto: false,
        );
        expect(updated.kind, GroupKind.manual);
        expect(updated.minAge, isNull);
        expect(updated.maxAge, isNull);
        expect(updated.dobOnOrAfterUtc, isNull);
        expect(updated.dobOnOrBeforeUtc, isNull);
        expect(updated.gender, isNull);

        // Member must still be on the group.
        final members = await client.groups.getMembers(group.id);
        final usernames = members.map((m) => m.membername).toList();
        expect(usernames, contains('test_bug174_member'));
      },
    );
  });
}
