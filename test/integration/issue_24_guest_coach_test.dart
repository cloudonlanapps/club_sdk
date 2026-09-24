import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/test_client.dart';

/// Issue 24: guest coach accounts and the staff-listing curation
/// (club_server#332).
void main() {
  group('Issue 24: guest coaches', () {
    late SecureClient client;
    const guest = 'test_issue24_guest';

    setUpAll(() async {
      client = await createTestClient();
      await client.auth.login(sudoUsername, sudoPassword);
    });

    tearDownAll(() async {
      await client.auth.logout();
    });

    test(
      'Issue 24: an admin creates a guest, published on their authority',
      () async {
        final created = await client.users.createUser(
          username: guest,
          email: '$guest@example.com',
          passwordHash: 'password123',
          phone: '9000000024',
          dateOfBirthUtc: DateTime.utc(1990),
          gender: Gender.male,
          firstName: 'Visiting',
          lastName: 'Coach',
          status: UserStatus.active,
          isGuest: true,
        );
        expect(created.isGuest, isTrue);
        expect(created.isPublicProfile, isTrue);
        // The server makes a guest a coach at creation.
        expect(created.roles.isCoach, isTrue);

        final info = await client.users.getUserInfo(guest);
        expect(info.isGuest, isTrue);
      },
    );

    test('Issue 24: the staff listing shows the guest row', () async {
      final rows = await client.admin.listStaffListing();
      final row = rows.firstWhere((r) => r.username == guest);
      expect(row.isGuest, isTrue);
      expect(row.isHidden, isFalse);
      expect(row.isPublicProfile, isTrue);
    });

    test('Issue 24: public staff withholds guests unless asked', () async {
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      final guestInfo = await client.users.getUserInfo(guest);
      final without = await anon.public.listPublicStaff();
      expect(
        without.map((p) => p.publicId),
        isNot(contains(guestInfo.publicId)),
      );
      final withGuests = await anon.public.listPublicStaff(includeGuests: true);
      final listed = withGuests.firstWhere(
        (p) => p.publicId == guestInfo.publicId,
      );
      expect(listed.isGuest, isTrue);
    });

    test('Issue 24: curation orders, hides and clears', () async {
      final positioned = await client.admin.setStaffListing(
        guest,
        position: () => 1,
      );
      expect(positioned.position, 1);
      expect(positioned.isGuest, isTrue);

      final hidden = await client.admin.setStaffListing(guest, isHidden: true);
      expect(hidden.isHidden, isTrue);
      final anon = await createRemoteSecureClient(baseUrl: baseUrl);
      final guestInfo = await client.users.getUserInfo(guest);
      final staff = await anon.public.listPublicStaff(includeGuests: true);
      expect(staff.map((p) => p.publicId), isNot(contains(guestInfo.publicId)));

      await client.admin.clearStaffListing(guest);
      final rows = await client.admin.listStaffListing();
      final curated = rows.where(
        (r) =>
            r.username == guest &&
            (r.isGuest || r.isHidden || r.position != null),
      );
      expect(curated, isEmpty);
    });

    test('Issue 24: a regular sign-up is not a guest', () async {
      final info = await client.users.getUserInfo('test_coach_1');
      expect(info.isGuest, isFalse);
    });
  });
}
