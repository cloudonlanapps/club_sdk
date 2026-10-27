import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 76: a template's printed texts are `{language: text}` only, and
/// `fillClause` fills one library clause with facts for the editor to
/// insert as custom text (club_server#107).
void main() {
  group('Issue 76: text-only templates and filling a clause', () {
    const password = 'password123';
    const memberName = 'test_i76_member';

    late SecureClient admin;
    late SecureClient member;
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
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: memberName,
        email: '$memberName@test.com',
        password: password,
        firstName: memberName,
        phone: '0000000076',
        dateOfBirthUtc: DateTime.utc(2012, 4, 5),
        gender: Gender.male,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      on = (await stackCapabilities(admin)).applications;

      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login(memberName, password);
      expect((await member.auth.getCurrentUser()).username, memberName);
    });

    tearDownAll(() async {
      for (final id in created) {
        await admin.applications.deleteApplication(id);
      }
      await member.auth.logout();
      await admin.auth.logout();
    });

    test('Issue 76: a rule filled with its facts comes back in every '
        'library language, with its heading', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final library = await admin.applications.getClauses();
      final filled = await admin.applications.fillClause(
        'rule.matches',
        facts: {'dates': matches, 'venue': venue},
      );
      expect(filled.clause, 'rule.matches');
      expect(filled.text.texts.keys, unorderedEquals(library.languages));
      expect(filled.heading?.texts.keys, unorderedEquals(library.languages));
      expect(filled.text.texts['en'], contains('City Rink'));
      expect(filled.text.texts['en'], contains('November 2026'));
      expect(filled.text.texts['mr'], contains('सिटी रिंक'));
    });

    test('Issue 76: a clause that is not a rule has no heading', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final filled = await admin.applications.fillClause('declaration.trial');
      expect(filled.heading, isNull);
      expect(filled.text.texts['en'], isNotEmpty);
    });

    test('Issue 76: a fill that does not match the clause is 422 '
        'APPLICATION_INVALID_REFERENCE', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final invalid = refused(422, SdkErrorCode.applicationInvalidReference);
      // An unknown clause.
      await expectLater(admin.applications.fillClause('rule.nowhere'), invalid);
      // A gap without a fact.
      await expectLater(
        admin.applications.fillClause('rule.matches', facts: {'venue': venue}),
        invalid,
      );
      // A fact for no gap.
      await expectLater(
        admin.applications.fillClause(
          'rule.matches',
          facts: {
            'dates': matches,
            'venue': venue,
            'extra': const ApplicationFact.amount(1),
          },
        ),
        invalid,
      );
      // A fact of the wrong type.
      await expectLater(
        admin.applications.fillClause(
          'rule.matches',
          facts: {'dates': const ApplicationFact.amount(1), 'venue': venue},
        ),
        invalid,
      );
    });

    test('Issue 76: a member may not fill a clause', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        member.applications.fillClause('declaration.trial'),
        refused(403, SdkErrorCode.insufficientPermission),
      );
    });

    test('Issue 76: a template of filled and written texts round-trips, '
        'keeping its facts', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final rule = await admin.applications.fillClause(
        'rule.matches',
        facts: {'dates': matches, 'venue': venue},
      );
      final declaration = await admin.applications.fillClause(
        'declaration.trial',
      );
      final content = ApplicationContent(
        facts: {'matches': matches, 'venue': venue},
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
