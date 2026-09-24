import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 5: an in-place reschedule of a camp or one-off carries the event's
/// version (club_server#434), like update, correction and split. A stale one
/// is refused with `StaleVersionException` and nothing moves.
void main() {
  group('Issue 5: rescheduleEvent version', () {
    late SecureClient admin;
    late SecureClient member;
    late int venueId;
    final opened = <SecureClient>[];
    const memberName = 'test_i5_member';
    const password = 'password123';
    var n = 0;

    Future<Event> create(EventType type) {
      n += 1;
      final start = dayAt(20 + n);
      return admin.events.createEvent(
        title: 'test_I5 ${type.name} $n',
        description: '',
        type: type,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: type == EventType.camp ? 'FREQ=DAILY;COUNT=3' : null,
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
      venueId = (await admin.venues.createVenue(name: 'test_Venue I5')).id;
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: memberName,
        email: '$memberName@test.com',
        password: password,
        phone: '0000000000',
        dateOfBirthUtc: DateTime.utc(2000),
        gender: Gender.male,
        firstName: 'Member',
      );
      member = await createRemoteSecureClient(baseUrl: baseUrl);
      opened.add(member);
      await member.auth.login(memberName, password);
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

    for (final type in const [EventType.camp, EventType.oneOff]) {
      group(type.name, () {
        test('a reschedule with the current version moves the event and '
            'bumps the version', () async {
          final event = await create(type);
          final newStart = event.startTimeUtc.add(const Duration(hours: 2));

          final moved = await admin.events.rescheduleEvent(
            event.id,
            version: event.version,
            startTimeUtc: newStart,
          );
          expect(moved.version, event.version + 1);

          final fetched = await admin.events.getEvent(event.id);
          expect(fetched.startTimeUtc, newStart);
          expect(fetched.version, event.version + 1);
          expect(fetched.updatedBy, sudoUsername);
        });

        test('a stale version is refused with the current one, and nothing '
            'moves', () async {
          final event = await create(type);
          final renamed = await admin.events.updateEvent(
            event.id,
            version: event.version,
            title: 'test_I5 renamed $n',
          );
          expect(renamed.version, event.version + 1);

          await expectLater(
            admin.events.rescheduleEvent(
              event.id,
              version: event.version,
              startTimeUtc: event.startTimeUtc.add(const Duration(hours: 2)),
            ),
            throwsA(
              isA<StaleVersionException>()
                  .having((e) => e.statusCode, 'status', 409)
                  .having((e) => e.version, 'version', renamed.version)
                  .having((e) => e.updatedBy, 'updatedBy', sudoUsername)
                  .having((e) => e.updatedAtUtc, 'updatedAtUtc', isNotNull),
            ),
          );

          final fetched = await admin.events.getEvent(event.id);
          expect(fetched.startTimeUtc, event.startTimeUtc);
          expect(fetched.version, renamed.version);
        });

        test(
          'a member cannot reschedule, even with the current version',
          () async {
            final event = await create(type);
            await expectLater(
              member.events.rescheduleEvent(
                event.id,
                version: event.version,
                startTimeUtc: event.startTimeUtc.add(const Duration(hours: 2)),
              ),
              throwsA(isA<ServerException>()),
            );
            final fetched = await admin.events.getEvent(event.id);
            expect(fetched.startTimeUtc, event.startTimeUtc);
            expect(fetched.version, event.version);
          },
        );
      });
    }
  });
}
