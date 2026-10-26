import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/credit_seed.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 34: every event response carries the server's `isPast` and
/// `hasEnded` (club_server#53, lifecycle L24), and the SDK gates read them.
/// `canEnrollOnEvent` follows `hasEnded`, the server's join guard
/// (`check_event_joinable`, 422 `INVALID_STATE`), so for a regular admin
/// the gate and the server's answer to an assign agree.
///
/// No endpoint creates an event in the past, so the cases that need time
/// to have passed (a finished one-off, a camp after its last day, a
/// programme years in) are covered by the server's own suite
/// (`test_event_response_lifecycle_flags.py`) and the unit tests. These
/// cases end an event early through the API instead.
void main() {
  group('Issue 34: the server lifecycle flags drive the gates', () {
    late SecureClient sudo;
    late SecureClient admin;
    late UserPrivate adminUser;
    var seq = 0;

    const adminName = 'test_i34_admin';
    const password = 'password123';
    final members = [for (var i = 1; i <= 6; i++) 'test_i34_member$i'];

    Matcher throwsInvalidState() => throwsA(
      isA<ServerException>().having(
        (e) => e.code,
        'code',
        SdkErrorCode.invalidState,
      ),
    );

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      for (final name in [adminName, ...members]) {
        await registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: password,
          phone: '+919000000034',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
      }
      await sudo.users.assignRole(adminName, 'admin');
      // Where the credit system is on, the server credit-gates assign and
      // assign-trial (credit R35), so every member gets general and
      // trial credit up front; a refused assign is then refused for the
      // event's state alone. A no-op where the module is off (#62).
      await seedEnrolmentCreditIfGated(sudo, members);

      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await admin.auth.login(adminName, password);
      adminUser = await admin.auth.getCurrentUser();
      expect(adminUser.username, adminName);
      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.isSuperAdmin, isFalse);
    });

    tearDownAll(() async {
      await admin.auth.logout();
      await sudo.auth.logout();
    });

    /// Each event gets its own venue, day and hour, so none clash: they
    /// share sudo as organizer, and an open-ended programme repeats weekly
    /// (club_server#72, #56).
    Future<Event> create(
      EventType type, {
      String? rrule,
      int days = 3,
    }) async {
      final n = ++seq;
      final start = dayAt(days + 2 * n, hour: 6 + n);
      final venue = await sudo.venues.createVenue(name: 'test_Venue I34 $n');
      return sudo.events.createEvent(
        title: 'test_I34 $n',
        description: '',
        type: type,
        visibility: Visibility.public,
        venueId: venue.id,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: rrule ?? (type == EventType.programme ? weeklyOn(start) : null),
      );
    }

    test('Issue 34: a one-off ahead is neither past nor ended, and the '
        'server accepts an assign', () async {
      final created = await create(EventType.oneOff);
      final event = await admin.events.getEvent(created.id);
      expect(event.isPast, isFalse);
      expect(event.hasEnded, isFalse);
      expect(isPastEvent(event), isFalse);
      expect(canEnrollOnEvent(event, adminUser), isTrue);

      await admin.enrollments.assign(event.id, members[0]);
      final enrolled = await admin.enrollments.getEnrollment(
        event.id,
        members[0],
      );
      expect(enrolled.status, EnrollmentStatus.assigned);
    });

    test('Issue 34: an open-ended programme is neither past nor ended, and '
        'the server accepts an assign-trial', () async {
      final created = await create(EventType.programme);
      final event = await admin.events.getEvent(created.id);
      expect(event.isPast, isFalse);
      expect(event.hasEnded, isFalse);
      expect(canAssignTrial(event, adminUser), isTrue);

      await admin.enrollments.assignTrial(event.id, members[1]);
      final enrolled = await admin.enrollments.getEnrollment(
        event.id,
        members[1],
      );
      expect(enrolled.status, EnrollmentStatus.assignedTrial);
    });

    test('Issue 34: a dropped one-off has ended but is not past, and the '
        'server refuses an assign', () async {
      final created = await create(EventType.oneOff);
      await sudo.events.drop(
        created.id,
        version: await occurrenceVersion(
          sudo,
          created.id,
          created.startTimeUtc,
        ),
        reason: 'no ice',
      );
      final event = await admin.events.getEvent(created.id);
      expect(event.isPast, isFalse);
      expect(event.hasEnded, isTrue);
      expect(isPastEvent(event), isFalse);
      expect(canEnrollOnEvent(event, adminUser), isFalse);

      await expectLater(
        admin.enrollments.assign(event.id, members[2]),
        throwsInvalidState(),
      );
    });

    test('Issue 34: a programme terminated at its first session has ended '
        'while its cutoff is still ahead; the gate follows the server, '
        'not the local approximation', () async {
      final created = await create(EventType.programme, days: 10);
      final terminated = await sudo.events.terminate(
        created.id,
        version: created.version,
        reason: 'not enough players',
        // A cutoff must fall on an occurrence start; at the first one,
        // every occurrence is cancelled while the cutoff is still ahead.
        cutoffTimeUtc: created.startTimeUtc,
      );
      expect(terminated.untilTimeUtc, created.startTimeUtc);

      final event = await admin.events.getEvent(created.id);
      expect(event.isPast, isFalse);
      expect(event.hasEnded, isTrue);
      // Without the server flags the gate would let the admin through: the
      // cutoff is ahead, so the series does not read as cancelled yet.
      final local = event.copyWith(isPast: () => null, hasEnded: () => null);
      expect(isEventSeriesCancelled(local), isFalse);
      expect(canEnrollOnEvent(local, adminUser), isTrue);
      expect(canEnrollOnEvent(event, adminUser), isFalse);
      expect(canAssignTrial(event, adminUser), isFalse);

      await expectLater(
        admin.enrollments.assign(event.id, members[3]),
        throwsInvalidState(),
      );
    });

    test('Issue 34: a camp with every remaining day cancelled has ended but '
        'is not past, and the server refuses an assign', () async {
      final created = await create(
        EventType.camp,
        rrule: 'FREQ=DAILY;COUNT=2',
      );
      for (final slot in [
        created.startTimeUtc,
        created.startTimeUtc.add(const Duration(days: 1)),
      ]) {
        await sudo.occurrences.cancelOccurrence(
          created.id,
          slot,
          version: await occurrenceVersion(sudo, created.id, slot),
          reason: 'rink closed',
        );
      }
      final event = await admin.events.getEvent(created.id);
      expect(event.isPast, isFalse);
      expect(event.hasEnded, isTrue);
      expect(isPastEvent(event), isFalse);
      expect(canEnrollOnEvent(event, adminUser), isFalse);

      await expectLater(
        admin.enrollments.assign(event.id, members[4]),
        throwsInvalidState(),
      );
    });

    test('Issue 34: the event listing carries both flags', () async {
      final created = await create(EventType.oneOff);
      final page = await admin.events.listEvents(venueId: created.venueId);
      final listed = page.items.singleWhere((e) => e.id == created.id);
      expect(listed.isPast, isFalse);
      expect(listed.hasEnded, isFalse);
    });
  });
}
