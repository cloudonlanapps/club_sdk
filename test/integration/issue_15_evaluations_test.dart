import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/evaluation_fixtures.dart';
import '../utils/event_time.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 15 / #98: evaluations as items and answers (`/evaluations`,
/// `/myevaluations`, club_server#302, #535).
///
/// A coach creates a draft against a template, answers its questions one at
/// a time, saves it once complete and publishes it. Until publication the
/// evaluation exists only for its effective owner; the member then reads it
/// without its private items.
///
/// Runs against both stacks: `just test` (module off) asserts the 503,
/// `just test-modules issue_15_evaluations_test.dart` the behaviour.
void main() {
  group('Issue 15: evaluations', () {
    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient coach;
    late SecureClient otherCoach;
    late SecureClient member;
    late SecureClient otherMember;
    late bool evaluationsOn;
    late EvaluationTemplate template;
    late int ratingId;
    late int yesNoId;
    late int singleId;
    late int multipleId;
    late int numberId;
    late int qaId;
    late int infoId;

    const memberName = 'test_i15_member';
    const otherMemberName = 'test_i15_other';
    const coachName = 'test_i15_coach';
    const otherCoachName = 'test_i15_coach2';
    const adminName = 'test_i15_admin';
    const password = 'password123';

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

    Future<EvaluationStaffView> draft({String createdFor = memberName}) =>
        coach.evaluations.createEvaluation(
          templateId: template.id,
          createdFor: createdFor,
        );

    /// A draft with its one required question answered, ready to save.
    Future<EvaluationStaffView> completeDraft() async {
      final e = await draft();
      return coach.evaluations.putAnswer(
        e.id,
        ratingId,
        const EvaluationAnswerInput(valueNum: 4),
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
      evaluationsOn = (await stackCapabilities(sudo)).evaluations;

      for (final name in [
        memberName,
        otherMemberName,
        coachName,
        otherCoachName,
        adminName,
      ]) {
        await registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: password,
          phone: '+919000000015',
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
      otherMember = await loginAs(otherMemberName);

      if (evaluationsOn) {
        template = await admin.evaluations.createTemplate(
          name: 'test_i15_template',
          layout: standardLayout(),
        );
        ratingId = itemIdOf(template, EvaluationItemType.rating);
        yesNoId = itemIdOf(template, EvaluationItemType.yesNo);
        singleId = itemIdOf(template, EvaluationItemType.singleChoice);
        multipleId = itemIdOf(template, EvaluationItemType.multipleChoice);
        numberId = itemIdOf(template, EvaluationItemType.number);
        qaId = itemIdOf(template, EvaluationItemType.qa);
        infoId = itemIdOf(template, EvaluationItemType.info);
      }
    });

    tearDownAll(() async {
      for (final c in [admin, coach, otherCoach, member, otherMember, sudo]) {
        await c.auth.logout();
      }
    });

    test('15.00: every route answers 503 where the module is off', () async {
      if (skipIf(enabled: evaluationsOn, feature: 'evaluations')) return;

      await expectLater(
        coach.evaluations.listEvaluations(),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
      await expectLater(
        admin.evaluations.listTemplates(),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
      await expectLater(
        admin.evaluations.searchItems(),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
      await expectLater(
        member.myEvaluations.listMyEvaluations(memberName),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
    });

    group('templates', () {
      test('15.01: a template is created whole; items get ids in layout '
          'order', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        expect(template.name, 'test_i15_template');
        expect(template.createdBy, adminName);
        expect(template.items.map((i) => i.type), [
          EvaluationItemType.info,
          EvaluationItemType.rating,
          EvaluationItemType.yesNo,
          EvaluationItemType.singleChoice,
          EvaluationItemType.multipleChoice,
          EvaluationItemType.number,
          EvaluationItemType.qa,
        ]);
        expect(template.layout, [
          EvaluationLayoutItem(infoId),
          EvaluationLayoutSection('Skills', [
            ratingId,
            yesNoId,
            singleId,
            multipleId,
            numberId,
          ]),
          EvaluationLayoutItem(qaId),
        ]);
        final rating = template.itemById(ratingId)! as EvaluationRatingItem;
        expect(rating.requireCommentFor, [1]);
        expect(rating.rateMax, 5);

        expect(await coach.evaluations.getTemplate(template.id), template);
        final listed = await coach.evaluations.listTemplates(limit: 100);
        expect(listed.items.map((t) => t.id), contains(template.id));
      });

      test('15.02: a template with no question is refused', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          admin.evaluations.createTemplate(
            name: 'test_i15_info_only',
            layout: const [
              EvaluationLayoutItem(EvaluationInfoItem(markdown: 'Nothing')),
            ],
          ),
          throwsCode(422, SdkErrorCode.validationError),
        );
      });

      test('15.03: a coach reads templates but cannot write them', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          coach.evaluations.createTemplate(
            name: 'test_i15_by_coach',
            layout: standardLayout(),
          ),
          throwsCode(403, SdkErrorCode.insufficientPermission),
        );
        await expectLater(
          coach.evaluations.updateTemplate(template.id, name: 'x'),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 403),
          ),
        );
        expect(
          (await admin.evaluations.getTemplate(template.id)).name,
          'test_i15_template',
        );
      });

      test('15.04: a template in use keeps its items but may be '
          'renamed', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final used = await admin.evaluations.createTemplate(
          name: 'test_i15_used',
          layout: standardLayout(),
        );
        final e = await coach.evaluations.createEvaluation(
          templateId: used.id,
          createdFor: memberName,
        );

        await expectLater(
          admin.evaluations.addItem(
            used.id,
            const EvaluationQaItem(question: 'Late addition'),
          ),
          throwsCode(422, SdkErrorCode.templateInUse),
        );
        await expectLater(
          admin.evaluations.removeItem(used.id, used.items.last.id!),
          throwsCode(422, SdkErrorCode.templateInUse),
        );
        await expectLater(
          admin.evaluations.deleteTemplate(used.id),
          throwsCode(422, SdkErrorCode.templateInUse),
        );
        final renamed = await admin.evaluations.updateTemplate(
          used.id,
          name: 'test_i15_used_renamed',
        );
        expect(renamed.name, 'test_i15_used_renamed');
        expect(renamed.items, used.items);

        await coach.evaluations.deleteEvaluation(e.id);
      });

      test('15.05: a template says whether it is in use, a soft-deleted '
          'evaluation included', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final fresh = await admin.evaluations.createTemplate(
          name: 'test_i15_in_use',
          layout: standardLayout(),
        );
        expect(fresh.inUse, isFalse);
        expect((await coach.evaluations.getTemplate(fresh.id)).inUse, isFalse);

        final e = await coach.evaluations.createEvaluation(
          templateId: fresh.id,
          createdFor: memberName,
        );
        expect((await admin.evaluations.getTemplate(fresh.id)).inUse, isTrue);
        expect((await coach.evaluations.getTemplate(fresh.id)).inUse, isTrue);
        final listed = await admin.evaluations.listTemplates(limit: 100);
        expect(listed.items.singleWhere((t) => t.id == fresh.id).inUse, isTrue);

        final deleted = await coach.evaluations.deleteEvaluation(e.id);
        expect(deleted.deletedAtUtc, isNotNull);
        expect((await admin.evaluations.getTemplate(fresh.id)).inUse, isTrue);
      });
    });

    group('creating and owning', () {
      test('15.10: an admin cannot create an evaluation', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          admin.evaluations.createEvaluation(
            templateId: template.id,
            createdFor: memberName,
          ),
          throwsCode(403, SdkErrorCode.insufficientPermission),
        );
      });

      test('15.11: a coach creates a general draft with no answers', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        expect(e.status, EvaluationStatus.draft);
        expect(e.templateId, template.id);
        expect(e.createdFor, memberName);
        expect(e.createdBy, coachName);
        expect(e.owner, isNull);
        expect(e.effectiveOwner, coachName);
        expect(e.isGeneral, isTrue);
        expect(e.answers, isEmpty);
        expect(await coach.evaluations.getEvaluation(e.id), e);
      });

      test('15.12: before publication only the owner sees it', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        for (final other in [otherCoach, admin]) {
          await expectLater(
            other.evaluations.getEvaluation(e.id),
            throwsCode(404, SdkErrorCode.evaluationNotFound),
          );
          final listed = await other.evaluations.listEvaluations(limit: 100);
          expect(listed.items.map((x) => x.id), isNot(contains(e.id)));
        }
        await expectLater(
          otherCoach.evaluations.putAnswer(
            e.id,
            ratingId,
            const EvaluationAnswerInput(valueNum: 3),
          ),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );
        final mine = await coach.evaluations.listEvaluations(limit: 100);
        expect(mine.items.map((x) => x.id), contains(e.id));
      });

      test('15.13: an unknown evaluation is a 404', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          coach.evaluations.getEvaluation(999999),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );
      });

      test('15.14: lists filter by status, member and scope', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final forOther = await draft(createdFor: otherMemberName);
        final saved = await completeDraft();
        await coach.evaluations.saveEvaluation(saved.id);

        final byMember = await coach.evaluations.listEvaluations(
          createdFor: otherMemberName,
          limit: 100,
        );
        expect(byMember.items.map((e) => e.id), [forOther.id]);

        final byStatus = await coach.evaluations.listEvaluations(
          status: EvaluationStatus.saved,
          limit: 100,
        );
        expect(byStatus.items.map((e) => e.id), contains(saved.id));
        expect(
          byStatus.items.map((e) => e.status).toSet(),
          {EvaluationStatus.saved},
        );

        final eventOnly = await coach.evaluations.listEvaluations(
          general: false,
          limit: 100,
        );
        expect(eventOnly.items.map((e) => e.id), isNot(contains(saved.id)));
        final generalOnly = await coach.evaluations.listEvaluations(
          general: true,
          limit: 100,
        );
        expect(generalOnly.items.map((e) => e.id), contains(saved.id));
      });
    });

    group('answers', () {
      test('15.20: every kind of question takes its answer', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        final answers = {
          ratingId: const EvaluationAnswerInput(valueNum: 4, coachNote: 'n'),
          yesNoId: const EvaluationAnswerInput.yesNo(yes: false),
          singleId: const EvaluationAnswerInput(valueText: 'd'),
          multipleId: const EvaluationAnswerInput(choices: ['shot', 'pass']),
          numberId: const EvaluationAnswerInput(valueNum: 12.5),
          qaId: const EvaluationAnswerInput(valueText: '*private*'),
        };
        for (final MapEntry(key: itemId, value: answer) in answers.entries) {
          await coach.evaluations.putAnswer(e.id, itemId, answer);
        }

        final read = await coach.evaluations.getEvaluation(e.id);
        expect(read.answerFor(ratingId)!.valueNum, 4);
        expect(read.answerFor(ratingId)!.coachNote, 'n');
        expect(read.answerFor(yesNoId)!.yesNo, isFalse);
        expect(read.answerFor(singleId)!.valueText, 'd');
        expect(
          read.answerFor(multipleId)!.choices,
          unorderedEquals(['shot', 'pass']),
        );
        expect(read.answerFor(numberId)!.valueNum, 12.5);
        expect(read.answerFor(qaId)!.valueText, '*private*');
      });

      test('15.21: an answer replaces the earlier one, and clears', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        await coach.evaluations.putAnswer(
          e.id,
          ratingId,
          const EvaluationAnswerInput(valueNum: 2, coachNote: 'first'),
        );
        final replaced = await coach.evaluations.putAnswer(
          e.id,
          ratingId,
          const EvaluationAnswerInput(valueNum: 5),
        );
        expect(replaced.answerFor(ratingId)!.valueNum, 5);
        expect(replaced.answerFor(ratingId)!.coachNote, isNull);

        final noteOnly = await coach.evaluations.putAnswer(
          e.id,
          numberId,
          const EvaluationAnswerInput(coachNote: 'not timed'),
        );
        expect(noteOnly.answerFor(numberId)!.valueNum, isNull);
        expect(noteOnly.answerFor(numberId)!.coachNote, 'not timed');

        final cleared = await coach.evaluations.clearAnswer(e.id, ratingId);
        expect(cleared.answerFor(ratingId), isNull);
        expect(
          (await coach.evaluations.getEvaluation(e.id)).answerFor(ratingId),
          isNull,
        );
      });

      test('15.22: an answer that does not fit its item is refused', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        final invalid = {
          'a rating off the scale': (
            ratingId,
            const EvaluationAnswerInput(valueNum: 9),
          ),
          'text for a rating': (
            ratingId,
            const EvaluationAnswerInput(valueText: 'great'),
          ),
          'a Yes / No of 2': (
            yesNoId,
            const EvaluationAnswerInput(valueNum: 2),
          ),
          'an unknown choice': (
            singleId,
            const EvaluationAnswerInput(valueText: 'g'),
          ),
          'a repeated choice': (
            multipleId,
            const EvaluationAnswerInput(choices: ['shot', 'shot']),
          ),
          'an answer to info': (
            infoId,
            const EvaluationAnswerInput(valueText: 'x'),
          ),
          'an empty answer': (qaId, const EvaluationAnswerInput()),
        };
        for (final MapEntry(key: what, value: (itemId, answer))
            in invalid.entries) {
          await expectLater(
            coach.evaluations.putAnswer(e.id, itemId, answer),
            throwsCode(422, SdkErrorCode.invalidAnswer),
            reason: what,
          );
        }
        expect((await coach.evaluations.getEvaluation(e.id)).answers, isEmpty);
      });

      test('15.23: saving an incomplete draft names the items', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        await expectLater(
          coach.evaluations.saveEvaluation(e.id),
          throwsA(
            isA<ServerException>()
                .having((x) => x.code, 'code', SdkErrorCode.incomplete)
                .having(
                  (x) => (x.details?['details'] as Map?)?['itemIds'],
                  'itemIds',
                  [ratingId],
                ),
          ),
        );

        // A 1 wants a coach note: still incomplete without one.
        await coach.evaluations.putAnswer(
          e.id,
          ratingId,
          const EvaluationAnswerInput(valueNum: 1),
        );
        await expectLater(
          coach.evaluations.saveEvaluation(e.id),
          throwsCode(422, SdkErrorCode.incomplete),
        );

        await coach.evaluations.putAnswer(
          e.id,
          ratingId,
          const EvaluationAnswerInput(valueNum: 1, coachNote: 'falls often'),
        );
        final saved = await coach.evaluations.saveEvaluation(e.id);
        expect(saved.status, EvaluationStatus.saved);
      });

      test(
        '15.24: the period is set, cleared, and needs both bounds',
        () async {
          if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

          final e = await draft();
          final start = DateTime.utc(2026, 1, 1);
          final end = DateTime.utc(2026, 3, 31);
          final set = await coach.evaluations.updateEvaluationPeriod(
            e.id,
            periodStartUtc: start,
            periodEndUtc: end,
          );
          expect(set.periodStartUtc, start);
          expect(set.periodEndUtc, end);
          expect(
            (await coach.evaluations.getEvaluation(e.id)).periodEndUtc,
            end,
          );

          await expectLater(
            coach.evaluations.updateEvaluationPeriod(
              e.id,
              periodStartUtc: start,
              periodEndUtc: null,
            ),
            throwsCode(422, SdkErrorCode.validationError),
          );

          final cleared = await coach.evaluations.updateEvaluationPeriod(
            e.id,
            periodStartUtc: null,
            periodEndUtc: null,
          );
          expect(cleared.periodStartUtc, isNull);
          expect(cleared.periodEndUtc, isNull);
        },
      );
    });

    group('lifecycle', () {
      test('15.30: a draft cannot be published without being saved', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await completeDraft();
        await expectLater(
          coach.evaluations.publishEvaluation(e.id),
          throwsCode(422, SdkErrorCode.invalidTransition),
        );
        expect(
          (await coach.evaluations.getEvaluation(e.id)).status,
          EvaluationStatus.draft,
        );
      });

      test('15.31: draft → saved → published, and back; only a draft is '
          'edited', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await completeDraft();
        final saved = await coach.evaluations.saveEvaluation(e.id);
        expect(saved.status, EvaluationStatus.saved);
        expect(saved.publishedAtUtc, isNull);
        await expectLater(
          coach.evaluations.putAnswer(
            e.id,
            ratingId,
            const EvaluationAnswerInput(valueNum: 3),
          ),
          throwsCode(422, SdkErrorCode.invalidState),
        );

        final published = await coach.evaluations.publishEvaluation(e.id);
        expect(published.status, EvaluationStatus.published);
        expect(published.isPublished, isTrue);
        await expectLater(
          coach.evaluations.clearAnswer(e.id, ratingId),
          throwsCode(422, SdkErrorCode.invalidState),
        );
        await expectLater(
          coach.evaluations.updateEvaluationPeriod(
            e.id,
            periodStartUtc: null,
            periodEndUtc: null,
          ),
          throwsCode(422, SdkErrorCode.invalidState),
        );

        final withdrawn = await coach.evaluations.unpublishEvaluation(e.id);
        expect(withdrawn.status, EvaluationStatus.saved);
        expect(withdrawn.publishedAtUtc, isNull);

        final reverted = await coach.evaluations.revertEvaluation(e.id);
        expect(reverted.status, EvaluationStatus.draft);
        final edited = await coach.evaluations.putAnswer(
          e.id,
          ratingId,
          const EvaluationAnswerInput(valueNum: 3),
        );
        expect(edited.answerFor(ratingId)!.valueNum, 3);
      });

      test('15.32: the owner previews the member copy as a PDF', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await completeDraft();
        final pdf = await coach.evaluations.previewMemberCopy(e.id);
        expect(String.fromCharCodes(pdf.take(5)), '%PDF-');

        await expectLater(
          otherCoach.evaluations.previewMemberCopy(e.id),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );
      });
    });

    group('transfer', () {
      test('15.40: the owner hands a draft to another coach', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        await coach.evaluations.transferEvaluation(e.id, owner: otherCoachName);

        final moved = await otherCoach.evaluations.getEvaluation(e.id);
        expect(moved.owner, otherCoachName);
        expect(moved.createdBy, coachName);
        expect(moved.effectiveOwner, otherCoachName);
        await expectLater(
          coach.evaluations.getEvaluation(e.id),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );
      });

      test('15.41: an admin transfers by id', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        await admin.evaluations.transferEvaluation(e.id, owner: otherCoachName);

        expect(
          (await otherCoach.evaluations.getEvaluation(e.id)).owner,
          otherCoachName,
        );
      });

      test('15.42: the new owner must be a coach', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        await expectLater(
          coach.evaluations.transferEvaluation(e.id, owner: otherMemberName),
          throwsCode(422, SdkErrorCode.notEligible),
        );
        expect((await coach.evaluations.getEvaluation(e.id)).owner, isNull);
      });

      test('15.43: a published evaluation cannot be transferred', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await completeDraft();
        await coach.evaluations.saveEvaluation(e.id);
        await coach.evaluations.publishEvaluation(e.id);
        await expectLater(
          coach.evaluations.transferEvaluation(e.id, owner: otherCoachName),
          throwsCode(422, SdkErrorCode.invalidState),
        );
        expect(
          (await coach.evaluations.getEvaluation(e.id)).effectiveOwner,
          coachName,
        );
      });
    });

    group("the member's view", () {
      late int publishedId;

      setUpAll(() async {
        if (!evaluationsOn) return;
        final e = await draft();
        await coach.evaluations.putAnswer(
          e.id,
          ratingId,
          const EvaluationAnswerInput(valueNum: 4, coachNote: 'for you'),
        );
        await coach.evaluations.putAnswer(
          e.id,
          qaId,
          const EvaluationAnswerInput(valueText: 'staff only'),
        );
        await coach.evaluations.saveEvaluation(e.id);
        await coach.evaluations.publishEvaluation(e.id);
        publishedId = e.id;
      });

      test('15.50: a member cannot see an unpublished evaluation', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await completeDraft();
        await coach.evaluations.saveEvaluation(e.id);
        await expectLater(
          member.myEvaluations.getMyEvaluation(memberName, e.id),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );
        await expectLater(
          member.myEvaluations.listMyEvaluationMedia(memberName, e.id),
          throwsCode(404, SdkErrorCode.evaluationNotFound),
        );
        final mine = await member.myEvaluations.listMyEvaluations(memberName);
        expect(mine.items.map((x) => x.id), isNot(contains(e.id)));
      });

      test('15.51: the member reads it without its private items', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final mine = await member.myEvaluations.listMyEvaluations(memberName);
        expect(mine.items.map((x) => x.id), contains(publishedId));

        final one = await member.myEvaluations.getMyEvaluation(
          memberName,
          publishedId,
        );
        expect(one.status, EvaluationStatus.published);
        expect(one.createdBy, coachName);
        expect(one.template.id, template.id);
        expect(one.template.items.map((i) => i.id), isNot(contains(qaId)));
        expect(one.template.items.every((i) => !i.isPrivate), isTrue);
        expect(
          one.template.layout.expand((entry) => entry.items),
          isNot(contains(qaId)),
        );
        expect(one.answers.map((a) => a.itemId), [ratingId]);
        expect(one.answers.single.coachNote, 'for you');
      });

      test('15.52: any coach reads it; an admin and another member '
          'cannot', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final byCoach = await otherCoach.myEvaluations.getMyEvaluation(
          memberName,
          publishedId,
        );
        expect(byCoach.answers.map((a) => a.itemId), [ratingId]);

        await expectLater(
          admin.myEvaluations.listMyEvaluations(memberName),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 403),
          ),
        );
        await expectLater(
          otherMember.myEvaluations.listMyEvaluations(memberName),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 's', 403),
          ),
        );
      });

      test('15.53: publishing stores the member copy, which the member '
          'downloads', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final media = await member.myEvaluations.listMyEvaluationMedia(
          memberName,
          publishedId,
        );
        final copy = media[EvaluationMediaTags.memberCopy]!.single;
        final bytes = await member.media.download(copy.mediaUuid);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      });

      test('15.54: publishing again replaces the member copy', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        Future<String> copyUuid() async =>
            (await member.myEvaluations.listMyEvaluationMedia(
              memberName,
              publishedId,
            ))[EvaluationMediaTags.memberCopy]!.single.mediaUuid;

        final first = await copyUuid();
        await coach.evaluations.unpublishEvaluation(publishedId);
        await coach.evaluations.publishEvaluation(publishedId);
        final second = await copyUuid();
        expect(second, isNot(first));
      });
    });

    group('event scope', () {
      late Event event;

      setUpAll(() async {
        if (!evaluationsOn) return;
        final venueId = (await sudo.venues.createVenue(
          name: 'test_i15_venue',
          address: '15 Rink Road',
        )).id;
        // The register of a session ten minutes out is open, so it can be
        // marked now.
        final start = nowUtcMinute().add(const Duration(minutes: 10));
        event = await sudo.events.createEvent(
          title: 'test_i15_event',
          description: 'evaluation eligibility',
          type: EventType.oneOff,
          visibility: Visibility.public,
          venueId: venueId,
          startTimeUtc: start,
          endTimeUtc: start.add(const Duration(hours: 1)),
          organizerName: sudoUsername,
          coachNames: [coachName],
        );
        await sudo.enrollments.assign(event.id, memberName);
        final report = await sudo.attendance.markAttendance(
          event.id,
          event.startTimeUtc,
          const [
            AttendanceMarkRecord(
              membername: memberName,
              status: AttendanceStatus.present,
            ),
          ],
        );
        expect(report.marked.map((m) => m.membername), [memberName]);
      });

      test('15.60: a coach of the event evaluates a member who '
          'attended', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await coach.evaluations.createEvaluation(
          templateId: template.id,
          createdFor: memberName,
          eventId: event.id,
        );
        expect(e.eventId, event.id);
        expect(e.isGeneral, isFalse);

        final listed = await coach.evaluations.listEvaluations(
          eventId: event.id,
          limit: 100,
        );
        expect(listed.items.map((x) => x.id), [e.id]);
      });

      test('15.61: a coach not on the event is not eligible', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          otherCoach.evaluations.createEvaluation(
            templateId: template.id,
            createdFor: memberName,
            eventId: event.id,
          ),
          throwsCode(422, SdkErrorCode.notEligible),
        );
      });

      test('15.62: a member with no attendance is not eligible', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          coach.evaluations.createEvaluation(
            templateId: template.id,
            createdFor: otherMemberName,
            eventId: event.id,
          ),
          throwsCode(422, SdkErrorCode.notEligible),
        );
      });

      test('15.63: an unknown event is a 404', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          coach.evaluations.createEvaluation(
            templateId: template.id,
            createdFor: memberName,
            eventId: 999999,
          ),
          throwsCode(404, SdkErrorCode.eventNotFound),
        );
      });
    });
  });
}
