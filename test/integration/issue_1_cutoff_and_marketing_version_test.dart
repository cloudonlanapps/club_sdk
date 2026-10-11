import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 1: the cutoff verbs take the event's version and the marketing
/// writes take the block's own (club_server#13). The current version
/// succeeds and moves it one on; a stale one is refused with
/// [StaleVersionException] and writes nothing.
///
/// The marketing cases need the Event Marketing module
/// (`just test-modules`); where it is off they assert the 503.
void main() {
  group('Issue 1: versions on the cutoff verbs and the marketing block', () {
    late SecureClient admin;
    late bool marketingOn;
    var seq = 0;

    /// Camps and programmes are organized by sudo, so each takes its own
    /// venue and its own day: programmes clash on venue and on organizer.
    Future<int> newVenue() async =>
        (await admin.venues.createVenue(name: 'test_i1v_venue_${++seq}')).id;

    Future<Event> camp(String name) async {
      final start = dayAt(20 + seq);
      return admin.events.createEvent(
        title: 'test_i1v_$name',
        description: 'issue 1',
        type: EventType.camp,
        visibility: Visibility.public,
        venueId: await newVenue(),
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: 'FREQ=DAILY;COUNT=5',
      );
    }

    Future<Event> programme(String name) async {
      final start = dayAt(20 + seq, hour: 6 + seq % 12);
      return admin.events.createEvent(
        title: 'test_i1v_$name',
        description: 'issue 1',
        type: EventType.programme,
        visibility: Visibility.public,
        venueId: await newVenue(),
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        rrule: weeklyOn(start),
      );
    }

    /// Matches the refusal of a write made at a version [current] has
    /// moved past, last written by sudo.
    Matcher throwsStaleAt(int current) => throwsA(
      isA<StaleVersionException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.code, 'code', SdkErrorCode.staleVersion)
          .having((e) => e.version, 'version', current)
          .having((e) => e.updatedBy, 'updatedBy', sudoUsername)
          .having((e) => e.updatedAtUtc, 'updatedAtUtc', isNotNull),
    );

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      marketingOn = (await stackCapabilities(admin)).eventMarketing;
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    // ═══════════════════════════════════════════════════════════════════
    // CAMP — cancel and undo-cancel
    // ═══════════════════════════════════════════════════════════════════

    test('Issue 1: cancelSeries at the current version sets the cutoff and '
        'bumps the version', () async {
      final event = await camp('cancel_ok');
      final cutoff = event.startTimeUtc.add(const Duration(days: 2));

      final cancelled = await admin.events.cancelSeries(
        event.id,
        version: event.version,
        reason: 'no ice',
        effectiveDateTimeUtc: cutoff,
      );
      expect(cancelled.untilTimeUtc, cutoff);
      expect(cancelled.version, event.version + 1);

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, cutoff);
      expect(read.version, event.version + 1);
    });

    test('Issue 1: cancelSeries at a stale version is refused and sets no '
        'cutoff', () async {
      final event = await camp('cancel_stale');
      final moved = await admin.events.updateEvent(
        event.id,
        version: event.version,
        description: 'issue 1, edited',
      );
      expect(moved.version, event.version + 1);

      await expectLater(
        admin.events.cancelSeries(
          event.id,
          version: event.version,
          reason: 'no ice',
          effectiveDateTimeUtc: event.startTimeUtc.add(const Duration(days: 2)),
        ),
        throwsStaleAt(moved.version),
      );

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, isNull);
      expect(read.status, EventStatus.active);
      expect(read.version, moved.version);
    });

    test('Issue 1: undoCancelSeries at the current version clears the '
        'cutoff and bumps the version', () async {
      final event = await camp('undo_ok');
      final cancelled = await admin.events.cancelSeries(
        event.id,
        version: event.version,
        reason: 'no ice',
        effectiveDateTimeUtc: event.startTimeUtc.add(const Duration(days: 2)),
      );
      expect(cancelled.untilTimeUtc, isNotNull);

      final restored = await admin.events.undoCancelSeries(
        event.id,
        version: cancelled.version,
      );
      expect(restored.untilTimeUtc, isNull);
      expect(restored.version, cancelled.version + 1);

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, isNull);
      expect(read.version, cancelled.version + 1);
    });

    test('Issue 1: undoCancelSeries at a stale version is refused and the '
        'camp stays cancelled', () async {
      final event = await camp('undo_stale');
      final cutoff = event.startTimeUtc.add(const Duration(days: 2));
      final cancelled = await admin.events.cancelSeries(
        event.id,
        version: event.version,
        reason: 'no ice',
        effectiveDateTimeUtc: cutoff,
      );
      expect(cancelled.untilTimeUtc, cutoff);

      await expectLater(
        admin.events.undoCancelSeries(event.id, version: event.version),
        throwsStaleAt(cancelled.version),
      );

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, cutoff);
      expect(read.version, cancelled.version);
    });

    // ═══════════════════════════════════════════════════════════════════
    // PROGRAMME — terminate, extend, extend-indefinitely
    // ═══════════════════════════════════════════════════════════════════

    test('Issue 1: terminate at the current version sets the cutoff and '
        'bumps the version', () async {
      final event = await programme('terminate_ok');
      final cutoff = event.startTimeUtc.add(const Duration(days: 21));

      final terminated = await admin.events.terminate(
        event.id,
        version: event.version,
        reason: 'season over',
        cutoffTimeUtc: cutoff,
      );
      expect(terminated.untilTimeUtc, cutoff);
      expect(terminated.version, event.version + 1);

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, cutoff);
      expect(read.version, event.version + 1);
    });

    test('Issue 1: terminate at a stale version is refused and sets no '
        'cutoff', () async {
      final event = await programme('terminate_stale');
      final moved = await admin.events.correctionOnEvent(
        event.id,
        version: event.version,
        description: 'issue 1, corrected',
      );
      expect(moved.version, event.version + 1);

      await expectLater(
        admin.events.terminate(
          event.id,
          version: event.version,
          reason: 'season over',
          cutoffTimeUtc: event.startTimeUtc.add(const Duration(days: 21)),
        ),
        throwsStaleAt(moved.version),
      );

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, isNull);
      expect(read.version, moved.version);
    });

    test('Issue 1: extend at the current version moves the cutoff and '
        'bumps the version', () async {
      final event = await programme('extend_ok');
      final cutoff = event.startTimeUtc.add(const Duration(days: 21));
      final terminated = await admin.events.terminate(
        event.id,
        version: event.version,
        reason: 'season over',
        cutoffTimeUtc: cutoff,
      );
      expect(terminated.untilTimeUtc, cutoff);

      final later = cutoff.add(const Duration(days: 7));
      final extended = await admin.events.extend(
        event.id,
        version: terminated.version,
        cutoffTimeUtc: later,
      );
      expect(extended.untilTimeUtc, later);
      expect(extended.version, terminated.version + 1);

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, later);
      expect(read.version, terminated.version + 1);
    });

    test('Issue 1: extend at a stale version is refused and the cutoff '
        'stays', () async {
      final event = await programme('extend_stale');
      final cutoff = event.startTimeUtc.add(const Duration(days: 21));
      final terminated = await admin.events.terminate(
        event.id,
        version: event.version,
        reason: 'season over',
        cutoffTimeUtc: cutoff,
      );
      expect(terminated.untilTimeUtc, cutoff);

      await expectLater(
        admin.events.extend(
          event.id,
          version: event.version,
          cutoffTimeUtc: cutoff.add(const Duration(days: 7)),
        ),
        throwsStaleAt(terminated.version),
      );

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, cutoff);
      expect(read.version, terminated.version);
    });

    test('Issue 1: extendIndefinitely at the current version clears the '
        'cutoff and bumps the version', () async {
      final event = await programme('open_ok');
      final terminated = await admin.events.terminate(
        event.id,
        version: event.version,
        reason: 'season over',
        cutoffTimeUtc: event.startTimeUtc.add(const Duration(days: 21)),
      );
      expect(terminated.untilTimeUtc, isNotNull);

      final open = await admin.events.extendIndefinitely(
        event.id,
        version: terminated.version,
      );
      expect(open.untilTimeUtc, isNull);
      expect(open.version, terminated.version + 1);

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, isNull);
      expect(read.version, terminated.version + 1);
    });

    test('Issue 1: extendIndefinitely at a stale version is refused and '
        'the cutoff stays', () async {
      final event = await programme('open_stale');
      final cutoff = event.startTimeUtc.add(const Duration(days: 21));
      final terminated = await admin.events.terminate(
        event.id,
        version: event.version,
        reason: 'season over',
        cutoffTimeUtc: cutoff,
      );
      expect(terminated.untilTimeUtc, cutoff);

      await expectLater(
        admin.events.extendIndefinitely(event.id, version: event.version),
        throwsStaleAt(terminated.version),
      );

      final read = await admin.events.getEvent(event.id);
      expect(read.untilTimeUtc, cutoff);
      expect(read.version, terminated.version);
    });

    // ═══════════════════════════════════════════════════════════════════
    // MARKETING — the block's own version; module-gated
    // ═══════════════════════════════════════════════════════════════════

    test('Issue 1: the marketing writes answer 503 where the module is '
        'off', () async {
      if (skipIf(enabled: marketingOn, feature: 'event marketing')) return;
      final event = await camp('marketing_off');

      await expectLater(
        admin.eventMarketing.setEventMarketing(
          event.id,
          const EventMarketing(fee: 500),
          version: EventMarketing.unwrittenVersion,
        ),
        throwsModuleDisabled(SdkErrorCode.eventMarketingDisabled),
      );
      await expectLater(
        admin.eventMarketing.clearEventMarketing(
          event.id,
          version: EventMarketing.unwrittenVersion,
        ),
        throwsModuleDisabled(SdkErrorCode.eventMarketingDisabled),
      );
    });

    test('Issue 1: the first setEventMarketing is made at the unwritten '
        'version and stores the block at the next', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_first');

      final stored = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 500),
        version: EventMarketing.unwrittenVersion,
      );
      expect(stored.fee, 500);
      expect(stored.version, EventMarketing.unwrittenVersion + 1);
      expect(stored.updatedBy, sudoUsername);
      expect(stored.updatedAtUtc, isNotNull);

      final read = await admin.eventMarketing.getEventMarketing(event.id);
      expect(read.version, EventMarketing.unwrittenVersion + 1);
      expect(read.updatedBy, sudoUsername);
      expect(read.fee, 500);
    });

    test('Issue 1: setEventMarketing at the current version replaces the '
        'block and bumps its version', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_ok');
      final first = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 500),
        version: EventMarketing.unwrittenVersion,
      );

      final second = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 600),
        version: first.version,
      );
      expect(second.fee, 600);
      expect(second.version, first.version + 1);

      final read = await admin.eventMarketing.getEventMarketing(event.id);
      expect(read.fee, 600);
      expect(read.version, first.version + 1);
    });

    test('Issue 1: a block read from the server can be written back with '
        'a change', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_readback');
      await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 500, urgencyText: 'Limited seats!'),
        version: EventMarketing.unwrittenVersion,
      );
      final loaded = await admin.eventMarketing.getEventMarketing(event.id);

      final saved = await admin.eventMarketing.setEventMarketing(
        event.id,
        loaded.copyWith(fee: () => 700),
        version: loaded.version,
      );
      expect(saved.fee, 700);
      expect(saved.urgencyText, 'Limited seats!');
      expect(saved.version, loaded.version + 1);
    });

    test('Issue 1: writing the marketing block leaves the event version '
        'as it was', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_event_version');

      final stored = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 500),
        version: EventMarketing.unwrittenVersion,
      );
      expect((await admin.events.getEvent(event.id)).version, event.version);

      await admin.eventMarketing.clearEventMarketing(
        event.id,
        version: stored.version,
      );
      expect((await admin.events.getEvent(event.id)).version, event.version);
    });

    test('Issue 1: setEventMarketing at a stale version is refused and '
        'writes nothing', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_stale');
      final first = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 500),
        version: EventMarketing.unwrittenVersion,
      );
      final second = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 600),
        version: first.version,
      );

      await expectLater(
        admin.eventMarketing.setEventMarketing(
          event.id,
          const EventMarketing(fee: 900),
          version: first.version,
        ),
        throwsStaleAt(second.version),
      );

      final read = await admin.eventMarketing.getEventMarketing(event.id);
      expect(read.fee, 600);
      expect(read.version, second.version);
    });

    test('Issue 1: a stale setEventMarketing on an event with no block '
        'names the unwritten version and no writer', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_stale_empty');

      await expectLater(
        admin.eventMarketing.setEventMarketing(
          event.id,
          const EventMarketing(fee: 500),
          version: 4,
        ),
        throwsA(
          isA<StaleVersionException>()
              .having(
                (e) => e.version,
                'version',
                EventMarketing.unwrittenVersion,
              )
              .having((e) => e.updatedAtUtc, 'updatedAtUtc', isNull)
              .having((e) => e.updatedBy, 'updatedBy', isNull),
        ),
      );
      await expectLater(
        admin.eventMarketing.getEventMarketing(event.id),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.eventMarketingNotFound,
          ),
        ),
      );
    });

    test('Issue 1: clearEventMarketing at a stale version is refused and '
        'the block stays', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_clear_stale');
      final first = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 500),
        version: EventMarketing.unwrittenVersion,
      );
      final second = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 600),
        version: first.version,
      );

      await expectLater(
        admin.eventMarketing.clearEventMarketing(
          event.id,
          version: first.version,
        ),
        throwsStaleAt(second.version),
      );

      final read = await admin.eventMarketing.getEventMarketing(event.id);
      expect(read.fee, 600);
      expect(read.version, second.version);
    });

    test('Issue 1: clearEventMarketing at the current version removes the '
        'block, which is then at the unwritten version again', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;
      final event = await camp('marketing_clear_ok');
      final first = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 500),
        version: EventMarketing.unwrittenVersion,
      );

      await admin.eventMarketing.clearEventMarketing(
        event.id,
        version: first.version,
      );
      await expectLater(
        admin.eventMarketing.getEventMarketing(event.id),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventMarketingNotFound,
              ),
        ),
      );

      final again = await admin.eventMarketing.setEventMarketing(
        event.id,
        const EventMarketing(fee: 800),
        version: EventMarketing.unwrittenVersion,
      );
      expect(again.fee, 800);
      expect(again.version, EventMarketing.unwrittenVersion + 1);
    });
  });
}
