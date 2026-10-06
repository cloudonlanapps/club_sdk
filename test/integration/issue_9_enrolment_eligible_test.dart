import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/age_dates.dart';
import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 9: an enrolment row reports `eligible` (club_server#19): false
/// while the member is enrolled and no longer meets the event's gender or
/// age window. Nobody is removed automatically.
void main() {
  group('Issue 9: enrolment eligible', () {
    late SecureClient adminClient;
    late SecureClient memberClient;
    late int eventId;

    const password = 'password123';
    const member = 'test_i9_member';
    const other = 'test_i9_other';
    const invited = 'test_i9_invited';

    final insideBand = bornAgo(years: 12, months: 6);

    Future<void> register(String username) async {
      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: 'User $username',
        phone: '0000000009',
        gender: Gender.male,
        dateOfBirthUtc: insideBand,
      );
    }

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await adminClient.auth.login(sudoUsername, sudoPassword);
      expect((await adminClient.auth.getCurrentUser()).username, sudoUsername);

      await register(member);
      await register(other);
      await register(invited);

      // A camp for ages 10 to 14, strictly, with two members assigned and a
      // third invited. A camp, not a programme: where the credit system is
      // on, assigning to a programme needs credit, and the flag is the same
      // on every event type.
      final venue = await adminClient.venues.createVenue(name: 'test_i9_venue');
      final now = DateTime.now().toUtc();
      final start = DateTime.utc(now.year, now.month, now.day + 7, 6);
      final camp = await adminClient.events.createEvent(
        title: 'test_i9_camp',
        description: 'enrolment eligibility',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=3',
        minAge: const Age(years: 10),
        maxAge: const Age(years: 14),
        strictAge: true,
      );
      eventId = camp.id;
      await adminClient.enrollments.assign(eventId, member);
      await adminClient.enrollments.assign(eventId, other);
      await adminClient.enrollments.invite(eventId, invited);

      memberClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await memberClient.auth.login(member, password);
      expect((await memberClient.auth.getCurrentUser()).username, member);
    });

    tearDownAll(() async {
      await memberClient.auth.logout();
      await adminClient.auth.logout();
    });

    test('Issue 9: an assigned member inside the window is read with '
        'eligible true', () async {
      final rows = await adminClient.enrollments.listEnrollmentsDetailed(
        eventId,
      );
      expect(rows[member]!.status, EnrollmentStatus.assigned);
      expect(rows[member]!.eligible, isTrue);
      expect(rows[other]!.eligible, isTrue);

      final mine = await memberClient.myEvents.getMyEnrollment(member, eventId);
      expect(mine.status, EnrollmentStatus.assigned);
      expect(mine.eligible, isTrue);
    });

    test('Issue 9: a member whose date of birth is corrected to one outside '
        'the window stays enrolled and is read with eligible false, in the '
        "event's list and in their own enrolment", () async {
      await adminClient.users.updateUser(
        member,
        dateOfBirthUtc: () => bornAgo(years: 20),
      );
      addTearDown(
        () => adminClient.users.updateUser(
          member,
          dateOfBirthUtc: () => insideBand,
        ),
      );

      final rows = await adminClient.enrollments.listEnrollmentsDetailed(
        eventId,
      );
      expect(rows[member]!.status, EnrollmentStatus.assigned);
      expect(rows[member]!.eligible, isFalse);
      expect(rows[other]!.eligible, isTrue, reason: 'only that member');

      final mine = await memberClient.myEvents.getMyEnrollment(member, eventId);
      expect(mine.status, EnrollmentStatus.assigned);
      expect(mine.eligible, isFalse);
    });

    test('Issue 9: a member who matches again is read with eligible '
        'true', () async {
      await adminClient.users.updateUser(
        member,
        dateOfBirthUtc: () => bornAgo(years: 20),
      );
      final flagged = await memberClient.myEvents.getMyEnrollment(
        member,
        eventId,
      );
      expect(flagged.eligible, isFalse);

      await adminClient.users.updateUser(
        member,
        dateOfBirthUtc: () => insideBand,
      );
      final rows = await adminClient.enrollments.listEnrollmentsDetailed(
        eventId,
      );
      expect(rows[member]!.eligible, isTrue);
      final mine = await memberClient.myEvents.getMyEnrollment(member, eventId);
      expect(mine.eligible, isTrue);
    });

    test('Issue 9: a row that is not an active enrolment is eligible '
        'whatever the window', () async {
      await adminClient.users.updateUser(
        invited,
        dateOfBirthUtc: () => bornAgo(years: 20),
      );

      final rows = await adminClient.enrollments.listEnrollmentsDetailed(
        eventId,
      );
      expect(rows[invited]!.status, EnrollmentStatus.invited);
      expect(rows[invited]!.eligible, isTrue);
    });
  });
}
