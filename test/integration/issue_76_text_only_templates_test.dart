import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 76: a template's printed texts are `{language: text}` only
/// (club_server#107). The editor pastes a library clause's text as written,
/// gaps included (club_server#126, #92).
void main() {
  group('Issue 76: text-only templates', () {
    late SecureClient admin;
    late bool on;
    final created = <int>[];

    final matches = ApplicationFact.dateRange(
      DateTime.utc(2026, 11, 19),
      DateTime.utc(2026, 11, 21),
    );
    const venue = ApplicationFact.localizedName({
      'en': 'City Rink',
      'mr': 'सिटी रिंक',
    });

    Matcher refused(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code),
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
      on = (await stackCapabilities(admin)).applications;
    });

    tearDownAll(() async {
      for (final id in created) {
        await admin.applications.deleteApplication(id);
      }
      await admin.auth.logout();
    });

    test('Issue 76: a template of pasted and written texts round-trips, '
        'keeping its facts', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final library = await admin.applications.getClauses();
      final rule = library.builtinClause('rule.matches')!;
      final declaration = library.builtinClause('declaration.trial')!;
      final content = ApplicationContent(
        facts: {'dates': matches, 'venue': venue},
        title: const ApplicationText({'en': 'Issue 76 — Trial'}),
        header: [
          ApplicationHeaderItem.lines([
            const ApplicationText({'en': 'City Rink'}),
            rule.text,
          ]),
        ],
        declaration: ApplicationText({'en': declaration.text.texts['en']!}),
        formFooter: const ApplicationText({'en': 'Play fair.'}),
        terms: [ApplicationTerm(heading: rule.heading!, body: rule.text)],
        termsNotes: const [
          ApplicationTermsNote(text: ApplicationText({'en': 'Go'})),
        ],
      );
      final draft = await admin.applications.createApplication(content);
      created.add(draft.id);
      expect(draft.content, content);
      final read = await admin.applications.getApplication(draft.id);
      expect(read.content.toMap(), content.toMap());
      expect(read.content.facts, content.facts);
    });

    test('Issue 76: a clause or fact reference in a text is refused with '
        '422', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      // The SDK no longer builds a reference, so send one as a map whose
      // keys are not languages: the server's shape check refuses it.
      const references = [
        ApplicationText({'clause': 'declaration.trial'}),
        ApplicationText({'fact': 'venue'}),
      ];
      final before = await admin.applications.listApplications(limit: 100);
      for (final ref in references) {
        await expectLater(
          admin.applications.createApplication(
            ApplicationContent(declaration: ref),
          ),
          refused(422, SdkErrorCode.validationError),
        );
        await expectLater(
          admin.applications.createApplication(
            ApplicationContent(
              terms: [
                ApplicationTerm(
                  heading: const ApplicationText({'en': 'Fee'}),
                  body: ref,
                ),
              ],
            ),
          ),
          refused(422, SdkErrorCode.validationError),
        );
      }
      final after = await admin.applications.listApplications(limit: 100);
      expect(after.total, before.total);

      final draft = await admin.applications.createApplication(
        const ApplicationContent(),
      );
      created.add(draft.id);
      await expectLater(
        admin.applications.updateApplication(
          draft.id,
          ApplicationPatch(subtitle: () => references.last),
        ),
        refused(422, SdkErrorCode.validationError),
      );
      expect(
        (await admin.applications.getApplication(draft.id)).content.subtitle,
        isNull,
      );
    });
  });
}
