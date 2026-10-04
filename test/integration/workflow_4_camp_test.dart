// Camp workflow: camp creation requires rrule+daily session times (max 24h
// duration). requestToJoin is self-only — students use their own clients.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Workflow 4: The Public Camp Social Story
///
/// Focus: EventType.camp, Visibility.public, approveRequest()/rejectRequest().
void main() {
  group('Workflow 4: The Public Camp Social Story', () {
    late SecureClient adminClient;
    late SecureClient student1Client;
    late SecureClient student2Client;
    late int venueId;

    setUpAll(() async {
      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: adminClient,
        username: sudoUsername,
        password: sudoPassword,
      );

      await adminClient.auth.login(sudoUsername, sudoPassword);

      // Register and approve admin user
      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_admin_1',
        email: 'test_admin_1@test.com',
        password: 'password123',
        firstName: 'Admin One',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );
      await adminClient.users.assignRole('test_admin_1', 'admin');

      // Register and approve member users
      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_s1',
        email: 'test_s1@test.com',
        password: 'password123',
        firstName: 'Student One',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      await registerAndApprove(
        client: adminClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: 'test_s2',
        email: 'test_s2@test.com',
        password: 'password123',
        firstName: 'Student Two',
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
      );

      // Create venue
      final venue = await adminClient.venues.createVenue(
        name: 'test_Forest Camp',
      );
      venueId = venue.id;

      await adminClient.auth.logout();

      // Create role-specific clients
      student1Client = await createRemoteSecureClient(baseUrl: baseUrl);
      await student1Client.auth.login('test_s1', 'password123');
      final s1User = await student1Client.auth.getCurrentUser();
      expect(s1User.username, 'test_s1');

      student2Client = await createRemoteSecureClient(baseUrl: baseUrl);
      await student2Client.auth.login('test_s2', 'password123');
      final s2User = await student2Client.auth.getCurrentUser();
      expect(s2User.username, 'test_s2');

      // Login admin client for tests
      await adminClient.auth.login('test_admin_1', 'password123');
      final adminUser = await adminClient.auth.getCurrentUser();
      expect(adminUser.username, 'test_admin_1');
    });

    tearDownAll(() async {
      try {
        await student1Client.auth.logout();
      } on Exception {
        // ignore
      }
      try {
        await student2Client.auth.logout();
      } on Exception {
        // ignore
      }
      try {
        await adminClient.auth.logout();
      } on Exception {
        // ignore
      }
    });

    test('Full Public Camp Social Execution', () async {
      // Server enforces max 24h session duration. For multi-day camps,
      // use daily session times + rrule.
      // Inside the scheduling horizon and still ahead, so join requests
      // find a live occurrence (#16).
      final campStart = dayAt(30, hour: 9);
      final campEnd = dayAt(30, hour: 17);

      const student1 = 'test_s1';
      const student2 = 'test_s2';

      // --- T0: Creation ---
      final event = await adminClient.events.createEvent(
        title: 'test_Survival Skills Camp',
        description: '5-day outdoor adventure',
        type: EventType.camp,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: campStart,
        endTimeUtc: campEnd,
        rrule: 'FREQ=DAILY;COUNT=5',
      );

      // --- T1: Browsing & Join Requests ---
      {
        final publicEvents = await adminClient.events.listEvents();
        expect(
          publicEvents.items.any((e) => e.id == event.id),
          isTrue,
          reason: 'Camp should be visible in public list',
        );
      }

      // Students request to join themselves (server enforces self-request)
      await student1Client.myEvents.requestToJoin(
        student1,
        event.id,
      );
      await student2Client.myEvents.requestToJoin(
        student2,
        event.id,
      );

      // --- T2: Approval/Rejection ---
      await adminClient.enrollments.approveRequest(
        event.id,
        student1,
      );
      await adminClient.enrollments.rejectRequest(
        event.id,
        student2,
        reason: 'Capacity reached',
      );

      // Verification: Enrollment results
      final s1Events = await student1Client.myEvents.listMyEvents(student1);
      expect(
        s1Events.items.any((e) => e.id == event.id),
        isTrue,
        reason: 'Approved student should see camp',
      );

      final s2Events = await student2Client.myEvents.listMyEvents(student2);
      expect(
        s2Events.items.any((e) => e.id == event.id),
        isTrue,
        reason: 'Public camp is always visible regardless of enrollment status',
      );
    });
  });
}
