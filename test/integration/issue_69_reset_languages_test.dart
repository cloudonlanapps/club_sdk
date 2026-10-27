import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 69: `ApplicationPatch(languages: () => null)` resets a draft's
/// print languages to English only (club_server#109), as the
/// `ApplicationPatch` doc says, so a text written in English alone no
/// longer blocks the save.
void main() {
  group('Issue 69: a null languages patch resets to English', () {
    late SecureClient admin;
    late bool on;
    late int appId;

    // English + Marathi, every required text in English only.
    const content = ApplicationContent(
      languages: ['en', 'mr'],
      title: ApplicationText.custom({'en': 'Issue 69 — Registration Form'}),
      declaration: ApplicationText.custom({'en': 'I agree to the rules.'}),
      formFooter: ApplicationText.custom({'en': 'Play fair.'}),
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
      if (on) appId = (await admin.applications.createApplication(content)).id;
    });

    tearDownAll(() async {
      if (on) {
        final t = await admin.applications.getApplication(appId);
        if (t.status == ApplicationStatus.saved) {
          await admin.applications.revertApplication(appId);
        }
        await admin.applications.deleteApplication(appId);
      }
      await admin.auth.logout();
    });

    test('Issue 69: the bilingual draft is refused for its missing '
        'Marathi', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.saveApplication(appId),
        throwsA(
          isA<ApplicationIncompleteException>().having(
            (e) => e.missing,
            'missing',
            containsAll(const [
              ApplicationMissingText(field: 'title', languages: ['mr']),
              ApplicationMissingText(field: 'declaration', languages: ['mr']),
              ApplicationMissingText(field: 'formFooter', languages: ['mr']),
            ]),
          ),
        ),
      );
    });

    test('Issue 69: languages null returns the draft with languages '
        '["en"]', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final patched = await admin.applications.updateApplication(
        appId,
        ApplicationPatch(languages: () => null),
      );
      expect(patched.content.languages, ['en']);
      expect(patched.content.title, content.title);
      final read = await admin.applications.getApplication(appId);
      expect(read.content.languages, ['en']);
    });

    test('Issue 69: once reset, the English-only texts save', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final saved = await admin.applications.saveApplication(appId);
      expect(saved.status, ApplicationStatus.saved);
      expect(saved.content.languages, ['en']);
    });
  });
}
