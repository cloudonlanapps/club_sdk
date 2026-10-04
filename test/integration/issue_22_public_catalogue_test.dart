import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 22: the public catalogue, public venues and event marketing
/// (club_server#299, #307, #409, #410).
///
/// The catalogue and the venue listing are unauthenticated and keyed by
/// opaque public ids, so an integer id must never resolve. The basic
/// marketing block travels on the event itself and needs no module; the
/// extended block is the deployment-gated Event Marketing module.
///
/// Runs against both stacks: the marketing cases assert the 503 on the
/// off stack (`just sdk-test`) and the behaviour on the on stack
/// (`just sdk-test-modules`). The catalogue cases run on both.
void main() {
  group('Issue 22: public catalogue and event marketing', () {
    late SecureClient admin;
    late SecureClient anon;
    late bool marketingOn;
    late int publicEventId;
    late int privateEventId;
    late int venueId;
    late String eventPublicId;
    late String venuePublicId;

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      marketingOn = (await stackCapabilities(admin)).eventMarketing;

      final venue = await admin.venues.createVenue(
        name: 'test_public_venue',
        address: '2 Rink Road',
        description: 'the main sheet',
      );
      venueId = venue.id;

      final start = dayAt(14);
      final event = await admin.events.createEvent(
        title: 'test_public_camp',
        description: 'a public camp',
        type: EventType.camp,
        venueId: venueId,
        visibility: Visibility.public,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 2)),
        rrule: 'FREQ=DAILY;COUNT=3',
        shortDescription: 'three days on the ice',
        stamp: 'Popular',
        highlights: const ['Small groups', 'Video review'],
        includes: const ['Ice time', 'Jersey'],
      );
      publicEventId = event.id;

      final privateStart = dayAt(16);
      final private = await admin.events.createEvent(
        title: 'test_private_camp',
        description: 'a private camp',
        type: EventType.camp,
        venueId: venueId,
        visibility: Visibility.private,
        startTimeUtc: privateStart,
        endTimeUtc: privateStart.add(const Duration(hours: 2)),
        rrule: 'FREQ=DAILY;COUNT=3',
      );
      privateEventId = private.id;

      anon = await createRemoteSecureClient(baseUrl: baseUrl);

      final venues = await anon.public.listPublicVenues();
      venuePublicId = venues
          .firstWhere((v) => v.name == 'test_public_venue')
          .publicId;
      final events = await anon.public.listPublicEvents();
      eventPublicId = events.items
          .firstWhere((e) => e.title == 'test_public_camp')
          .publicId;
    });

    tearDownAll(() async {
      await admin.auth.logout();
    });

    // ═══════════════════════════════════════════════════════════════════
    // BASIC MARKETING — on the event itself, no module gate
    // ═══════════════════════════════════════════════════════════════════

    test('22.01: the basic marketing block round-trips on the event', () async {
      final event = await admin.events.getEvent(publicEventId);
      expect(event.shortDescription, 'three days on the ice');
      expect(event.stamp, 'Popular');
      expect(event.highlights, ['Small groups', 'Video review']);
      expect(event.includes, ['Ice time', 'Jersey']);
    });

    // ═══════════════════════════════════════════════════════════════════
    // PUBLIC CATALOGUE — unauthenticated
    // ═══════════════════════════════════════════════════════════════════

    test('22.02: the catalogue lists public live events to a logged-out '
        'caller', () async {
      final page = await anon.public.listPublicEvents();
      expect(page.items, isNotEmpty);
      final ours = page.items.firstWhere((e) => e.title == 'test_public_camp');
      expect(ours.type, EventType.camp);
      expect(ours.venue.publicId, venuePublicId);
      expect(ours.marketing?.shortDescription, 'three days on the ice');
      expect(ours.marketing?.stamp, 'Popular');
    });

    test('22.03: a private event never reaches the catalogue', () async {
      final page = await anon.public.listPublicEvents(limit: 100);
      expect(
        page.items.map((e) => e.title),
        isNot(contains('test_private_camp')),
      );
    });

    test('22.04: one public event is readable by its public id', () async {
      final event = await anon.public.getPublicEvent(eventPublicId);
      expect(event.publicId, eventPublicId);
      expect(event.title, 'test_public_camp');
    });

    test('22.05: an integer id is not a public id', () async {
      await expectLater(
        anon.public.getPublicEvent('$publicEventId'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
      await expectLater(
        anon.public.getPublicVenue('$venueId'),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 404),
        ),
      );
    });

    test('22.06: the catalogue filters by type and venue', () async {
      final camps = await anon.public.listPublicEvents(type: EventType.camp);
      expect(camps.items, isNotEmpty);
      expect(camps.items.every((e) => e.type == EventType.camp), isTrue);

      final atVenue = await anon.public.listPublicEvents(
        venueId: venuePublicId,
      );
      expect(
        atVenue.items.map((e) => e.title),
        contains('test_public_camp'),
      );

      final programmes = await anon.public.listPublicEvents(
        type: EventType.programme,
      );
      expect(
        programmes.items.map((e) => e.title),
        isNot(contains('test_public_camp')),
      );
    });

    test('22.07: the catalogue filters by window', () async {
      final after = await anon.public.listPublicEvents(from: dayAt(200));
      expect(
        after.items.map((e) => e.title),
        isNot(contains('test_public_camp')),
        reason: 'the camp has no occurrence that far out',
      );

      final around = await anon.public.listPublicEvents(
        from: dayAt(1),
        to: dayAt(60),
      );
      expect(around.items.map((e) => e.title), contains('test_public_camp'));
    });

    test('22.08: public venues are listed and readable by public id', () async {
      final venues = await anon.public.listPublicVenues();
      final ours = venues.firstWhere((v) => v.name == 'test_public_venue');
      expect(ours.address, '2 Rink Road');
      expect(ours.description, 'the main sheet');

      final one = await anon.public.getPublicVenue(venuePublicId);
      expect(one, ours);
    });

    // ═══════════════════════════════════════════════════════════════════
    // EXTENDED MARKETING — the deployment-gated module
    // ═══════════════════════════════════════════════════════════════════

    test(
      '22.09: every marketing route answers 503 where the module is off',
      () async {
        if (marketingOn) {
          markTestSkipped('event marketing is on on this stack');
          return;
        }
        await expectLater(
          admin.eventMarketing.getEventMarketing(publicEventId),
          throwsModuleDisabled(SdkErrorCode.eventMarketingDisabled),
        );
        await expectLater(
          anon.public.getPublicEventMarketing(eventPublicId),
          throwsModuleDisabled(SdkErrorCode.eventMarketingDisabled),
        );
        await expectLater(
          anon.public.listPublicEventMarketing([eventPublicId]),
          throwsModuleDisabled(SdkErrorCode.eventMarketingDisabled),
        );
      },
    );

    test('22.10: an event without a marketing block is a 404', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;

      await expectLater(
        admin.eventMarketing.getEventMarketing(privateEventId),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 404)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventMarketingNotFound,
              ),
        ),
      );
    });

    test(
      '22.11: the extended block round-trips and PUT replaces it whole',
      () async {
        if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;

        const block = EventMarketing(
          durationText: '3 days',
          scheduleText: 'Mon-Wed, 6-8am',
          eligibilityText: 'U14 and up',
          registrationDeadlineUtc: null,
          hasOpenSlots: true,
          contactNumber: '+919000000003',
          fee: 4500,
          feeStructure: [FeeItem(name: 'Ice time', amount: 3000)],
        );

        final stored = await admin.eventMarketing.setEventMarketing(
          publicEventId,
          block,
        );
        expect(stored.durationText, '3 days');
        expect(stored.scheduleText, 'Mon-Wed, 6-8am');
        expect(stored.fee, 4500);
        expect(stored.feeStructure?.single.name, 'Ice time');

        final read = await admin.eventMarketing.getEventMarketing(
          publicEventId,
        );
        expect(read.durationText, '3 days');

        // PUT replaces: a field left null on the new body is cleared.
        final replaced = await admin.eventMarketing.setEventMarketing(
          publicEventId,
          const EventMarketing(durationText: '4 days'),
        );
        expect(replaced.durationText, '4 days');
        expect(replaced.scheduleText, isNull);
        expect(replaced.fee, isNull);
        expect(replaced.feeStructure, anyOf(isNull, isEmpty));
      },
    );

    test('22.12: the public reads the extended block by public id', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;

      final one = await anon.public.getPublicEventMarketing(eventPublicId);
      expect(one.durationText, '4 days');

      final batch = await anon.public.listPublicEventMarketing([
        eventPublicId,
        'not-a-real-public-id',
      ]);
      expect(batch.keys, contains(eventPublicId));
      expect(
        batch.keys,
        isNot(contains('not-a-real-public-id')),
        reason: 'unknown ids are silently absent',
      );
    });

    test('22.13: the batch read refuses more than 50 ids', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;

      await expectLater(
        anon.public.listPublicEventMarketing(
          List<String>.generate(51, (i) => 'id-$i'),
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 422)
              .having((e) => e.code, 'code', SdkErrorCode.tooManyIds),
        ),
      );
    });

    test('22.14: clearing the block removes it', () async {
      if (skipUnless(enabled: marketingOn, module: 'event marketing')) return;

      await admin.eventMarketing.clearEventMarketing(publicEventId);
      await expectLater(
        admin.eventMarketing.getEventMarketing(publicEventId),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 404)
              .having(
                (e) => e.code,
                'code',
                SdkErrorCode.eventMarketingNotFound,
              ),
        ),
      );
    });
  });
}
