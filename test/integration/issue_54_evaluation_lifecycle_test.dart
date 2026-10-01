import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/evaluation_fixtures.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// Issue 54 / #98: the evaluation calls beyond the core flow — the delete
/// lifecycles of evaluations and templates, editing a template one item at
/// a time, copying items between templates, and evidence attached to
/// answers (club_server#535), including media linked to an evaluation (#42).
///
/// Needs the evaluations module: every test skips on the default stack.
/// Run with `just test-modules issue_54_evaluation_lifecycle_test.dart`.
void main() {
  group('Issue 54: evaluation lifecycle', () {
    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient coach;
    late SecureClient otherCoach;
    late SecureClient member;
    late bool evaluationsOn;
    late EvaluationTemplate template;

    const memberName = 'test_i54_member';
    const coachName = 'test_i54_coach';
    const otherCoachName = 'test_i54_coach2';
    const adminName = 'test_i54_admin';
    const password = 'password123';
    final suffix = DateTime.now().millisecondsSinceEpoch;

    Matcher throwsCode(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'status', status)
          .having((e) => e.code, 'code', code),
    );

    Future<SecureClient> loginAs(String username) async {
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(username, password);
      expect((await client.auth.getCurrentUser()).username, username);
      return client;
    }

    Future<EvaluationTemplate> newTemplate(String name) =>
        admin.evaluations.createTemplate(
          name: 'test_i54_${name}_$suffix',
          layout: standardLayout(),
        );

    Future<EvaluationStaffView> draft() => coach.evaluations.createEvaluation(
      templateId: template.id,
      createdFor: memberName,
    );

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      evaluationsOn = (await stackCapabilities(sudo)).evaluations;

      for (final name in [memberName, coachName, otherCoachName, adminName]) {
        await registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: password,
          phone: '+919000000054',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
      }
      await sudo.users.assignRole(coachName, 'coach');
      await sudo.users.assignRole(otherCoachName, 'coach');
      await sudo.users.assignRole(adminName, 'admin');

      admin = await loginAs(adminName);
      coach = await loginAs(coachName);
      otherCoach = await loginAs(otherCoachName);
      member = await loginAs(memberName);

      if (evaluationsOn) {
        template = await newTemplate('main');
      }
    });

    tearDownAll(() async {
      for (final c in [member, otherCoach, coach, admin, sudo]) {
        await c.auth.logout();
      }
    });

    group('evaluation delete lifecycle', () {
      late int id;

      setUpAll(() async {
        if (!evaluationsOn) return;
        id = (await draft()).id;
      });

      test('54.01: soft-delete moves it from the active to the deleted '
          'listing', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final deleted = await coach.evaluations.deleteEvaluation(id);
        expect(deleted.deletedAtUtc, isNotNull);

        final active = await coach.evaluations.listEvaluations(limit: 100);
        expect(active.items.map((e) => e.id), isNot(contains(id)));
        final gone = await coach.evaluations.listDeletedEvaluations(
          limit: 100,
        );
        expect(gone.items.map((e) => e.id), contains(id));
      });

      test('54.02: restore moves it back', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final restored = await coach.evaluations.restoreEvaluation(id);
        expect(restored.deletedAtUtc, isNull);

        final active = await coach.evaluations.listEvaluations(limit: 100);
        expect(active.items.map((e) => e.id), contains(id));
        final gone = await coach.evaluations.listDeletedEvaluations(
          limit: 100,
        );
        expect(gone.items.map((e) => e.id), isNot(contains(id)));
      });

      test('54.03: hard-delete of an active evaluation is refused with 422 '
          'HARD_DELETE_NEEDS_SOFT_DELETE', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.hardDeleteEvaluation(id),
          throwsCode(422, SdkErrorCode.hardDeleteNeedsSoftDelete),
        );
        final still = await coach.evaluations.getEvaluation(id);
        expect(still.deletedAtUtc, isNull);
      });

      test('54.04: a regular admin cannot hard-delete', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await coach.evaluations.deleteEvaluation(id);
        await expectLater(
          admin.evaluations.hardDeleteEvaluation(id),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 403),
          ),
        );
        final gone = await coach.evaluations.listDeletedEvaluations(
          limit: 100,
        );
        expect(gone.items.map((e) => e.id), contains(id));
      });

      test('54.05: the super admin hard-deletes one they do not own; it '
          'leaves both listings', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await sudo.evaluations.hardDeleteEvaluation(id);

        final active = await coach.evaluations.listEvaluations(limit: 100);
        expect(active.items.map((e) => e.id), isNot(contains(id)));
        final gone = await coach.evaluations.listDeletedEvaluations(
          limit: 100,
        );
        expect(gone.items.map((e) => e.id), isNot(contains(id)));
      });
    });

    group('template delete lifecycle', () {
      late int id;

      setUpAll(() async {
        if (!evaluationsOn) return;
        id = (await newTemplate('lifecycle')).id;
      });

      test('54.11: soft-delete moves it from the active to the deleted '
          'listing', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final deleted = await admin.evaluations.deleteTemplate(id);
        expect(deleted.deletedAtUtc, isNotNull);

        final active = await admin.evaluations.listTemplates(limit: 100);
        expect(active.items.map((t) => t.id), isNot(contains(id)));
        final gone = await admin.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), contains(id));
      });

      test('54.12: restore moves it back', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final restored = await admin.evaluations.restoreTemplate(id);
        expect(restored.deletedAtUtc, isNull);

        final active = await admin.evaluations.listTemplates(limit: 100);
        expect(active.items.map((t) => t.id), contains(id));
        final gone = await admin.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), isNot(contains(id)));
      });

      test('54.13: hard-delete of an active template is refused with 422 '
          'HARD_DELETE_NEEDS_SOFT_DELETE', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.hardDeleteTemplate(id),
          throwsCode(422, SdkErrorCode.hardDeleteNeedsSoftDelete),
        );
        final still = await admin.evaluations.getTemplate(id);
        expect(still.deletedAtUtc, isNull);
      });

      test('54.14: a regular admin cannot hard-delete', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await admin.evaluations.deleteTemplate(id);
        await expectLater(
          admin.evaluations.hardDeleteTemplate(id),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 403),
          ),
        );
        final gone = await admin.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), contains(id));
      });

      test('54.15: the super admin hard-deletes; it leaves both '
          'listings', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await sudo.evaluations.hardDeleteTemplate(id);

        final active = await admin.evaluations.listTemplates(limit: 100);
        expect(active.items.map((t) => t.id), isNot(contains(id)));
        final gone = await admin.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), isNot(contains(id)));
      });
    });

    group('editing a template', () {
      test('54.21: an item is added at the end, or into a section', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('add');
        final atEnd = await admin.evaluations.addItem(
          t.id,
          const EvaluationNumberItem(question: 'Laps'),
        );
        final added = atEnd.items.last;
        expect(added, isA<EvaluationNumberItem>());
        expect(atEnd.layout.last, EvaluationLayoutItem(added.id!));

        final inSection = await admin.evaluations.addItem(
          t.id,
          const EvaluationQaItem(question: 'Anything else?'),
          section: 'Skills',
        );
        final qa = inSection.items.firstWhere(
          (i) => i is EvaluationQaItem && i.question == 'Anything else?',
        );
        final skills = inSection.layout
            .whereType<EvaluationLayoutSection<int>>()
            .single;
        expect(skills.items.last, qa.id);

        final newSection = await admin.evaluations.addItem(
          t.id,
          const EvaluationYesNoItem(question: 'Ready for games?'),
          section: 'Readiness',
        );
        final readiness = newSection.layout.last;
        expect(readiness, isA<EvaluationLayoutSection<int>>());
        expect(
          (readiness as EvaluationLayoutSection<int>).section,
          'Readiness',
        );
        expect(await admin.evaluations.getTemplate(t.id), newSection);
      });

      test('54.22: an item is replaced whole, keeping its id', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('replace');
        final rating =
            t.itemById(itemIdOf(t, EvaluationItemType.rating))!
                as EvaluationRatingItem;
        final updated = await admin.evaluations.replaceItem(
          t.id,
          rating.id!,
          rating.copyWith(question: 'Edge work', isPrivate: true),
        );
        final read = updated.itemById(rating.id!)! as EvaluationRatingItem;
        expect(read.question, 'Edge work');
        expect(read.isPrivate, isTrue);
        expect(updated.items.length, t.items.length);
      });

      test('54.23: an item keeps its type', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('type');
        await expectLater(
          admin.evaluations.replaceItem(
            t.id,
            itemIdOf(t, EvaluationItemType.rating),
            const EvaluationQaItem(question: 'Now in writing'),
          ),
          throwsCode(422, SdkErrorCode.itemTypeFixed),
        );
      });

      test('54.24: an item of another template is not found', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('foreign');
        final foreign = template.itemById(
          itemIdOf(template, EvaluationItemType.qa),
        )!;
        await expectLater(
          admin.evaluations.replaceItem(t.id, foreign.id!, foreign),
          throwsCode(404, SdkErrorCode.itemNotFound),
        );
        await expectLater(
          admin.evaluations.removeItem(t.id, foreign.id!),
          throwsCode(404, SdkErrorCode.itemNotFound),
        );
      });

      test('54.25: an item is removed with its place in the layout', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('remove');
        final numberId = itemIdOf(t, EvaluationItemType.number);
        final updated = await admin.evaluations.removeItem(t.id, numberId);
        expect(updated.itemById(numberId), isNull);
        expect(
          updated.layout.expand((e) => e.items),
          isNot(contains(numberId)),
        );
      });

      test('54.26: the layout is re-ordered, naming every item once', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('relayout');
        final ids = t.items.map((i) => i.id!).toList();
        final reversed = [
          for (final id in ids.reversed) EvaluationLayoutItem<int>(id),
        ];
        final updated = await admin.evaluations.updateTemplate(
          t.id,
          layout: reversed,
        );
        expect(updated.layout, reversed);
        expect(updated.items.map((i) => i.id), ids.reversed);

        await expectLater(
          admin.evaluations.updateTemplate(t.id, layout: reversed.sublist(1)),
          throwsCode(422, SdkErrorCode.invalidLayout),
        );
        await expectLater(
          admin.evaluations.updateTemplate(
            t.id,
            layout: [...reversed, reversed.first],
          ),
          throwsCode(422, SdkErrorCode.invalidLayout),
        );
        expect((await admin.evaluations.getTemplate(t.id)).layout, reversed);
      });

      test('54.27: a coach cannot edit items', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          coach.evaluations.addItem(
            template.id,
            const EvaluationQaItem(question: 'By a coach'),
          ),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 403),
          ),
        );
        await expectLater(
          coach.evaluations.removeItem(template.id, template.items.last.id!),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 403),
          ),
        );
      });
    });

    group('copying items', () {
      late EvaluationRatingItem source;

      setUpAll(() async {
        if (!evaluationsOn) return;
        source =
            template.itemById(itemIdOf(template, EvaluationItemType.rating))!
                as EvaluationRatingItem;
      });

      test('54.31: the item search finds items by text and type', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final hits = await coach.evaluations.searchItems(
          search: 'Skating',
          type: EvaluationItemType.rating,
          limit: 100,
        );
        final hit = hits.items.firstWhere((h) => h.templateId == template.id);
        expect(hit.templateName, template.name);
        expect(hit.item, source);
        expect(
          hits.items.map((h) => h.item.type).toSet(),
          {EvaluationItemType.rating},
        );
      });

      test('54.32: a copy records its origin, and a copy of a copy the '
          'first', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('copy');
        final withCopy = await admin.evaluations.addItem(
          t.id,
          source.copyWith(
            id: () => null,
            question: 'Skating (copied)',
            originItemId: () => source.id,
          ),
        );
        final copy = withCopy.items.last as EvaluationRatingItem;
        expect(copy.originItemId, source.id);
        expect(copy.question, 'Skating (copied)');

        final t2 = await newTemplate('copy2');
        final withCopy2 = await admin.evaluations.addItem(
          t2.id,
          copy.copyWith(id: () => null, originItemId: () => copy.id),
        );
        expect(
          (withCopy2.items.last as EvaluationRatingItem).originItemId,
          source.id,
        );
      });

      test('54.33: a copy keeps its answer domain', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('mismatch');
        await expectLater(
          admin.evaluations.addItem(
            t.id,
            source.copyWith(
              id: () => null,
              originItemId: () => source.id,
              rateMax: () => 10,
            ),
          ),
          throwsCode(422, SdkErrorCode.originMismatch),
        );
      });

      test('54.34: an unknown origin is not found', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final t = await newTemplate('noorigin');
        await expectLater(
          admin.evaluations.addItem(
            t.id,
            source.copyWith(id: () => null, originItemId: () => 999999),
          ),
          throwsCode(404, SdkErrorCode.itemNotFound),
        );
      });
    });

    group('evidence', () {
      late int id;
      late int ratingId;
      late int multipleId;
      late int qaId;
      late Media clip;
      late Media secret;

      Future<Media> upload(String name) => coach.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i54_$name.png',
        contentType: 'image/png',
        preserveOriginal: true,
      );

      setUpAll(() async {
        if (!evaluationsOn) return;
        ratingId = itemIdOf(template, EvaluationItemType.rating);
        multipleId = itemIdOf(template, EvaluationItemType.multipleChoice);
        qaId = itemIdOf(template, EvaluationItemType.qa);
        id = (await draft()).id;
        clip = await upload('clip');
        secret = await upload('secret');
      });

      test('54.41: evidence is attached under the item id and read with '
          'the answer', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await coach.evaluationMedia.attach(
          id,
          tag: EvaluationMediaTags.evidence(ratingId),
          mediaUuid: clip.uuid,
        );
        await coach.evaluationMedia.attach(
          id,
          tag: EvaluationMediaTags.evidence(qaId),
          mediaUuid: secret.uuid,
        );

        final e = await coach.evaluations.getEvaluation(id);
        expect(e.answerFor(ratingId)!.evidence.single.mediaUuid, clip.uuid);
        expect(e.answerFor(ratingId)!.valueNum, isNull);
        expect(e.answerFor(qaId)!.evidence.single.mediaUuid, secret.uuid);
      });

      test('54.42: evidence is refused where the item takes none', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final noEvidence = {
          'a question without evidence': EvaluationMediaTags.evidence(
            itemIdOf(template, EvaluationItemType.yesNo),
          ),
          'an info item': EvaluationMediaTags.evidence(
            itemIdOf(template, EvaluationItemType.info),
          ),
          'a free-form tag': 'shared_clips',
        };
        for (final MapEntry(key: what, value: tag) in noEvidence.entries) {
          await expectLater(
            coach.evaluationMedia.attach(id, tag: tag, mediaUuid: clip.uuid),
            throwsCode(422, SdkErrorCode.invalidEvidence),
            reason: what,
          );
        }
      });

      test("54.43: another coach cannot reach the owner's evidence", () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          otherCoach.evaluationMedia.listGrouped(id),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );
      });

      test('54.44 (#42): getLinks reports the evaluation owner', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final links = await sudo.media.getLinks(clip.uuid);
        expect(links, hasLength(1));
        expect(links.single.ownerType, MediaLinkOwnerType.evaluation);
        expect(links.single.ownerId, '$id');
        expect(links.single.tag, EvaluationMediaTags.evidence(ratingId));
      });

      test('54.45 (#42): searchLinks lists evaluation media', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final page = await sudo.media.searchLinks(
          tag: EvaluationMediaTags.evidence(ratingId),
        );
        expect(
          page.items.where(
            (l) =>
                l.ownerType == MediaLinkOwnerType.evaluation &&
                l.mediaUuid == clip.uuid,
          ),
          hasLength(1),
        );
        // The whole unfiltered page parses too.
        await sudo.media.searchLinks(limit: 100);
      });

      test('54.46: clearing an answer detaches its evidence', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final extra = await upload('extra');
        await coach.evaluationMedia.attach(
          id,
          tag: EvaluationMediaTags.evidence(multipleId),
          mediaUuid: extra.uuid,
        );
        final cleared = await coach.evaluations.clearAnswer(id, multipleId);
        expect(cleared.answerFor(multipleId), isNull);
        final grouped = await coach.evaluationMedia.listGrouped(id);
        expect(
          grouped.containsKey(EvaluationMediaTags.evidence(multipleId)),
          isFalse,
        );
      });

      test('54.47: once published, the member sees evidence on public '
          'items only, and it is frozen', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          member.myEvaluations.listMyEvaluationMedia(memberName, id),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );

        await coach.evaluations.putAnswer(
          id,
          ratingId,
          const EvaluationAnswerInput(valueNum: 3),
        );
        await coach.evaluations.saveEvaluation(id);
        await expectLater(
          coach.evaluationMedia.detach(
            id,
            EvaluationMediaTags.evidence(ratingId),
            clip.uuid,
          ),
          throwsCode(422, SdkErrorCode.invalidState),
        );
        await coach.evaluations.publishEvaluation(id);

        final media = await member.myEvaluations.listMyEvaluationMedia(
          memberName,
          id,
        );
        expect(
          media.keys,
          unorderedEquals([
            EvaluationMediaTags.evidence(ratingId),
            EvaluationMediaTags.memberCopy,
          ]),
        );
        expect(
          media[EvaluationMediaTags.evidence(ratingId)]!.single.mediaUuid,
          clip.uuid,
        );

        final view = await member.myEvaluations.getMyEvaluation(memberName, id);
        expect(view.answers.map((a) => a.itemId), [ratingId]);
        expect(view.answers.single.evidence.single.mediaUuid, clip.uuid);
      });
    });
  });
}
