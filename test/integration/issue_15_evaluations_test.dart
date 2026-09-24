import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 15: evaluations (`/evaluations`, `/myevaluations`,
/// club_server#302).
///
/// The lifecycle is draft → saved → published and back again, and the
/// two-step publish is deliberate: nothing here saves and publishes at
/// once. A member sees only published evaluations, without the coach note.
///
/// Runs against both stacks: `just sdk-test` (module off) asserts the 503,
/// `just sdk-test-modules` the behaviour.
void main() {
  group('Issue 15: evaluations', () {
    late SecureClient admin;
    late SecureClient member;
    late bool evaluationsOn;
    late int templateId;

    const memberName = 'test_eval_member';
    const otherName = 'test_eval_other';
    const coachName = 'test_eval_coach';

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      evaluationsOn = (await stackCapabilities(admin)).evaluations;

      for (final name in [memberName, otherName, coachName]) {
        await registerAndApprove(
          client: admin,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: 'password123',
          phone: '+919000000002',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
      }
      await admin.users.assignRole(coachName, 'coach');

      if (evaluationsOn) {
        final template = await admin.evaluations.createTemplate(
          name: 'test_eval_template',
          scopes: [EvaluationScopeType.general],
          categories: const [
            EvaluationCategory(
              key: 'skating',
              label: 'Skating',
              minValue: 1,
              maxValue: 5,
              defaultValue: 3,
            ),
            EvaluationCategory(
              key: 'passing',
              label: 'Passing',
              minValue: 1,
              maxValue: 5,
            ),
          ],
          description: 'general skills',
        );
        templateId = template.id;
      }

      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login(memberName, 'password123');
    });

    tearDownAll(() async {
      await admin.auth.logout();
      await member.auth.logout();
    });

    test('15.00: every route answers 503 where the module is off', () async {
      if (evaluationsOn) {
        markTestSkipped('evaluations are on on this stack');
        return;
      }
      await expectLater(
        admin.evaluations.listEvaluations(),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
      await expectLater(
        admin.evaluations.listTemplates(),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
      await expectLater(
        member.myEvaluations.listMyEvaluations(memberName),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
    });

    test('15.01: a template declares its categories and scopes', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final template = await admin.evaluations.getTemplate(templateId);
      expect(template.name, 'test_eval_template');
      expect(template.scopes, contains(EvaluationScopeType.general));
      expect(template.categories.map((c) => c.key), ['skating', 'passing']);
      expect(
        template.categories.every((c) => c.id != null),
        isTrue,
        reason: 'the server assigns category ids',
      );

      final listed = await admin.evaluations.listTemplates();
      expect(listed.items.map((t) => t.id), contains(templateId));
    });

    test('15.02: a draft cannot be published without being saved', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final draft = await admin.evaluations.createEvaluation(
        subjectUsername: memberName,
        templateId: templateId,
        scope: const EvaluationScope.general(),
        authorUsername: coachName,
        scores: const [EvaluationScoreInput(key: 'skating', value: 4)],
        comment: 'coming along',
      );
      expect(draft.status, EvaluationStatus.draft);

      await expectLater(
        admin.evaluations.publishEvaluation(draft.id),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidTransition,
          ),
        ),
      );

      await admin.evaluations.deleteEvaluation(draft.id);
    });

    test('15.03: draft → saved → published, and back', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final draft = await admin.evaluations.createEvaluation(
        subjectUsername: memberName,
        templateId: templateId,
        scope: const EvaluationScope.general(),
        authorUsername: coachName,
        scores: const [
          EvaluationScoreInput(key: 'skating', value: 4),
          EvaluationScoreInput(key: 'passing', value: 2),
        ],
        comment: 'solid term',
        coachNote: 'watch the edges',
      );

      final saved = await admin.evaluations.saveEvaluation(draft.id);
      expect(saved.status, EvaluationStatus.saved);
      expect(saved.publishedAtUtc, isNull);

      final published = await admin.evaluations.publishEvaluation(draft.id);
      expect(published.status, EvaluationStatus.published);
      expect(published.publishedAtUtc, isNotNull);

      // A published evaluation is immutable until it is unpublished.
      await expectLater(
        admin.evaluations.updateEvaluation(draft.id, comment: 'second thought'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidState,
          ),
        ),
      );

      final unpublished = await admin.evaluations.unpublishEvaluation(draft.id);
      expect(unpublished.status, EvaluationStatus.saved);
      expect(unpublished.publishedAtUtc, isNull);

      final reverted = await admin.evaluations.revertEvaluation(draft.id);
      expect(reverted.status, EvaluationStatus.draft);

      await admin.evaluations.deleteEvaluation(draft.id);
    });

    test('15.04: a score outside the template bounds is refused', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      await expectLater(
        admin.evaluations.createEvaluation(
          subjectUsername: memberName,
          templateId: templateId,
          scope: const EvaluationScope.general(),
          authorUsername: coachName,
          scores: const [EvaluationScoreInput(key: 'skating', value: 9)],
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidScore,
          ),
        ),
      );

      await expectLater(
        admin.evaluations.createEvaluation(
          subjectUsername: memberName,
          templateId: templateId,
          scope: const EvaluationScope.general(),
          authorUsername: coachName,
          scores: const [EvaluationScoreInput(key: 'stickhandling', value: 3)],
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.invalidScore,
          ),
        ),
      );
    });

    test('15.05: applying a template seeds the default scores', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final applied = await admin.evaluations.applyTemplate(
        templateId,
        subjectUsername: memberName,
        scope: const EvaluationScope.general(),
        comment: 'from template',
      );
      expect(applied.status, EvaluationStatus.draft);
      expect(applied.templateId, templateId);
      final skating = applied.scores.firstWhere((s) => s.key == 'skating');
      expect(skating.value, 3, reason: "the category's defaultValue");

      await admin.evaluations.deleteEvaluation(applied.id);
    });

    test('15.06: a template in use cannot be deleted', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final draft = await admin.evaluations.createEvaluation(
        subjectUsername: memberName,
        templateId: templateId,
        scope: const EvaluationScope.general(),
        authorUsername: coachName,
      );

      await expectLater(
        admin.evaluations.deleteTemplate(templateId),
        throwsA(
          isA<ServerException>().having(
            (e) => e.code,
            'code',
            SdkErrorCode.templateInUse,
          ),
        ),
      );

      await admin.evaluations.deleteEvaluation(draft.id);
    });

    test(
      '15.07: a member sees published evaluations without the coach note',
      () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final draft = await admin.evaluations.createEvaluation(
          subjectUsername: memberName,
          templateId: templateId,
          scope: const EvaluationScope.general(),
          authorUsername: coachName,
          scores: const [EvaluationScoreInput(key: 'skating', value: 5)],
          comment: 'excellent',
          coachNote: 'private note',
        );

        // Unpublished: the member cannot tell it exists.
        await expectLater(
          member.myEvaluations.getMyEvaluation(memberName, draft.id),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 404),
          ),
        );

        await admin.evaluations.saveEvaluation(draft.id);
        await admin.evaluations.publishEvaluation(draft.id);

        final mine = await member.myEvaluations.listMyEvaluations(memberName);
        expect(mine.items.map((e) => e.id), contains(draft.id));

        final one = await member.myEvaluations.getMyEvaluation(
          memberName,
          draft.id,
        );
        expect(one.comment, 'excellent');
        expect(one.toMap().containsKey('coachNote'), isFalse);
      },
    );

    test("15.08: a member cannot read another member's evaluations", () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      await expectLater(
        member.myEvaluations.listMyEvaluations(otherName),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    });

    test('15.09: an unknown evaluation is a 404', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      await expectLater(
        admin.evaluations.getEvaluation(999999),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'status', 404)
              .having((e) => e.code, 'code', SdkErrorCode.evaluationNotFound),
        ),
      );
    });
  });
}
