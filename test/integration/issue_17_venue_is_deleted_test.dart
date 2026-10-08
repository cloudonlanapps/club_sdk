import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/test_client.dart';

/// Issue 17: `SdkErrorCode.venueIsDeleted` names the refusal of restoring an
/// event whose venue is deleted, and `deleteEvent` deletes a cancelled event
/// like any other.
void main() {
  group('Issue 17: restoring an event at a deleted venue, deleting a '
      'cancelled event', () {
    late SecureClient sudo;

    Future<int> venue(String name) async => (await sudo.venues.createVenue(
      name: 'test_i17_$name',
      address: '17 Rink Road',
    )).id;

    Future<Event> oneOff(String name, int venueId, {int days = 3}) {
      final start = dayAt(days, hour: 15);
      return sudo.events.createEvent(
        title: 'test_i17_$name',
        description: 'issue 17',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        organizerName: sudoUsername,
      );
    }

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      expect((await sudo.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      await sudo.auth.logout();
    });

    test('Issue 17: restoring an event whose venue is deleted is refused '
        'with SdkErrorCode.venueIsDeleted', () async {
      final venueId = await venue('gone');
      final event = await oneOff('at_gone_venue', venueId);
      await sudo.events.deleteEvent(event.id);
      final deletedVenue = await sudo.venues.deleteVenue(venueId);
      expect(deletedVenue.deletedAtUtc, isNotNull);

      await expectLater(
        sudo.events.restoreEvent(event.id),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.code, 'code', SdkErrorCode.venueIsDeleted),
        ),
      );

      final deleted = await sudo.events.listDeletedEvents(limit: 100);
      expect(deleted.items.map((e) => e.id), contains(event.id));
    });

    test('Issue 17: the event is restored once its venue is', () async {
      final venueId = await venue('back');
      final event = await oneOff('at_restored_venue', venueId, days: 4);
      await sudo.events.deleteEvent(event.id);
      await sudo.venues.deleteVenue(venueId);
      await sudo.venues.restoreVenue(venueId);

      final restored = await sudo.events.restoreEvent(event.id);

      expect(restored.deletedAtUtc, isNull);
      final read = await sudo.events.getEvent(event.id);
      expect(read.deletedAtUtc, isNull);
    });

    test('Issue 17: a cancelled event is soft-deleted by '
        'deleteEvent', () async {
      final venueId = await venue('cancelled');
      final start = dayAt(5, hour: 15);
      final camp = await sudo.events.createEvent(
        title: 'test_i17_cancelled_camp',
        description: 'issue 17',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=3',
        organizerName: sudoUsername,
      );
      final cancelled = await sudo.events.cancelSeries(
        camp.id,
        reason: 'rink closed',
        effectiveDateTimeUtc: start.add(const Duration(days: 1)),
      );
      expect(cancelled.status, EventStatus.cancelled);

      final deleted = await sudo.events.deleteEvent(camp.id);

      expect(deleted.deletedAtUtc, isNotNull);
      final listed = await sudo.events.listDeletedEvents(limit: 100);
      expect(listed.items.map((e) => e.id), contains(camp.id));
    });
  });
}
