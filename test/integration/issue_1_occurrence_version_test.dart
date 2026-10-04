import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/occurrence_version.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 1: every occurrence carries its own version (club_server#430).
///
/// Reschedule, cancel, undo-cancel, and a one-off's drop and reinstate send
/// the occurrence's version; a stale one is refused with
/// `StaleVersionException` and writes nothing. Occurrence changes never bump
/// the event's version.
void main() {
  group('Issue 1: occurrence version', () {
    late SecureClient admin;
    late SecureClient member;
    final opened = <SecureClient>[];
    late int venueId;
    const memberName = 'test_i1_member';
    const memberPassword = 'password123';
    var n = 0;

    /// A camp far enough ahead that no lead-time rule applies.
    Future<Event> camp() async {
      n += 1;
      final start = dayAt(10 + n);
      return admin.events.createEvent(
        title: 'test_I1 camp $n',
        description: '',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=3',
      );
    }

    Future<Event> oneOff() async {
      n += 1;
      final start = dayAt(10 + n);
      return admin.events.createEvent(
        title: 'test_I1 one-off $n',
        description: '',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
      );
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(admin);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      venueId = (await admin.venues.createVenue(name: 'test_Venue I1')).id;
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: memberName,
        email: '$memberName@test.com',
        password: memberPassword,
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
        firstName: 'Member',
      );
      member = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(member);
      await member.auth.login(memberName, memberPassword);
      expect((await member.auth.getCurrentUser()).username, memberName);
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

    test('an unchanged occurrence is version 1 with no author', () async {
      final event = await camp();
      final occ = await admin.occurrences.getOccurrence(
        event.id,
        event.startTimeUtc,
      );
      expect(occ.version, 1);
      expect(occ.updatedAtUtc, isNull);
      expect(occ.updatedBy, isNull);
    });

    test('a reschedule bumps the version and records who made it', () async {
      final event = await camp();
      final t = event.startTimeUtc;
      await admin.occurrences.rescheduleOccurrence(
        event.id,
        t,
        version: 1,
        newDurationMinutes: 45,
      );

      final occ = await admin.occurrences.getOccurrence(event.id, t);
      expect(occ.version, 2);
      expect(occ.updatedBy, sudoUsername);
      expect(occ.updatedAtUtc, isNotNull);
      expect(
        occ.actualEndTimeUtc.difference(occ.actualStartTimeUtc),
        const Duration(minutes: 45),
      );
    });

    test('a member sees the same version as the staff view', () async {
      final event = await camp();
      final t = event.startTimeUtc;
      await admin.enrollments.assign(event.id, memberName);
      await admin.occurrences.rescheduleOccurrence(
        event.id,
        t,
        version: 1,
        newDurationMinutes: 50,
      );

      final staffView = await admin.occurrences.getOccurrence(event.id, t);
      final memberView = await member.myEvents.getMyOccurrence(
        memberName,
        event.id,
        t,
      );
      expect(staffView.version, 2);
      expect(memberView.version, staffView.version);
      expect(memberView.updatedBy, sudoUsername);
    });

    test('a stale version is refused with the current one, and nothing is '
        'written', () async {
      final event = await camp();
      final t = event.startTimeUtc;
      await admin.occurrences.rescheduleOccurrence(
        event.id,
        t,
        version: 1,
        newDurationMinutes: 40,
      );

      await expectLater(
        admin.occurrences.cancelOccurrence(
          event.id,
          t,
          version: 1,
          reason: 'edit from a stale load',
        ),
        throwsA(
          isA<StaleVersionException>()
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.version, 'version', 2)
              .having((e) => e.updatedBy, 'updatedBy', sudoUsername)
              .having((e) => e.updatedAtUtc, 'updatedAtUtc', isNotNull),
        ),
      );

      final occ = await admin.occurrences.getOccurrence(event.id, t);
      expect(occ.status, isNot(OccurrenceStatus.cancelled));
      expect(occ.version, 2);
    });

    test('cancel and undo-cancel each bump the version; it never goes '
        'backwards', () async {
      final event = await camp();
      final t = event.startTimeUtc;
      await admin.occurrences.cancelOccurrence(
        event.id,
        t,
        version: 1,
        reason: 'ice',
      );
      final cancelled = await admin.occurrences.getOccurrence(event.id, t);
      expect(cancelled.status, OccurrenceStatus.cancelled);
      expect(cancelled.cancelReason, 'ice');
      expect(cancelled.version, 2);

      await admin.occurrences.undoCancelOccurrence(
        event.id,
        t,
        version: cancelled.version,
      );
      final restored = await admin.occurrences.getOccurrence(event.id, t);
      expect(restored.status, OccurrenceStatus.scheduled);
      expect(restored.version, 3);
    });

    test('undo-cancel with a stale version is refused', () async {
      final event = await camp();
      final t = event.startTimeUtc;
      await admin.occurrences.cancelOccurrence(
        event.id,
        t,
        version: 1,
        reason: 'ice',
      );

      await expectLater(
        admin.occurrences.undoCancelOccurrence(event.id, t, version: 1),
        throwsA(
          isA<StaleVersionException>().having((e) => e.version, 'version', 2),
        ),
      );
      final occ = await admin.occurrences.getOccurrence(event.id, t);
      expect(occ.status, OccurrenceStatus.cancelled);
    });

    test("occurrence changes do not bump the event's version", () async {
      final event = await camp();
      final t = event.startTimeUtc;
      await admin.occurrences.cancelOccurrence(
        event.id,
        t,
        version: 1,
        reason: 'ice',
      );
      await admin.occurrences.undoCancelOccurrence(event.id, t, version: 2);

      final after = await admin.events.getEvent(event.id);
      expect(after.version, event.version);
      final occ = await admin.occurrences.getOccurrence(event.id, t);
      expect(occ.version, 3);
    });

    test("drop and reinstate take the occurrence's version, not the "
        "event's", () async {
      final event = await oneOff();
      final t = event.startTimeUtc;
      // Move the event's version past the occurrence's, so sending the
      // event's version would be stale for the occurrence.
      final renamed = await admin.events.updateEvent(
        event.id,
        version: event.version,
        title: 'test_I1 one-off renamed',
      );
      expect(renamed.version, 2);
      expect(await occurrenceVersion(admin, event.id, t), 1);

      await expectLater(
        admin.events.drop(event.id, version: renamed.version, reason: 'rain'),
        throwsA(
          isA<StaleVersionException>().having((e) => e.version, 'version', 1),
        ),
      );

      await admin.events.drop(event.id, version: 1, reason: 'rain');
      final dropped = await admin.occurrences.getOccurrence(event.id, t);
      expect(dropped.status, OccurrenceStatus.cancelled);
      expect(dropped.cancelReason, 'rain');
      expect(dropped.version, 2);

      await expectLater(
        admin.events.reinstate(event.id, version: 1),
        throwsA(
          isA<StaleVersionException>().having((e) => e.version, 'version', 2),
        ),
      );

      await admin.events.reinstate(event.id, version: dropped.version);
      final back = await admin.occurrences.getOccurrence(event.id, t);
      expect(back.status, OccurrenceStatus.scheduled);
      expect(back.version, 3);
    });
  });
}
