import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/application_fixtures.dart';
import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 92: `{fact}` gaps in application texts, Save's unknown-fact
/// refusal, the club's library of texts and the clauses list that merges
/// it with the built-in clauses (club_server#126).
///
/// Applications are on in `sdk_test_server1.conf` (`just test-one`); the
/// module-off case runs on `just test-server2`.
void main() {
  group('Issue 92: fact gaps and the club library', () {
    const password = 'password123';
    const memberName = 'test_i92_member';

    late RemoteStore adminStore;
    late SecureClient admin;
    late SecureClient member;
    late SecureClient anonymous;
    late bool on;
    final templates = <int>[];
    final libraryTexts = <int>[];

    Matcher refused(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code),
    );

    Matcher isPdf() => isA<List<int>>().having(
      (b) => String.fromCharCodes(b.take(4)),
      'first bytes',
      '%PDF',
    );

    // A complete English + Marathi template that saves (the unit fixture,
    // club_server's own `template_body`); each test puts gaps into it.
    final complete = ApplicationContent.fromMap(applicationContentJson());

    Future<ApplicationTemplate> draft(ApplicationContent content) async {
      final created = await admin.applications.createApplication(content);
      templates.add(created.id);
      return created;
    }

    Future<ApplicationLibraryText> libraryText(
      ApplicationLibraryTextInput input,
    ) async {
      final created = await admin.applications.createLibraryText(input);
      libraryTexts.add(created.id);
      return created;
    }

    setUpAll(() async {
      adminStore = RemoteStore(baseUrl: baseUrl);
      admin = await createRemoteSecureClient(
        baseUrl: baseUrl,
        store: adminStore,
      );
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
        phone: '0000000092',
        dateOfBirthUtc: DateTime.utc(2012, 4, 5),
        gender: Gender.male,
      );
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      on = (await stackCapabilities(admin)).applications;

      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login(memberName, password);
      expect((await member.auth.getCurrentUser()).username, memberName);
      anonymous = await createRemoteSecureClient(baseUrl: baseUrl);

      // Club texts are not `test_`-named entities clearTestArtifacts
      // knows; drop any this file left behind on a kept stack.
      if (on) {
        for (final text in await admin.applications.listLibraryTexts()) {
          if (text.name.startsWith('test_i92')) {
            await admin.applications.deleteLibraryText(text.id);
          }
        }
      }
    });

    tearDownAll(() async {
      for (final id in templates) {
        await admin.applications.deleteApplication(id);
      }
      for (final id in libraryTexts) {
        await admin.applications.deleteLibraryText(id);
      }
      await member.auth.logout();
      await admin.auth.logout();
    });

    // ── Gaps in a template's texts ──────────────────────────────────────

    test('Issue 92: a draft keeps its gaps as written, even one naming no '
        'fact, on create and on edit', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final content = complete.copyWith(
        title: () => const ApplicationText({
          'en': 'Trial at {venue} — {nowhere}',
          'mr': '{venue} येथे चाचणी',
        }),
      );
      final created = await draft(content);
      expect(created.content.title, content.title);
      final read = await admin.applications.getApplication(created.id);
      expect(read.content.toMap(), content.toMap());

      const subtitle = ApplicationText({
        'en': 'From {camp} {Venue} { x }',
        'mr': '{also_nowhere}',
      });
      final edited = await admin.applications.updateApplication(
        created.id,
        ApplicationPatch(subtitle: () => subtitle),
      );
      expect(edited.content.subtitle, subtitle);
      expect(
        (await admin.applications.getApplication(created.id)).content.subtitle,
        subtitle,
      );
    });

    test('Issue 92: Save refuses a gap naming no fact with each place, '
        'language and gap, a Marathi-only gap included', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final created = await draft(
        complete.copyWith(
          title: () => const ApplicationText({
            'en': 'Trial at {venue} on {trial_day}',
            'mr': '{venue} येथे चाचणी',
          }),
          selections: const [
            ApplicationText({
              'en': 'I will attend the camp on {camp}.',
              'mr': 'मी {camp_dates} रोजीच्या शिबिरास उपस्थित राहीन.',
            }),
          ],
        ),
      );
      try {
        await admin.applications.saveApplication(created.id);
        fail('Save accepted gaps naming no fact');
      } on ApplicationUnknownFactException catch (e) {
        expect(e.statusCode, 422);
        expect(e.code, SdkErrorCode.applicationUnknownFact);
        expect(e.gaps, const [
          ApplicationUnknownGap(
            place: 'title',
            language: 'en',
            gap: 'trial_day',
          ),
          ApplicationUnknownGap(
            place: 'selections[0]',
            language: 'mr',
            gap: 'camp_dates',
          ),
        ]);
      }
      final after = await admin.applications.getApplication(created.id);
      expect(after.status, ApplicationStatus.draft);
      expect(after.layout, isNull);
    });

    test('Issue 92: Save refuses an unknown gap in a header line and in a '
        'term', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final created = await draft(
        complete.copyWith(
          header: const [
            ApplicationHeaderItem.single(ApplicationText({'en': '{venue}'})),
            ApplicationHeaderItem.lines([
              ApplicationText({'en': 'Camp: {camp}'}),
              ApplicationText({'en': 'Matches: {match_days}'}),
            ]),
          ],
          terms: const [
            ApplicationTerm(
              heading: ApplicationText({'en': 'Fee', 'mr': 'शुल्क'}),
              body: ApplicationText({
                'en': 'Pay {fees} by {trialDay}.',
                'mr': '{fees} भरा.',
              }),
            ),
          ],
        ),
      );
      await expectLater(
        admin.applications.saveApplication(created.id),
        throwsA(
          isA<ApplicationUnknownFactException>().having(
            (e) => e.gaps,
            'gaps',
            const [
              ApplicationUnknownGap(
                place: 'header[1][1]',
                language: 'en',
                gap: 'match_days',
              ),
              ApplicationUnknownGap(
                place: 'terms[0].body',
                language: 'en',
                gap: 'fees',
              ),
              ApplicationUnknownGap(
                place: 'terms[0].body',
                language: 'mr',
                gap: 'fees',
              ),
            ],
          ),
        ),
      );
    });

    test('Issue 92: Save accepts gaps that name facts, other braces are '
        'literal, and the forms are drawn', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final created = await draft(
        complete.copyWith(
          title: () => const ApplicationText({
            'en': 'Selection Trial at {venue}',
            'mr': '{venue} येथे निवड चाचणी',
          }),
          subtitle: () => const ApplicationText({
            'en': '{camp} {Venue} { x } {1st}',
            'mr': '{camp}',
          }),
          selections: const [
            ApplicationText({
              'en': 'I will attend the {surface} camp on {camp}.',
              'mr': 'मी {camp} रोजीच्या शिबिरास उपस्थित राहीन.',
            }),
          ],
        ),
      );
      expect(await admin.applications.downloadPreview(created.id), isPdf());
      final saved = await admin.applications.saveApplication(created.id);
      expect(saved.status, ApplicationStatus.saved);
      expect(saved.layout, isNotNull);
      expect(saved.content.title?.texts['en'], 'Selection Trial at {venue}');
      expect(await admin.applications.downloadPreview(created.id), isPdf());
    });

    // ── The club library ────────────────────────────────────────────────

    test('Issue 92: an admin creates, reads, lists, changes and deletes a '
        'club text', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final before = DateTime.now().toUtc().subtract(
        const Duration(minutes: 5),
      );
      const input = ApplicationLibraryTextInput(
        kind: ApplicationClauseKind.rule,
        name: 'test_i92 Match days',
        heading: ApplicationText({'en': 'Matches', 'mr': 'सामने'}),
        text: ApplicationText({
          'en': 'Matches are played on {match_dates} at {venue}.',
          'mr': '{match_dates} रोजी {venue} येथे सामने.',
          'hi': '{match_dates} को {venue} पर मैच।',
        }),
      );
      final created = await libraryText(input);
      expect(created.kind, input.kind);
      expect(created.name, input.name);
      expect(created.heading, input.heading);
      expect(created.text, input.text);
      expect(created.createdBy, sudoUsername);
      expect(created.createdAtUtc.isAfter(before), isTrue);

      expect(await admin.applications.getLibraryText(created.id), created);
      expect(
        (await admin.applications.listLibraryTexts()).where(
          (t) => t.id == created.id,
        ),
        [created],
      );

      final renamed = await admin.applications.updateLibraryText(
        created.id,
        const ApplicationLibraryTextPatch(name: 'test_i92 Matches'),
      );
      expect(renamed.name, 'test_i92 Matches');
      expect(renamed.heading, input.heading);
      expect(renamed.text, input.text);

      final asNote = await admin.applications.updateLibraryText(
        created.id,
        ApplicationLibraryTextPatch(
          kind: ApplicationClauseKind.note,
          heading: () => null,
          text: const ApplicationText({'en': 'See you at {venue}.'}),
        ),
      );
      expect(asNote.kind, ApplicationClauseKind.note);
      expect(asNote.heading, isNull);
      expect(asNote.text, const ApplicationText({'en': 'See you at {venue}.'}));
      expect(await admin.applications.getLibraryText(created.id), asNote);

      await admin.applications.deleteLibraryText(created.id);
      libraryTexts.remove(created.id);
      await expectLater(
        admin.applications.getLibraryText(created.id),
        refused(404, SdkErrorCode.applicationLibraryTextNotFound),
      );
      expect(
        (await admin.applications.listLibraryTexts()).map((t) => t.id),
        isNot(contains(created.id)),
      );
    });

    test('Issue 92: the library lists texts oldest first', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final first = await libraryText(
        const ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.declaration,
          name: 'test_i92 first',
          text: ApplicationText({'en': 'I agree.'}),
        ),
      );
      final second = await libraryText(
        const ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.header,
          name: 'test_i92 second',
          text: ApplicationText({'en': 'At {venue}'}),
        ),
      );
      final ids = (await admin.applications.listLibraryTexts())
          .map((t) => t.id)
          .where((id) => id == first.id || id == second.id);
      expect(ids, [first.id, second.id]);
    });

    test('Issue 92: only a rule has a heading; a refused change leaves the '
        'text as it was', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final validation = refused(422, SdkErrorCode.validationError);
      await expectLater(
        admin.applications.createLibraryText(
          const ApplicationLibraryTextInput(
            kind: ApplicationClauseKind.note,
            name: 'test_i92 headed note',
            heading: ApplicationText({'en': 'Note'}),
            text: ApplicationText({'en': 'Follow the rules.'}),
          ),
        ),
        validation,
      );
      final note = await libraryText(
        const ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.note,
          name: 'test_i92 note',
          text: ApplicationText({'en': 'Follow the rules.'}),
        ),
      );
      await expectLater(
        admin.applications.updateLibraryText(
          note.id,
          ApplicationLibraryTextPatch(
            heading: () => const ApplicationText({'en': 'Note'}),
          ),
        ),
        validation,
      );
      expect(await admin.applications.getLibraryText(note.id), note);
    });

    test('Issue 92: a name over 100 characters, an empty text or an unknown '
        'language is refused', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final validation = refused(422, SdkErrorCode.validationError);
      for (final input in [
        ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.note,
          name: 'test_i92 ${'x' * 100}',
          text: const ApplicationText({'en': 'Text'}),
        ),
        const ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.note,
          name: 'test_i92 empty',
          text: ApplicationText({}),
        ),
        const ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.note,
          name: 'test_i92 tamil',
          text: ApplicationText({'ta': 'உரை'}),
        ),
      ]) {
        await expectLater(
          admin.applications.createLibraryText(input),
          validation,
          reason: '$input',
        );
      }
    });

    test('Issue 92: an unknown club text is 404 '
        'APPLICATION_LIBRARY_TEXT_NOT_FOUND', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      const unknown = 999999;
      final notFound = refused(
        404,
        SdkErrorCode.applicationLibraryTextNotFound,
      );
      await expectLater(admin.applications.getLibraryText(unknown), notFound);
      await expectLater(
        admin.applications.updateLibraryText(
          unknown,
          const ApplicationLibraryTextPatch(name: 'test_i92 nobody'),
        ),
        notFound,
      );
      await expectLater(
        admin.applications.deleteLibraryText(unknown),
        notFound,
      );
    });

    test(
      'Issue 92: only an admin may use the library: a member is refused 403 '
      'and a visitor 401',
      () async {
        if (skipUnless(enabled: on, module: 'applications')) return;
        final text = await libraryText(
          const ApplicationLibraryTextInput(
            kind: ApplicationClauseKind.note,
            name: 'test_i92 admin only',
            text: ApplicationText({'en': 'Admins only.'}),
          ),
        );
        const input = ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.note,
          name: 'test_i92 by member',
          text: ApplicationText({'en': 'No.'}),
        );
        const patch = ApplicationLibraryTextPatch(name: 'test_i92 changed');
        for (final (client, status, code) in [
          (member, 403, SdkErrorCode.insufficientPermission),
          (anonymous, 401, SdkErrorCode.notAuthenticated),
        ]) {
          final no = refused(status, code);
          await expectLater(client.applications.listLibraryTexts(), no);
          await expectLater(client.applications.getLibraryText(text.id), no);
          await expectLater(client.applications.createLibraryText(input), no);
          await expectLater(
            client.applications.updateLibraryText(text.id, patch),
            no,
          );
          await expectLater(client.applications.deleteLibraryText(text.id), no);
        }
        expect(await admin.applications.getLibraryText(text.id), text);
      },
    );

    // ── The clauses list ────────────────────────────────────────────────

    test('Issue 92: the clauses list holds the built-in clauses, then the '
        'texts of the club, each marked with its source', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final rule = await libraryText(
        const ApplicationLibraryTextInput(
          kind: ApplicationClauseKind.rule,
          name: 'test_i92 listed rule',
          heading: ApplicationText({'en': 'Kit'}),
          text: ApplicationText({'en': 'Bring a helmet to {venue}.'}),
        ),
      );
      final library = await admin.applications.getClauses();
      final sources = library.clauses.map((c) => c.source).toList();
      expect(sources, contains(ApplicationClauseSource.builtin));
      expect(
        sources.indexOf(ApplicationClauseSource.club),
        greaterThan(sources.lastIndexOf(ApplicationClauseSource.builtin)),
      );

      final matches = library.builtinClause('rule.matches')!;
      expect(matches.source, ApplicationClauseSource.builtin);
      expect(matches.id, isNull);
      expect(matches.name, isNull);
      expect(matches.kind, ApplicationClauseKind.rule);
      expect(matches.gaps, {
        'dates': ApplicationFactType.dateRange,
        'venue': ApplicationFactType.name,
      });
      expect(matches.text.texts['en'], contains('{venue}'));

      final listed = library.clubTexts.singleWhere((c) => c.id == rule.id);
      expect(listed.source, ApplicationClauseSource.club);
      expect(listed.key, isNull);
      expect(listed.gaps, isNull);
      expect(listed.name, rule.name);
      expect(listed.kind, ApplicationClauseKind.rule);
      expect(listed.heading, rule.heading);
      expect(listed.text, rule.text);
    });

    test('Issue 92: filling a clause is no longer a route', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        adminStore.post(
          '/applications/clauses/fill',
          body: {'clause': 'declaration.trial', 'facts': <String, dynamic>{}},
        ),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('Issue 92: every library route answers 503 APPLICATIONS_DISABLED '
        'while the module is off', () async {
      if (skipIf(enabled: on, feature: 'applications')) return;
      final off = throwsModuleDisabled(SdkErrorCode.applicationsDisabled);
      await expectLater(admin.applications.listLibraryTexts(), off);
      await expectLater(admin.applications.getLibraryText(1), off);
      await expectLater(
        admin.applications.createLibraryText(
          const ApplicationLibraryTextInput(
            kind: ApplicationClauseKind.note,
            name: 'test_i92 off',
            text: ApplicationText({'en': 'Off.'}),
          ),
        ),
        off,
      );
      await expectLater(
        admin.applications.updateLibraryText(
          1,
          const ApplicationLibraryTextPatch(name: 'test_i92 off'),
        ),
        off,
      );
      await expectLater(admin.applications.deleteLibraryText(1), off);
    });
  });
}
