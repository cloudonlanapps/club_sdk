import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/event_time.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// club_server#526 (and #520 for media restore): one code per wrong-state
/// delete, on every endpoint.
///
/// - Hard delete of an item that was not soft-deleted first → 422
///   `HARD_DELETE_NEEDS_SOFT_DELETE` — group, user, template, evaluation,
///   media item, event and venue. The item still exists afterwards.
/// - Restore of an item that is not deleted → 422 `NOTHING_TO_RESTORE` —
///   event, user, venue, group, template, evaluation and media item. The
///   item is still live afterwards.
///
/// Templates and evaluations need the evaluations module: those cases skip
/// on the default stack. Run the whole file with
/// `just test-modules issue_526_delete_state_codes_test.dart`.
void main() {
  group('club_server#526: wrong-state delete codes', () {
    late SecureClient sudo;
    late bool evaluationsOn;

    late int groupId;
    late int venueId;
    late int eventId;
    late int mediaId;
    int? templateId;
    int? evaluationId;

    const memberName = 'test_i526_member';
    const coachName = 'test_i526_coach';
    const password = 'password123';
    final suffix = DateTime.now().millisecondsSinceEpoch;

    final hardDeleteNeedsSoftDelete = throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having(
            (e) => e.code,
            'code',
            SdkErrorCode.hardDeleteNeedsSoftDelete,
          ),
    );
    final nothingToRestore = throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.code, 'code', SdkErrorCode.nothingToRestore),
    );

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      final me = await sudo.auth.getCurrentUser();
      expect(me.username, sudoUsername);
      evaluationsOn = (await stackCapabilities(sudo)).evaluations;

      for (final name in [memberName, coachName]) {
        await registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: password,
          phone: '+919000000526',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
      }
      await sudo.users.assignRole(coachName, 'coach');

      groupId = (await sudo.groups.createGroup(name: 'test_i526_group')).id;
      venueId = (await sudo.venues.createVenue(
        name: 'test_i526_venue',
        address: '526 Rink Road',
      )).id;
      final start = dayAt(3, hour: 15);
      eventId = (await sudo.events.createEvent(
        title: 'test_i526_event',
        description: 'wrong-state delete codes',
        type: EventType.oneOff,
        visibility: Visibility.public,
        venueId: venueId,
        startTimeUtc: start,
        endTimeUtc: start.add(const Duration(hours: 1)),
        organizerName: sudoUsername,
      )).id;
      mediaId = (await sudo.media.upload(
        fileBytes: testPngBytes,
        filename: 'issue_526.png',
        contentType: 'image/png',
        preserveOriginal: true,
      )).id;

      if (evaluationsOn) {
        templateId = (await sudo.evaluations.createTemplate(
          name: 'test_i526_template_$suffix',
          scopes: const [EvaluationScopeType.general],
          categories: const [
            EvaluationCategory(
              key: 'skating',
              label: 'Skating',
              minValue: 1,
              maxValue: 5,
            ),
          ],
        )).id;
        evaluationId = (await sudo.evaluations.createEvaluation(
          subjectUsername: memberName,
          templateId: templateId!,
          scope: const EvaluationScope.general(),
          authorUsername: coachName,
          scores: const [EvaluationScoreInput(key: 'skating', value: 4)],
          comment: 'i526',
        )).id;
      }
    });

    tearDownAll(() async {
      // Media and evaluation rows carry no `test_` name for
      // clearTestArtifacts to find, so they are removed here.
      await sudo.media.softDelete(mediaId);
      await sudo.media.hardDelete(mediaId);
      if (evaluationId != null) {
        await sudo.evaluations.deleteEvaluation(evaluationId!);
        await sudo.evaluations.hardDeleteEvaluation(evaluationId!);
      }
      if (templateId != null) {
        await sudo.evaluations.deleteTemplate(templateId!);
        await sudo.evaluations.hardDeleteTemplate(templateId!);
      }
      await sudo.auth.logout();
    });

    group('hard delete of a live item', () {
      test('526.01: a group is refused and still exists', () async {
        await expectLater(
          sudo.groups.hardDeleteGroup(groupId),
          hardDeleteNeedsSoftDelete,
        );
        final still = await sudo.groups.getGroup(groupId);
        expect(still.id, groupId);
      });

      test('526.02: a user is refused and still exists', () async {
        await expectLater(
          sudo.users.hardDeleteUser(memberName),
          hardDeleteNeedsSoftDelete,
        );
        final still = await sudo.users.getUserInfo(memberName);
        expect(still.username, memberName);
      });

      test('526.03: a template is refused and still exists', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.hardDeleteTemplate(templateId!),
          hardDeleteNeedsSoftDelete,
        );
        final still = await sudo.evaluations.getTemplate(templateId!);
        expect(still.deletedAtUtc, isNull);
      });

      test('526.04: an evaluation is refused and still exists', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.hardDeleteEvaluation(evaluationId!),
          hardDeleteNeedsSoftDelete,
        );
        final still = await sudo.evaluations.getEvaluation(evaluationId!);
        expect(still.id, evaluationId);
      });

      test('526.05: a media item is refused and still exists', () async {
        await expectLater(
          sudo.media.hardDelete(mediaId),
          hardDeleteNeedsSoftDelete,
        );
        final still = await sudo.media.getById(mediaId);
        expect(still.isDeleted, false);
      });

      test('526.06: an event is refused and still exists', () async {
        await expectLater(
          sudo.events.hardDeleteEvent(eventId),
          hardDeleteNeedsSoftDelete,
        );
        final still = await sudo.events.getEvent(eventId);
        expect(still.deletedAtUtc, isNull);
      });

      test('526.07: a venue is refused and still exists', () async {
        await expectLater(
          sudo.venues.hardDeleteVenue(venueId),
          hardDeleteNeedsSoftDelete,
        );
        final still = await sudo.venues.getVenue(venueId);
        expect(still.deletedAtUtc, isNull);
      });
    });

    group('restore of a live item', () {
      test('526.11: an event is refused and stays live', () async {
        await expectLater(
          sudo.events.restoreEvent(eventId),
          nothingToRestore,
        );
        final still = await sudo.events.getEvent(eventId);
        expect(still.deletedAtUtc, isNull);
      });

      test('526.12: a user is refused and stays live', () async {
        await expectLater(
          sudo.users.restoreUser(memberName),
          nothingToRestore,
        );
        final deleted = await sudo.users.getDeletedUsers(
          searchTerm: memberName,
        );
        expect(
          deleted.items.map((u) => u.username),
          isNot(contains(memberName)),
        );
        final still = await sudo.users.getUserInfo(memberName);
        expect(still.username, memberName);
      });

      test('526.13: a venue is refused and stays live', () async {
        await expectLater(
          sudo.venues.restoreVenue(venueId),
          nothingToRestore,
        );
        final still = await sudo.venues.getVenue(venueId);
        expect(still.deletedAtUtc, isNull);
      });

      test('526.14: a group is refused and stays live', () async {
        await expectLater(
          sudo.groups.restoreGroup(groupId),
          nothingToRestore,
        );
        final deleted = await sudo.groups.getDeletedGroups();
        expect(deleted.items.map((g) => g.id), isNot(contains(groupId)));
      });

      test('526.15: a template is refused and stays live', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.restoreTemplate(templateId!),
          nothingToRestore,
        );
        final still = await sudo.evaluations.getTemplate(templateId!);
        expect(still.deletedAtUtc, isNull);
      });

      test('526.16: an evaluation is refused and stays live', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.restoreEvaluation(evaluationId!),
          nothingToRestore,
        );
        final still = await sudo.evaluations.getEvaluation(evaluationId!);
        expect(still.deletedAtUtc, isNull);
      });

      test('club_server#520: a media item is refused and stays live', () async {
        final before = await sudo.media.getById(mediaId);
        await expectLater(sudo.media.restore(mediaId), nothingToRestore);
        final after = await sudo.media.getById(mediaId);
        expect(after.isDeleted, false);
        expect(after.updatedAtUtc, before.updatedAtUtc);
      });
    });
  });
}
