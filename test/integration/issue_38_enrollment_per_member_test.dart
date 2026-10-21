import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

const _password = 'password123';
const _admin = 'test_admin_i38';
const _coach = 'test_coach_i38';
const _enrolled = 'test_enrolled_i38';
const _other = 'test_other_i38';

/// Issue 38: getEnrollment and getEnrollmentStatus read one member's
/// enrollment through the per-member route
/// (`GET /myevents/by_id/{username}/{eventId}/enrollments`), which a member
/// may read for themself and staff for anyone.
void main() {
  group('Issue 38: the per-member enrollment route', () {
    late SecureClient adminClient;
    late SecureClient coachClient;
    late SecureClient enrolledClient;
    late SecureClient otherClient;
    late int eventId;

    setUpAll(() async {
      final setup = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: setup,
        username: sudoUsername,
        password: sudoPassword,
      );
      await setup.auth.login(sudoUsername, sudoPassword);

      Future<void> register(String username, {String? role}) async {
        await registerAndApprove(
          client: setup,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: _password,
          firstName: 'I38',
          phone: '0000000000',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
        );
        if (role != null) await setup.users.assignRole(username, role);
      }

      await register(_admin, role: 'admin');
      await register(_coach, role: 'coach');
      await register(_enrolled);
      await register(_other);
      // Where the credit system is on, joining a programme needs usable
      // credit; elsewhere this does nothing.
      await seedEnrolmentCreditIfGated(setup, [_enrolled, _other]);

      final venue = await setup.venues.createVenue(name: 'test_Venue I38');
      final start = dayAt(30);
      final event = await setup.events.createEvent(
        title: 'test_Programme I38',
        description: 'I38 fixture',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
      eventId = event.id;
      await setup.enrollments.assign(eventId, _enrolled);
      await setup.auth.logout();

      Future<SecureClient> loggedIn(String username) async {
        final c = await createRemoteSecureClient(baseUrl: baseUrl);
        await c.auth.login(username, _password);
        expect((await c.auth.getCurrentUser()).username, username);
        return c;
      }

      adminClient = await loggedIn(_admin);
      coachClient = await loggedIn(_coach);
      enrolledClient = await loggedIn(_enrolled);
      otherClient = await loggedIn(_other);
    });

    tearDownAll(() async {
      for (final c in [adminClient, coachClient, enrolledClient, otherClient]) {
        try {
          await c.auth.logout();
        } on Exception {
          /* ignore */
        }
      }
    });

    Matcher serverError(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code),
    );

    test(
      'Issue 38: the assigned member is on the roster as assigned',
      () async {
        final roster = await adminClient.enrollments.listEnrollments(eventId);
        expect(roster[_enrolled], EnrollmentStatus.assigned);
        expect(roster.containsKey(_other), isFalse);
      },
    );

    test('Issue 38: an admin reads an enrolled member record', () async {
      final e = await adminClient.enrollments.getEnrollment(eventId, _enrolled);
      expect(e.membername, _enrolled);
      expect(e.eventId, eventId);
      expect(e.status, EnrollmentStatus.assigned);
    });

    test('Issue 38: an admin reads an enrolled member status', () async {
      expect(
        await adminClient.enrollments.getEnrollmentStatus(eventId, _enrolled),
        EnrollmentStatus.assigned,
      );
    });

    test('Issue 38: an admin reading a member with no enrollment gets '
        'ENROLLMENT_NOT_FOUND', () async {
      await expectLater(
        adminClient.enrollments.getEnrollment(eventId, _other),
        serverError(404, SdkErrorCode.enrollmentNotFound),
      );
    });

    test('Issue 38: an admin reading the status of a member with no '
        'enrollment gets null', () async {
      expect(
        await adminClient.enrollments.getEnrollmentStatus(eventId, _other),
        isNull,
      );
    });

    test('Issue 38: a coach reads any member record', () async {
      final e = await coachClient.enrollments.getEnrollment(eventId, _enrolled);
      expect(e.membername, _enrolled);
      expect(e.status, EnrollmentStatus.assigned);
    });

    test('Issue 38: a member reads their own record and status', () async {
      final e = await enrolledClient.enrollments.getEnrollment(
        eventId,
        _enrolled,
      );
      expect(e.membername, _enrolled);
      expect(e.status, EnrollmentStatus.assigned);
      expect(
        await enrolledClient.enrollments.getEnrollmentStatus(
          eventId,
          _enrolled,
        ),
        EnrollmentStatus.assigned,
      );
    });

    test(
      'Issue 38: a member reading another member record is refused',
      () async {
        await expectLater(
          otherClient.enrollments.getEnrollment(eventId, _enrolled),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );

    test(
      'Issue 38: a member reading another member status is refused',
      () async {
        await expectLater(
          otherClient.enrollments.getEnrollmentStatus(eventId, _enrolled),
          throwsA(
            isA<ServerException>().having(
              (e) => e.statusCode,
              'statusCode',
              403,
            ),
          ),
        );
      },
    );
  });
}
