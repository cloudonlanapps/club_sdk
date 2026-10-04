import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// club_server#515: deciding a withdrawal does not delete staff's original
/// enrollment-request notice (`enrollment.rsvp`, outcome `requested`).
///
/// Approving a request already deletes its notice (notifications:R36), so
/// the notice survives to a withdrawal only when the member was enrolled
/// some other way. Here an admin assigns each member directly over their
/// pending request; the member then asks to withdraw, and the admin
/// approves one withdrawal and rejects the other. A dedicated staff user
/// watches its own feed. A one-off needs no credit on either stack.
void main() {
  group('club_server#515: withdrawal decisions keep the request notice', () {
    late SecureClient admin;
    late SecureClient staffClient;
    final memberClients = <String, SecureClient>{};
    late int eventId;

    const password = 'password123';
    const staff = 'test_i515_staff';
    const approvedMember = 'test_i515_approved';
    const rejectedMember = 'test_i515_rejected';

    Future<void> approved(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000515',
      dateOfBirthUtc: DateTime.utc(1995),
      gender: Gender.male,
    );

    /// Every notification [client] holds, newest first.
    Future<List<AppNotification>> feedOf(SecureClient client) async {
      final all = <AppNotification>[];
      const limit = 100;
      for (var offset = 0; ; offset += limit) {
        final page = await client.notifications.getNotifications(
          offset: offset,
          limit: limit,
        );
        all.addAll(page.items);
        if (page.items.length < limit) break;
      }
      return all;
    }

    /// Staff's request notices for [member] on this file's event.
    Future<List<AppNotification>> requestNotices(String member) async {
      final feed = await feedOf(staffClient);
      return feed.where((n) {
        final data = (n.payload['data'] as Map?) ?? const {};
        return n.type == NotificationType.enrollmentRsvp &&
            data['eventId'] == eventId &&
            data['memberUsername'] == member &&
            data['outcome'] == 'requested';
      }).toList();
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);

      await approved(staff);
      await admin.users.assignRole(staff, 'admin');
      for (final m in [approvedMember, rejectedMember]) {
        await approved(m);
      }

      final venue = await admin.venues.createVenue(name: 'test_Venue I515');
      final start = dayAt(2);
      final event = await admin.events.createEvent(
        title: 'test_I515 one-off',
        description: 'I515 fixture',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
      eventId = event.id;

      staffClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await staffClient.auth.login(staff, password);
      expect((await staffClient.auth.getCurrentUser()).username, staff);

      for (final m in [approvedMember, rejectedMember]) {
        final c = await createRemoteSecureClient(baseUrl: baseUrl);
        await c.auth.login(m, password);
        expect((await c.auth.getCurrentUser()).username, m);
        memberClients[m] = c;

        await c.myEvents.requestToJoin(m, eventId);
        expect(await requestNotices(m), hasLength(1));

        await admin.enrollments.assign(eventId, m);
        expect(
          await admin.enrollments.getEnrollmentStatus(eventId, m),
          EnrollmentStatus.assigned,
        );
        // Assigning over the request leaves its notice in place.
        expect(await requestNotices(m), hasLength(1));

        await c.myEvents.withdraw(m, eventId, reason: 'test_i515');
        expect(
          await admin.enrollments.getEnrollmentStatus(eventId, m),
          EnrollmentStatus.withdrawRequested,
        );
      }
    });

    tearDownAll(() async {
      for (final c in [staffClient, ...memberClients.values]) {
        await c.auth.logout();
      }
      await admin.auth.logout();
    });

    test('approving a withdrawal keeps the original request notice', () async {
      await admin.enrollments.approveWithdraw(eventId, approvedMember);
      expect(
        await admin.enrollments.getEnrollmentStatus(eventId, approvedMember),
        EnrollmentStatus.withdrawn,
      );
      expect(await requestNotices(approvedMember), hasLength(1));
    });

    test('rejecting a withdrawal keeps the original request notice', () async {
      await admin.enrollments.rejectWithdraw(eventId, rejectedMember);
      expect(
        await admin.enrollments.getEnrollmentStatus(eventId, rejectedMember),
        EnrollmentStatus.assigned,
      );
      expect(await requestNotices(rejectedMember), hasLength(1));
    });
  });
}
