import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/application_fixtures.dart';
import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 96: the club library after club_server#133 — the built-in clauses
/// seeded as library texts, the club's labels and their edit, and the
/// club's languages (`ProfileOptions.languages`, `{code, name}`) as the
/// application languages.
///
/// Applications and the extended profile are on in `sdk_test_server1.conf`
/// (`just test-one`); every case skips on `just test-server2`.
void main() {
  group('Issue 96: library, labels and club languages', () {
    late SecureClient admin;
    late Capabilities capabilities;
    late ProfileOptions originalOptions;
    final templates = <int>[];

    // A language no club test stack has: the server knows its code.
    const gujarati = ProfileLanguage(code: 'gu', name: 'Gujarati');

    Matcher refused(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code),
    );

    Matcher notOffered(List<String> languages) => throwsA(
      isA<ApplicationLanguageNotOfferedException>()
          .having((e) => e.statusCode, 'statusCode', 422)
          .having((e) => e.languages, 'languages', languages),
    );

    bool skipUnlessBoth() =>
        skipUnless(
          enabled: capabilities.applications,
          module: 'applications',
        ) ||
        skipUnless(
          enabled: capabilities.extendedProfile,
          module: 'extended profile',
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
      capabilities = await stackCapabilities(admin);
      originalOptions = await admin.users.getProfileOptions();
    });

    tearDownAll(() async {
      if (capabilities.extendedProfile) {
        await admin.users.setProfileOptions(originalOptions);
      }
      for (final id in templates) {
        await admin.applications.deleteApplication(id);
      }
      await admin.auth.logout();
    });

    test("Issue 96: the profile options' languages are codes and names, "
        'English among them, and they are the application languages', () async {
      if (skipUnlessBoth()) return;
      final options = await admin.users.getProfileOptions();
      expect(options.language('en')?.name, 'English');
      expect(options.codes, isNot(contains(gujarati.code)));
      final labels = await admin.applications.getLabels();
      final clauses = await admin.applications.getClauses();
      expect(labels.languages, options.codes);
      expect(clauses.languages, options.codes);
    });

    test('Issue 96: a written language list is stored as written and read '
        'back as codes and names', () async {
      if (skipUnlessBoth()) return;
      final written = await admin.users.setProfileOptions(
        originalOptions.copyWith(
          languages: [...originalOptions.languages, gujarati],
        ),
      );
      expect(written.language('gu'), gujarati);
      expect(await admin.users.getProfileOptions(), written);
      expect((await admin.applications.getLabels()).languages, written.codes);
      await admin.users.setProfileOptions(originalOptions);
    });

    test('Issue 96: a language list without English is refused', () async {
      if (skipUnlessBoth()) return;
      await expectLater(
        admin.users.setProfileOptions(
          const ProfileOptions(languages: [gujarati]),
        ),
        refused(422, SdkErrorCode.invalidPreferenceValue),
      );
      expect(await admin.users.getProfileOptions(), originalOptions);
    });

    test('Issue 96: a print language the club lacks is '
        'ApplicationLanguageNotOfferedException naming it', () async {
      if (skipUnlessBoth()) return;
      await expectLater(
        admin.applications.createApplication(
          const ApplicationContent(languages: ['en', 'gu']),
        ),
        notOffered(['gu']),
      );
    });

    test('Issue 96: a library text in a language the club lacks is '
        'refused the same way', () async {
      if (skipUnlessBoth()) return;
      await expectLater(
        admin.applications.createLibraryText(
          const ApplicationLibraryTextInput(
            kind: ApplicationClauseKind.note,
            name: 'test_i96 note',
            text: ApplicationText({'en': 'Be on time.', 'gu': 'સમયસર.'}),
          ),
        ),
        notOffered(['gu']),
      );
    });

    test('Issue 96: a seeded clause is a library text: it is changed like '
        'any other and keeps its key', () async {
      if (skipUnlessBoth()) return;
      final seeded = (await admin.applications.getClauses()).clauseWithKey(
        'note.follow_rules',
      );
      expect(seeded, isNotNull);
      expect(seeded!.key, 'note.follow_rules');
      expect(await admin.applications.getLibraryText(seeded.id), seeded);
      try {
        final renamed = await admin.applications.updateLibraryText(
          seeded.id,
          const ApplicationLibraryTextPatch(name: 'test_i96 follow rules'),
        );
        expect(renamed.name, 'test_i96 follow rules');
        expect(renamed.key, 'note.follow_rules');
        expect(
          (await admin.applications.getClauses())
              .clauseWithKey('note.follow_rules')
              ?.name,
          'test_i96 follow rules',
        );
      } finally {
        await admin.applications.updateLibraryText(
          seeded.id,
          ApplicationLibraryTextPatch(name: seeded.name),
        );
      }
    });

    test("Issue 96: an admin edits a label's text and reads it back", () async {
      if (skipUnlessBoth()) return;
      const key = 'field.full_name';
      final before = await admin.applications.getLabels();
      final original = ApplicationText(before.labels[key]!);
      try {
        final edited = await admin.applications.updateLabel(
          key,
          const ApplicationText({'en': 'Name of the player'}),
        );
        expect(edited.key, key);
        expect(edited.text.texts['en'], 'Name of the player');
        expect(
          (await admin.applications.getLabels()).label(key, 'en'),
          'Name of the player',
        );
      } finally {
        await admin.applications.updateLabel(key, original);
      }
      expect(await admin.applications.getLabels(), before);
    });

    test(
      'Issue 96: an unknown label is 404 APPLICATION_LABEL_NOT_FOUND',
      () async {
        if (skipUnlessBoth()) return;
        await expectLater(
          admin.applications.updateLabel(
            'field.test_i96_nowhere',
            const ApplicationText({'en': 'x'}),
          ),
          refused(404, SdkErrorCode.applicationLabelNotFound),
        );
      },
    );

    test(
      'Issue 96: a label edit without English is 422, and one in a '
      'language the club lacks is ApplicationLanguageNotOfferedException',
      () async {
        if (skipUnlessBoth()) return;
        final before = await admin.applications.getLabels();
        await expectLater(
          admin.applications.updateLabel(
            'field.full_name',
            const ApplicationText({'mr': 'नाव'}),
          ),
          refused(422, SdkErrorCode.validationError),
        );
        await expectLater(
          admin.applications.updateLabel(
            'field.full_name',
            const ApplicationText({'en': 'Name', 'gu': 'નામ'}),
          ),
          notOffered(['gu']),
        );
        expect(await admin.applications.getLabels(), before);
      },
    );

    test('Issue 96: once a language is added, save lists the labels that '
        'lack it as labels.<key>', () async {
      if (skipUnlessBoth()) return;
      await admin.users.setProfileOptions(
        originalOptions.copyWith(
          languages: [...originalOptions.languages, gujarati],
        ),
      );
      try {
        final complete = ApplicationContent.fromMap(applicationContentJson());
        final draft = await admin.applications.createApplication(
          complete.copyWith(languages: const ['en', 'gu']),
        );
        templates.add(draft.id);
        Object? error;
        try {
          await admin.applications.saveApplication(draft.id);
        } on ApplicationIncompleteException catch (e) {
          error = e;
        }
        expect(error, isA<ApplicationIncompleteException>());
        final missing = (error! as ApplicationIncompleteException).missing;
        final labels = [
          for (final m in missing)
            if (m.labelKey != null) m,
        ];
        expect(labels, isNotEmpty);
        expect(labels.map((m) => m.labelKey), contains('field.full_name'));
        for (final m in labels) {
          expect(m.field, 'labels.${m.labelKey}');
          expect(m.languages, ['gu']);
        }
      } finally {
        await admin.users.setProfileOptions(originalOptions);
      }
    });
  });
}
