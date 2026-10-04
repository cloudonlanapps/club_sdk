// Verifies the server-side guards aligned in
// club_server PRs #157 (attendance eligibility, INVALID_STATE)
// and #158 (admin-or-organizer authorization, INSUFFICIENT_PERMISSION).
//
// Each test creates a fresh isolated event and uses dedicated role-bound
// clients so we never depend on cross-test state.
import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

void main() {
  group('Workflow 10: Attendance gates', () {
    late SecureClient adminClient;
    late SecureClient organizerClient;
    late SecureClient coachClient;
    late int venueId;

    final now = DateTime.now().toUtc();

    const adminName = 'test_admin_wf10';
    const organizerName = 'test_organizer_wf10';
    const coachName = 'test_coach_wf10';
    const memberName = 'test_member_wf10';

    var eventSlot = 0;

    Future<Event> createUpcomingEventOrganizedBy(String organizer) async {
      // 8-day gaps so concurrent test events don't collide on venue.
      final offset = Duration(days: ++eventSlot * 8);
      final start = now.add(offset);
      return adminClient.events.createEvent(
        title: 'test_WF10 slot$eventSlot',
        description: 'WF10 fixture',
        type: EventType.oneOff,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        organizerName: organizer,
      );
    }

    setUpAll(() async {
      final setup = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: setup,
        username: sudoUsername,
        password: sudoPassword,
      );

      await setup.auth.login(sudoUsername, sudoPassword);

      // `member` is not a role (#27): a user with no roles is a member.
      Future<void> registerWithRole(
        String username,
        String? role, {
        String first = 'WF10',
      }) async {
        await registerAndApprove(
          client: setup,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: 'password123',
          firstName: first,
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        if (role != null) await setup.users.assignRole(username, role);
      }

      await registerWithRole(adminName, 'admin');
      await registerWithRole(organizerName, 'coach');
      await registerWithRole(coachName, 'coach');
      await registerWithRole(memberName, null);

      final venue = await setup.venues.createVenue(name: 'test_Venue WF10');
      venueId = venue.id;

      await setup.auth.logout();

      adminClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await adminClient.auth.login(adminName, 'password123');

      organizerClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await organizerClient.auth.login(organizerName, 'password123');

      coachClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await coachClient.auth.login(coachName, 'password123');
    });

    tearDownAll(() async {
      for (final c in [adminClient, organizerClient, coachClient]) {
        try {
          await c.auth.logout();
        } on Exception {
          /* ignore */
        }
      }
    });

    test(
      'markAttendance for a member never enrolled returns INVALID_STATE',
      () async {
        // Ten minutes out, so the register is open (attendance R12) and the
        // refusal is the enrollment gate, not the not-yet-open one.
        final start = nowUtcMinute().add(const Duration(minutes: 10));
        final event = await adminClient.events.createEvent(
          title: 'test_WF10 never enrolled',
          description: 'WF10 fixture',
          type: EventType.oneOff,
          venueId: venueId,
          visibility: Visibility.public,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          organizerName: organizerName,
        );
        final occTime = event.startTimeUtc;

        await expectLater(
          () => organizerClient.attendance.markAttendance(
            event.id,
            occTime,
            const [
              AttendanceMarkRecord(
                membername: memberName,
                status: AttendanceStatus.present,
              ),
            ],
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidState,
            ),
          ),
        );
      },
    );

    test(
      'markAttendance by a non-organizer coach returns INSUFFICIENT_PERMISSION',
      () async {
        final event = await createUpcomingEventOrganizedBy(organizerName);
        final occTime = event.startTimeUtc;
        await adminClient.enrollments.assign(
          event.id,
          memberName,
        );

        await expectLater(
          () => coachClient.attendance.markAttendance(
            event.id,
            occTime,
            const [
              AttendanceMarkRecord(
                membername: memberName,
                status: AttendanceStatus.present,
              ),
            ],
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.insufficientPermission,
            ),
          ),
        );
      },
    );

    test(
      'approveLeave by a non-organizer coach returns INSUFFICIENT_PERMISSION',
      () async {
        final event = await createUpcomingEventOrganizedBy(organizerName);
        final occTime = event.startTimeUtc;
        await adminClient.enrollments.assign(
          event.id,
          memberName,
        );

        await expectLater(
          () => coachClient.attendance.approveLeave(
            event.id,
            memberName,
            occTime,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.insufficientPermission,
            ),
          ),
        );
      },
    );

    test(
      'rejectLeave by a non-organizer coach returns INSUFFICIENT_PERMISSION',
      () async {
        final event = await createUpcomingEventOrganizedBy(organizerName);
        final occTime = event.startTimeUtc;
        await adminClient.enrollments.assign(
          event.id,
          memberName,
        );

        await expectLater(
          () => coachClient.attendance.rejectLeave(
            event.id,
            memberName,
            occTime,
          ),
          throwsA(
            isA<ServerException>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.insufficientPermission,
            ),
          ),
        );
      },
    );
  });
}
