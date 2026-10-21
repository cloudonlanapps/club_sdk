import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 28: the per-occurrence cancel and undo-cancel calls are for camps
/// and programmes (club_server#48, one-off R8a).
///
/// A one-off is called off with `EventSource.drop` and brought back with
/// `EventSource.reinstate`. `cancelOccurrence` and `undoCancelOccurrence`
/// refuse it with 422 `INVALID_STATE`, naming the call to use, and change
/// nothing.
void main() {
  group('Issue 28: occurrence cancel on a one-off', () {
    late SecureClient admin;
    late SecureClient coach;
    late SecureClient member;
    final opened = <SecureClient>[];
    late int venueId;
    const coachName = 'test_i28_coach';
    const memberName = 'test_i28_member';
    const password = 'password123';
    var n = 0;

    /// A one-off organized by [coachName], with [memberName] assigned, far
    /// enough ahead that no lead-time rule applies.
    Future<Event> oneOff() async {
      n += 1;
      final start = dayAt(10 + n);
      final event = await admin.events.createEvent(
        title: 'test_I28 one-off $n',
        description: '',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        organizerName: coachName,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
      await admin.enrollments.assign(event.id, memberName);
      expect(
        await admin.enrollments.getEnrollmentStatus(event.id, memberName),
        EnrollmentStatus.assigned,
      );
      return event;
    }

    Future<void> register(String username) => registerAndApprove(
      client: admin,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      phone: '0000000000',
      dateOfBirthUtc: DateTime.utc(2000),
      gender: Gender.male,
      firstName: username,
    );

    Future<SecureClient> loggedIn(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(c);
      await c.auth.login(username, password);
      expect((await c.auth.getCurrentUser()).username, username);
      return c;
    }

    Matcher refusedNaming(String route) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', SdkErrorCode.invalidState)
          .having((e) => e.message, 'message', contains(route)),
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
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      venueId = (await admin.venues.createVenue(name: 'test_Venue I28')).id;
      await register(coachName);
      await admin.users.assignRole(coachName, 'coach');
      await register(memberName);
      coach = await loggedIn(coachName);
      member = await loggedIn(memberName);
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

    test('Issue 28: an admin cancelling a one-off occurrence is refused, '
        'naming /drop, and it stays scheduled for staff and member', () async {
      final event = await oneOff();
      final t = event.startTimeUtc;

      await expectLater(
        admin.occurrences.cancelOccurrence(
          event.id,
          t,
          version: await occurrenceVersion(admin, event.id, t),
          reason: 'ice',
        ),
        refusedNaming('/drop'),
      );

      final staffView = await admin.occurrences.getOccurrence(event.id, t);
      expect(staffView.status, OccurrenceStatus.scheduled);
      expect(staffView.version, 1);
      final memberView = await member.myEvents.getMyOccurrence(
        memberName,
        event.id,
        t,
      );
      expect(memberView.status, OccurrenceStatus.scheduled);
    });

    test('Issue 28: the organizing coach cancelling a one-off occurrence is '
        'refused the same way', () async {
      final event = await oneOff();
      final t = event.startTimeUtc;

      await expectLater(
        coach.occurrences.cancelOccurrence(
          event.id,
          t,
          version: await occurrenceVersion(coach, event.id, t),
          reason: 'ice',
        ),
        refusedNaming('/drop'),
      );

      final occ = await admin.occurrences.getOccurrence(event.id, t);
      expect(occ.status, OccurrenceStatus.scheduled);
    });

    test('Issue 28: undo-cancel on a dropped one-off is refused, naming '
        '/reinstate, and it stays cancelled', () async {
      final event = await oneOff();
      final t = event.startTimeUtc;
      await admin.events.drop(event.id, version: 1, reason: 'rain');
      final dropped = await admin.occurrences.getOccurrence(event.id, t);
      expect(dropped.status, OccurrenceStatus.cancelled);

      await expectLater(
        admin.occurrences.undoCancelOccurrence(
          event.id,
          t,
          version: dropped.version,
        ),
        refusedNaming('/reinstate'),
      );

      final staffView = await admin.occurrences.getOccurrence(event.id, t);
      expect(staffView.status, OccurrenceStatus.cancelled);
      expect(staffView.version, dropped.version);
      final memberView = await member.myEvents.getMyOccurrence(
        memberName,
        event.id,
        t,
      );
      expect(memberView.status, OccurrenceStatus.cancelled);
    });

    test('Issue 28: drop and reinstate call a one-off off and bring it '
        'back', () async {
      final event = await oneOff();
      final t = event.startTimeUtc;

      await coach.events.drop(event.id, version: 1, reason: 'rain');
      final dropped = await admin.occurrences.getOccurrence(event.id, t);
      expect(dropped.status, OccurrenceStatus.cancelled);
      expect(dropped.cancelReason, 'rain');

      await coach.events.reinstate(event.id, version: dropped.version);
      final back = await admin.occurrences.getOccurrence(event.id, t);
      expect(back.status, OccurrenceStatus.scheduled);
      final memberView = await member.myEvents.getMyOccurrence(
        memberName,
        event.id,
        t,
      );
      expect(memberView.status, OccurrenceStatus.scheduled);
    });

    test('Issue 28: a camp occurrence is still cancelled and restored through '
        'the occurrence calls', () async {
      n += 1;
      final start = dayAt(10 + n);
      final camp = await admin.events.createEvent(
        title: 'test_I28 camp $n',
        description: '',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venueId,
        organizerName: coachName,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=2',
      );

      await coach.occurrences.cancelOccurrence(
        camp.id,
        start,
        version: 1,
        reason: 'ice',
      );
      final cancelled = await admin.occurrences.getOccurrence(camp.id, start);
      expect(cancelled.status, OccurrenceStatus.cancelled);

      await coach.occurrences.undoCancelOccurrence(
        camp.id,
        start,
        version: cancelled.version,
      );
      final restored = await admin.occurrences.getOccurrence(camp.id, start);
      expect(restored.status, OccurrenceStatus.scheduled);
    });
  });
}
