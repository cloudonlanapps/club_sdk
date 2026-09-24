import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 6: the SDK reads the fields club_server has always sent and the SDK
/// used to drop: an occurrence's `venueName` and `organizerDisplayName`, a
/// group's `memberCount`, and the members `getGroup` sends inline.
void main() {
  group('Issue 6: response fields the SDK used to drop', () {
    late SecureClient admin;
    late SecureClient member;
    late int venueId;
    final opened = <SecureClient>[];
    const venueName = 'test_Venue I6 Main Rink';
    const organizer = 'test_i6_org';
    const memberA = 'test_i6_amy';
    const memberB = 'test_i6_bo';
    const password = 'password123';

    Future<void> register(String username, String first, String last) =>
        registerAndApprove(
          client: admin,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: password,
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.female,
          firstName: first,
          lastName: last,
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
      venueId = (await admin.venues.createVenue(name: venueName)).id;
      await register(organizer, 'Olive', 'Organiser');
      await register(memberA, 'Amy', 'Adams');
      await register(memberB, 'Bo', 'Brown');
      member = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(member);
      await member.auth.login(memberA, password);
      expect((await member.auth.getCurrentUser()).username, memberA);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      for (final c in opened) {
        try {
          await c.auth.logout();
        } on Exception {
          /* already out */
        }
      }
    });

    group('occurrence', () {
      test("carries its venue's name and its organizer's public display "
          'name', () async {
        final start = dayAt(12);
        final event = await admin.events.createEvent(
          title: 'test_I6 one-off',
          description: '',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          organizerName: organizer,
        );

        // Not shown publicly (the default): the placeholder, never the
        // real name — the staff view's full name must not leak here.
        final private = await admin.users.getUserPrivate(organizer);
        expect(private.useNamePublicly, isFalse);
        final occ = await admin.occurrences.getOccurrence(event.id, start);
        expect(occ.venueName, venueName);
        expect(occ.organizerName, organizer);
        expect(occ.organizerDisplayName, 'Name not provided');
        expect(
          occ.organizerDisplayName,
          computePublicDisplayName(useNamePublicly: false),
        );

        // Shown publicly: the real name, from the listing too.
        await admin.users.updateUser(organizer, useNamePublicly: true);
        final listed = await admin.occurrences.listOccurrences(
          fromTimeUtc: start.subtract(const Duration(minutes: 1)),
          toTimeUtc: start.add(const Duration(minutes: 1)),
        );
        final same = listed.singleWhere((o) => o.eventId == event.id);
        expect(same.venueName, venueName);
        expect(same.organizerDisplayName, 'Olive Organiser');
        expect(
          same.organizerDisplayName,
          computePublicDisplayName(
            useNamePublicly: true,
            firstName: 'Olive',
            lastName: 'Organiser',
          ),
        );
      });

      test('a member sees the same names on their own occurrence', () async {
        final start = dayAt(13);
        final event = await admin.events.createEvent(
          title: 'test_I6 camp',
          description: '',
          type: EventType.camp,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          rrule: 'FREQ=DAILY;COUNT=2',
          organizerName: organizer,
        );
        await admin.enrollments.assign(event.id, memberA);

        final staff = await admin.occurrences.getOccurrence(event.id, start);
        final own = await member.myEvents.getMyOccurrence(
          memberA,
          event.id,
          start,
        );
        expect(own.venueName, venueName);
        expect(own.venueName, staff.venueName);
        expect(own.organizerDisplayName, staff.organizerDisplayName);
        expect(own.organizerDisplayName, isNotNull);
      });
    });

    group('group', () {
      test('memberCount follows adds and removes', () async {
        final created = await admin.groups.createGroup(name: 'test_I6 count');
        expect(created.memberCount, 0);

        await admin.groups.addMember(created.id, memberA);
        await admin.groups.addMember(created.id, memberB);
        final listed = (await admin.groups.getGroups(
          limit: 100,
        )).items.singleWhere((g) => g.id == created.id);
        expect(listed.memberCount, 2);
        expect(listed.members, isNull, reason: 'listings send no members');

        await admin.groups.removeMember(created.id, memberB);
        final after = (await admin.groups.getGroups(
          limit: 100,
        )).items.singleWhere((g) => g.id == created.id);
        expect(after.memberCount, 1);
      });

      test("a member's own group listing carries the same count", () async {
        final created = await admin.groups.createGroup(name: 'test_I6 mine');
        await admin.groups.addMember(created.id, memberA);
        await admin.groups.addMember(created.id, memberB);

        final mine = await member.myGroups.listGroups(memberA);
        final same = mine.singleWhere((g) => g.id == created.id);
        expect(same.memberCount, 2);
      });

      test(
        'getGroup returns the members inline, matching getMembers',
        () async {
          final created = await admin.groups.createGroup(
            name: 'test_I6 detail',
          );
          await admin.groups.addMember(created.id, memberA);
          await admin.groups.addMember(created.id, memberB);

          final detail = await admin.groups.getGroup(created.id);
          expect(detail.members, isNotNull);
          expect(
            detail.members!.map((m) => m.membername),
            unorderedEquals([memberA, memberB]),
          );
          final amy = detail.members!.singleWhere(
            (m) => m.membername == memberA,
          );
          expect(amy.firstName, 'Amy');
          expect(amy.lastName, 'Adams');
          expect(detail.memberCount, 2);

          final separately = await admin.groups.getMembers(created.id);
          expect(
            detail.members!.toSet(),
            separately.toSet(),
            reason: 'the inline list is the same list getMembers returns',
          );
        },
      );
    });
  });
}
