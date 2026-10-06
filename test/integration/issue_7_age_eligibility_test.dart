import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/age_dates.dart';
import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 7: eligibility on events and groups is an age band (club_server#16):
/// `minAge`, `maxAge` and `strictAge`. The server works out the window of
/// birth dates on a reference day and reports both. A semi-auto member who
/// no longer matches is kept and read with `eligible: false`
/// (club_server#17).
void main() {
  group('Issue 7: age-based eligibility', () {
    late SecureClient client;
    late int venueId;

    const member = 'test_i7_member';

    /// [day] less [years] and [months], landing on the last day of a shorter
    /// month, the way the server counts an age back (eligibility R9).
    DateTime ageBefore(DateTime day, {required int years, int months = 0}) {
      final first = DateTime.utc(day.year - years, day.month - months);
      final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
      return DateTime.utc(
        first.year,
        first.month,
        day.day > lastDay ? lastDay : day.day,
      );
    }

    DateTime addDays(DateTime day, int days) =>
        DateTime.utc(day.year, day.month, day.day + days);

    setUpAll(() async {
      client = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: client,
        username: sudoUsername,
        password: sudoPassword,
      );
      await client.auth.login(sudoUsername, sudoPassword);
      expect((await client.auth.getCurrentUser()).username, sudoUsername);

      await registerAndApprove(
        client: client,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: member,
        email: '$member@test.com',
        password: 'password123',
        firstName: 'Seven',
        phone: '0000000007',
        gender: Gender.male,
        dateOfBirthUtc: bornAgo(years: 12, months: 6),
      );
      final venue = await client.venues.createVenue(name: 'test_i7_venue');
      venueId = venue.id;
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    group('groups', () {
      test('Issue 7: a group created with ages reports them and the '
          "server's strict window, counted today", () async {
        final group = await client.groups.createGroup(
          name: 'test_i7_strict',
          minAge: const Age(years: 10),
          maxAge: const Age(years: 14, months: 6),
          strictAge: true,
        );

        expect(group.kind, GroupKind.auto);
        expect(group.minAge, const Age(years: 10));
        expect(group.maxAge, const Age(years: 14, months: 6));
        expect(group.strictAge, isTrue);

        // The reference day is the club's today: UTC's, or the day after.
        final today = group.eligibilityReferenceDayUtc!;
        final utcNow = DateTime.now().toUtc();
        expect(
          today.difference(DateTime.utc(utcNow.year, utcNow.month, utcNow.day)),
          anyOf(Duration.zero, const Duration(days: 1)),
        );
        expect(
          group.dobOnOrAfterUtc,
          ageBefore(today, years: 14, months: 6),
        );
        expect(group.dobOnOrBeforeUtc, ageBefore(today, years: 10));

        final read = await client.groups.getGroup(group.id);
        expect(read.minAge, const Age(years: 10));
        expect(read.maxAge, const Age(years: 14, months: 6));
        expect(read.strictAge, isTrue);
        expect(read.dobOnOrAfterUtc, group.dobOnOrAfterUtc);
        expect(read.dobOnOrBeforeUtc, group.dobOnOrBeforeUtc);
        expect(read.eligibilityReferenceDayUtc, today);
      });

      test('Issue 7: a relaxed band is a year less a day wider at each '
          'end', () async {
        final group = await client.groups.createGroup(
          name: 'test_i7_relaxed',
          minAge: const Age(years: 10),
          maxAge: const Age(years: 14),
        );

        expect(group.strictAge, isFalse);
        final today = group.eligibilityReferenceDayUtc!;
        expect(
          group.dobOnOrAfterUtc,
          addDays(ageBefore(today, years: 15), 1),
        );
        expect(
          group.dobOnOrBeforeUtc,
          addDays(ageBefore(today, years: 9), -1),
        );
      });

      test('Issue 7: an update changes a bound, clears the other and sets '
          'strict', () async {
        final group = await client.groups.createGroup(
          name: 'test_i7_update',
          minAge: const Age(years: 10),
          maxAge: const Age(years: 14),
        );

        final updated = await client.groups.updateGroup(
          group.id,
          minAge: () => const Age(years: 11),
          maxAge: () => null,
          strictAge: true,
        );
        expect(updated.minAge, const Age(years: 11));
        expect(updated.maxAge, isNull);
        expect(updated.strictAge, isTrue);
        expect(updated.dobOnOrAfterUtc, isNull);
        expect(
          updated.dobOnOrBeforeUtc,
          ageBefore(updated.eligibilityReferenceDayUtc!, years: 11),
        );

        // An update that leaves the band out keeps it.
        final renamed = await client.groups.updateGroup(
          group.id,
          name: 'test_i7_update_renamed',
        );
        expect(renamed.minAge, const Age(years: 11));
        expect(renamed.maxAge, isNull);
        expect(renamed.strictAge, isTrue);
      });

      test('Issue 7: a minimum age above the maximum is refused '
          '(422 INVALID_STATE)', () async {
        await expectLater(
          client.groups.createGroup(
            name: 'test_i7_inverted',
            minAge: const Age(years: 14),
            maxAge: const Age(years: 10),
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 422)
                .having((e) => e.code, 'code', SdkErrorCode.invalidState),
          ),
        );
        final groups = await client.groups.getGroups(limit: 100);
        expect(
          groups.items.map((g) => g.name),
          isNot(contains('test_i7_inverted')),
        );
      });

      test('Issue 7: a semi-auto member outside the band is kept and read '
          'with eligible false', () async {
        final group = await client.groups.createGroup(
          name: 'test_i7_semi',
          minAge: const Age(years: 10),
          maxAge: const Age(years: 14),
          strictAge: true,
          semiAuto: true,
        );
        expect(group.kind, GroupKind.semiAuto);
        await client.groups.addMember(group.id, member);

        var members = await client.groups.getMembers(group.id);
        expect(members.single.membername, member);
        expect(members.single.eligible, isTrue);
        var detail = await client.groups.getGroup(group.id);
        expect(detail.ineligibleMemberCount, 0);
        expect(detail.members!.single.eligible, isTrue);

        // The member's date of birth is corrected to one outside the band.
        await client.users.updateUser(
          member,
          dateOfBirthUtc: () => bornAgo(years: 20),
        );
        addTearDown(
          () => client.users.updateUser(
            member,
            dateOfBirthUtc: () => bornAgo(years: 12, months: 6),
          ),
        );

        members = await client.groups.getMembers(group.id);
        expect(members.single.membername, member);
        expect(members.single.eligible, isFalse);
        detail = await client.groups.getGroup(group.id);
        expect(detail.ineligibleMemberCount, 1);
        expect(detail.members!.single.eligible, isFalse);
        final listed = await client.groups.getGroups(limit: 100);
        final row = listed.items.singleWhere((g) => g.id == group.id);
        expect(row.memberCount, 1);
        expect(row.ineligibleMemberCount, 1);

        // Back inside the band, the member is eligible again.
        await client.users.updateUser(
          member,
          dateOfBirthUtc: () => bornAgo(years: 12, months: 6),
        );
        members = await client.groups.getMembers(group.id);
        expect(members.single.eligible, isTrue);
        detail = await client.groups.getGroup(group.id);
        expect(detail.ineligibleMemberCount, 0);
      });
    });

    group('events', () {
      // 06:00 UTC is the same calendar day in UTC and in the club's zone.
      DateTime startIn(int days) {
        final now = DateTime.now().toUtc();
        return DateTime.utc(now.year, now.month, now.day + days, 6);
      }

      Future<Event> createOneOff(
        String title,
        DateTime start, {
        Age? minAge,
        Age? maxAge,
        bool? strictAge,
      }) {
        return client.events.createEvent(
          title: title,
          description: 'age-based eligibility',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          minAge: minAge,
          maxAge: maxAge,
          strictAge: strictAge,
        );
      }

      test('Issue 7: an event created with ages reports them and the '
          "server's window, counted on the day it starts", () async {
        final start = startIn(10);
        final startDay = DateTime.utc(start.year, start.month, start.day);
        final event = await createOneOff(
          'test_i7_event_strict',
          start,
          minAge: const Age(years: 8),
          maxAge: const Age(years: 14, months: 6),
          strictAge: true,
        );

        expect(event.minAge, const Age(years: 8));
        expect(event.maxAge, const Age(years: 14, months: 6));
        expect(event.strictAge, isTrue);
        expect(event.eligibilityReferenceDayUtc, startDay);
        expect(
          event.dobOnOrAfterUtc,
          ageBefore(startDay, years: 14, months: 6),
        );
        expect(event.dobOnOrBeforeUtc, ageBefore(startDay, years: 8));

        final read = await client.events.getEvent(event.id);
        expect(read.minAge, const Age(years: 8));
        expect(read.maxAge, const Age(years: 14, months: 6));
        expect(read.strictAge, isTrue);
        expect(read.eligibilityReferenceDayUtc, startDay);
        expect(read.dobOnOrAfterUtc, event.dobOnOrAfterUtc);
        expect(read.dobOnOrBeforeUtc, event.dobOnOrBeforeUtc);
      });

      test('Issue 7: an event with no band reports no ages and no '
          'window', () async {
        final start = startIn(12);
        final event = await createOneOff('test_i7_event_open', start);

        expect(event.minAge, isNull);
        expect(event.maxAge, isNull);
        expect(event.strictAge, isFalse);
        expect(event.dobOnOrAfterUtc, isNull);
        expect(event.dobOnOrBeforeUtc, isNull);
        expect(
          event.eligibilityReferenceDayUtc,
          DateTime.utc(start.year, start.month, start.day),
        );
      });

      test('Issue 7: the users eligible for an event are those inside its '
          'window', () async {
        final inside = await createOneOff(
          'test_i7_event_inside',
          startIn(14),
          minAge: const Age(years: 10),
          maxAge: const Age(years: 14),
          strictAge: true,
        );
        final outside = await createOneOff(
          'test_i7_event_outside',
          startIn(16),
          minAge: const Age(years: 16),
          strictAge: true,
        );

        final admitted = await client.events.listEligible(inside.id);
        expect(admitted.map((u) => u.username), contains(member));
        final refused = await client.events.listEligible(outside.id);
        expect(refused.map((u) => u.username), isNot(contains(member)));
      });

      test('Issue 7: an update changes a bound, clears the other and sets '
          'strict', () async {
        final event = await createOneOff(
          'test_i7_event_update',
          startIn(18),
          minAge: const Age(years: 8),
          maxAge: const Age(years: 12),
        );
        expect(event.strictAge, isFalse);

        final updated = await client.events.updateEvent(
          event.id,
          version: event.version,
          minAge: () => null,
          maxAge: () => const Age(years: 13, months: 3),
          strictAge: true,
        );
        expect(updated.minAge, isNull);
        expect(updated.maxAge, const Age(years: 13, months: 3));
        expect(updated.strictAge, isTrue);
        expect(updated.dobOnOrBeforeUtc, isNull);
        expect(
          updated.dobOnOrAfterUtc,
          ageBefore(updated.eligibilityReferenceDayUtc!, years: 13, months: 3),
        );

        // An update that leaves the band out keeps it.
        final retitled = await client.events.updateEvent(
          event.id,
          version: updated.version,
          title: 'test_i7_event_update_retitled',
        );
        expect(retitled.minAge, isNull);
        expect(retitled.maxAge, const Age(years: 13, months: 3));
        expect(retitled.strictAge, isTrue);
      });

      test("Issue 7: a programme's band is corrected in place", () async {
        final start = startIn(20);
        final programme = await client.events.createEvent(
          title: 'test_i7_programme',
          description: 'age-based eligibility',
          type: EventType.programme,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: weeklyOn(start),
          maxAge: const Age(years: 12),
        );
        expect(programme.maxAge, const Age(years: 12));

        final corrected = await client.events.correctionOnEvent(
          programme.id,
          version: programme.version,
          minAge: () => const Age(years: 6),
          maxAge: () => null,
          strictAge: true,
        );
        expect(corrected.minAge, const Age(years: 6));
        expect(corrected.maxAge, isNull);
        expect(corrected.strictAge, isTrue);
        expect(corrected.dobOnOrAfterUtc, isNull);
        expect(
          corrected.dobOnOrBeforeUtc,
          ageBefore(corrected.eligibilityReferenceDayUtc!, years: 6),
        );
      });

      test('Issue 7: a minimum age above the maximum is refused '
          '(422 INVALID_STATE)', () async {
        await expectLater(
          createOneOff(
            'test_i7_event_inverted',
            startIn(22),
            minAge: const Age(years: 14),
            maxAge: const Age(years: 10),
          ),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 422)
                .having((e) => e.code, 'code', SdkErrorCode.invalidState),
          ),
        );
      });

      test('Issue 7: the public catalogue reports the band, the window '
          'and the reference day', () async {
        final start = startIn(24);
        final event = await createOneOff(
          'test_i7_event_public',
          start,
          minAge: const Age(years: 8),
          maxAge: const Age(years: 12),
          strictAge: true,
        );

        final anon = await createRemoteSecureClient(baseUrl: baseUrl);
        final catalogue = await anon.public.listPublicEvents(limit: 100);
        final listed = catalogue.items.singleWhere(
          (e) => e.title == 'test_i7_event_public',
        );
        expect(listed.minAge, const Age(years: 8));
        expect(listed.maxAge, const Age(years: 12));
        expect(listed.strictAge, isTrue);
        expect(
          listed.eligibilityReferenceDayUtc,
          event.eligibilityReferenceDayUtc,
        );
        expect(listed.dobOnOrAfterUtc, event.dobOnOrAfterUtc);
        expect(listed.dobOnOrBeforeUtc, event.dobOnOrBeforeUtc);

        final one = await anon.public.getPublicEvent(listed.publicId);
        expect(one, listed);
      });
    });
  });
}
