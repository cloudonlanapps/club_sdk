import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// Issue 54: the evaluation calls no test reached — the delete lifecycle of
/// evaluations and templates, `updateTemplate`, `transferEvaluation` and
/// `listMyEvaluationMedia`. Also the fixes they would have caught:
/// re-sending fetched categories (#46) and media linked to an evaluation
/// (#42).
///
/// Needs the evaluations module: every test skips on the default stack.
/// Run with `just test-modules issue_54_evaluation_lifecycle_test.dart`.
void main() {
  group('Issue 54: evaluation lifecycle', () {
    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient member;
    late bool evaluationsOn;
    late int templateId;

    const memberName = 'test_i54_member';
    const coachName = 'test_i54_coach';
    const otherCoachName = 'test_i54_coach2';
    const adminName = 'test_i54_admin';
    const password = 'password123';
    final suffix = DateTime.now().millisecondsSinceEpoch;

    const categories = [
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
    ];

    Future<EvaluationStaffView> draft({String author = coachName}) =>
        sudo.evaluations.createEvaluation(
          subjectUsername: memberName,
          templateId: templateId,
          scope: const EvaluationScope.general(),
          authorUsername: author,
          scores: const [EvaluationScoreInput(key: 'skating', value: 4)],
          comment: 'i54',
        );

    Future<EvaluationTemplate> newTemplate(String name) =>
        sudo.evaluations.createTemplate(
          name: 'test_i54_${name}_$suffix',
          scopes: const [EvaluationScopeType.general],
          categories: categories,
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

      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await admin.auth.login(adminName, password);
      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login(memberName, password);

      if (evaluationsOn) {
        templateId = (await newTemplate('main')).id;
      }
    });

    tearDownAll(() async {
      await member.auth.logout();
      await admin.auth.logout();
      await sudo.auth.logout();
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

        final deleted = await sudo.evaluations.deleteEvaluation(id);
        expect(deleted.deletedAtUtc, isNotNull);

        final active = await sudo.evaluations.listEvaluations(
          subjectUsername: memberName,
          limit: 100,
        );
        expect(active.items.map((e) => e.id), isNot(contains(id)));
        final gone = await sudo.evaluations.listDeletedEvaluations(limit: 100);
        expect(gone.items.map((e) => e.id), contains(id));
      });

      test('54.02: restore moves it back', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final restored = await sudo.evaluations.restoreEvaluation(id);
        expect(restored.deletedAtUtc, isNull);

        final active = await sudo.evaluations.listEvaluations(
          subjectUsername: memberName,
          limit: 100,
        );
        expect(active.items.map((e) => e.id), contains(id));
        final gone = await sudo.evaluations.listDeletedEvaluations(limit: 100);
        expect(gone.items.map((e) => e.id), isNot(contains(id)));
      });

      test('54.03: hard-delete of an active evaluation is refused', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.hardDeleteEvaluation(id),
          throwsA(isA<ServerException>()),
        );
      });

      test('54.04: a regular admin cannot hard-delete', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await sudo.evaluations.deleteEvaluation(id);
        await expectLater(
          admin.evaluations.hardDeleteEvaluation(id),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        final gone = await sudo.evaluations.listDeletedEvaluations(limit: 100);
        expect(gone.items.map((e) => e.id), contains(id));
      });

      test('54.05: the super admin hard-deletes; it leaves both '
          'listings', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await sudo.evaluations.hardDeleteEvaluation(id);

        final active = await sudo.evaluations.listEvaluations(
          subjectUsername: memberName,
          limit: 100,
        );
        expect(active.items.map((e) => e.id), isNot(contains(id)));
        final gone = await sudo.evaluations.listDeletedEvaluations(limit: 100);
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

        final deleted = await sudo.evaluations.deleteTemplate(id);
        expect(deleted.deletedAtUtc, isNotNull);

        final active = await sudo.evaluations.listTemplates(limit: 100);
        expect(active.items.map((t) => t.id), isNot(contains(id)));
        final gone = await sudo.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), contains(id));
      });

      test('54.12: restore moves it back', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final restored = await sudo.evaluations.restoreTemplate(id);
        expect(restored.deletedAtUtc, isNull);

        final active = await sudo.evaluations.listTemplates(limit: 100);
        expect(active.items.map((t) => t.id), contains(id));
        final gone = await sudo.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), isNot(contains(id)));
      });

      test('54.13: hard-delete of an active template is refused', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          sudo.evaluations.hardDeleteTemplate(id),
          throwsA(isA<ServerException>()),
        );
      });

      test('54.14: a regular admin cannot hard-delete', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await sudo.evaluations.deleteTemplate(id);
        await expectLater(
          admin.evaluations.hardDeleteTemplate(id),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        final gone = await sudo.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), contains(id));
      });

      test('54.15: the super admin hard-deletes; it leaves both '
          'listings', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await sudo.evaluations.hardDeleteTemplate(id);

        final active = await sudo.evaluations.listTemplates(limit: 100);
        expect(active.items.map((t) => t.id), isNot(contains(id)));
        final gone = await sudo.evaluations.listDeletedTemplates(limit: 100);
        expect(gone.items.map((t) => t.id), isNot(contains(id)));
      });
    });

    group('updateTemplate', () {
      test('54.21 (#46): re-sending the fetched categories unchanged '
          'succeeds', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final created = await newTemplate('resend');
        final fetched = await sudo.evaluations.getTemplate(created.id);
        expect(fetched.categories.every((c) => c.id != null), isTrue);

        final updated = await sudo.evaluations.updateTemplate(
          created.id,
          name: 'test_i54_resent_$suffix',
          categories: fetched.categories,
        );
        expect(updated.name, 'test_i54_resent_$suffix');
        expect(updated.categories.map((c) => c.key), ['skating', 'passing']);
      });

      test("54.22 (#46): a fetched template's categories create a "
          'copy', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final source = await sudo.evaluations.getTemplate(templateId);
        final copy = await sudo.evaluations.createTemplate(
          name: 'test_i54_copy_$suffix',
          scopes: source.scopes,
          categories: source.categories,
        );
        expect(copy.categories.map((c) => c.key), ['skating', 'passing']);
      });

      test('54.23: changes the description and scopes', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final created = await newTemplate('edit');
        final updated = await sudo.evaluations.updateTemplate(
          created.id,
          description: 'edited',
          scopes: const [
            EvaluationScopeType.general,
            EvaluationScopeType.event,
          ],
        );
        expect(updated.description, 'edited');
        expect(
          updated.scopes,
          unorderedEquals([
            EvaluationScopeType.general,
            EvaluationScopeType.event,
          ]),
        );
        expect(
          (await sudo.evaluations.getTemplate(created.id)).description,
          'edited',
        );
      });
    });

    group('transferEvaluation', () {
      test('54.31: moves a draft to another coach', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        expect(e.authorUsername, coachName);

        final moved = await sudo.evaluations.transferEvaluation(
          e.id,
          newAuthorUsername: otherCoachName,
        );
        expect(moved.authorUsername, otherCoachName);
        expect(
          (await sudo.evaluations.getEvaluation(e.id)).authorUsername,
          otherCoachName,
        );
      });

      test('54.32: to a user who is not staff is refused', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final e = await draft();
        await expectLater(
          sudo.evaluations.transferEvaluation(
            e.id,
            newAuthorUsername: memberName,
          ),
          throwsA(isA<ServerException>()),
        );
        expect(
          (await sudo.evaluations.getEvaluation(e.id)).authorUsername,
          coachName,
        );
      });
    });

    group('evaluation media', () {
      late int id;
      late Media shared;
      late Media private;

      setUpAll(() async {
        if (!evaluationsOn) return;
        id = (await draft()).id;
        shared = await sudo.media.upload(
          fileBytes: testPngBytes,
          filename: 'test_i54_shared.png',
          contentType: 'image/png',
          preserveOriginal: true,
        );
        private = await sudo.media.upload(
          fileBytes: testPngBytes,
          filename: 'test_i54_private.png',
          contentType: 'image/png',
          preserveOriginal: true,
        );
        await sudo.evaluationMedia.attach(
          id,
          tag: 'shared_clips',
          mediaUuid: shared.uuid,
        );
        await sudo.evaluationMedia.attach(
          id,
          tag: 'coach_notes',
          mediaUuid: private.uuid,
        );
      });

      test('54.41 (#42): getLinks reports the evaluation owner', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final links = await sudo.media.getLinks(shared.uuid);
        expect(links, hasLength(1));
        expect(links.single.ownerType, MediaLinkOwnerType.evaluation);
        expect(links.single.ownerId, '$id');
        expect(links.single.tag, 'shared_clips');
      });

      test('54.42 (#42): searchLinks with no owner filter lists evaluation '
          'media', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        final page = await sudo.media.searchLinks(tag: 'shared_clips');
        expect(
          page.items.where(
            (l) =>
                l.ownerType == MediaLinkOwnerType.evaluation &&
                l.mediaUuid == shared.uuid,
          ),
          hasLength(1),
        );
        // The whole unfiltered page parses too.
        await sudo.media.searchLinks(limit: 100);
      });

      test(
        '54.43 (#42): searchLinks filters by the evaluation owner',
        () async {
          if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

          final page = await sudo.media.searchLinks(
            ownerType: MediaLinkOwnerType.evaluation,
            limit: 100,
          );
          expect(
            page.items.map((l) => l.mediaUuid),
            containsAll([shared.uuid, private.uuid]),
          );
          expect(
            page.items.every(
              (l) => l.ownerType == MediaLinkOwnerType.evaluation,
            ),
            isTrue,
          );
        },
      );

      test('54.44: listMyEvaluationMedia is 404 before publication', () async {
        if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

        await expectLater(
          member.myEvaluations.listMyEvaluationMedia(memberName, id),
          throwsA(
            isA<ServerException>().having((e) => e.statusCode, 'status', 404),
          ),
        );
      });

      test(
        '54.45: once published, the member sees only shared_ tags',
        () async {
          if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

          await sudo.evaluations.saveEvaluation(id);
          await sudo.evaluations.publishEvaluation(id);

          final media = await member.myEvaluations.listMyEvaluationMedia(
            memberName,
            id,
          );
          expect(media.keys, ['shared_clips']);
          expect(media['shared_clips']!.single.mediaUuid, shared.uuid);
        },
      );
    });
  });
}
