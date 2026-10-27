import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/identity_document.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 66: printable applications (club_server#93).
///
/// Applications are available only where `applications_enabled` and
/// identity verification are both on. `sdk_test.conf` turns both on, so
/// the lifecycle runs on `just test`; `sdk_test_modules.conf` turns both
/// off, so the 503 case runs on `just test-modules` (#86).
void main() {
  group('Issue 66: applications', () {
    const password = 'password123';
    const adminName = 'test_i66a_admin';
    const memberName = 'test_i66a_member';
    const olderName = 'test_i66a_older';
    const newcomerName = 'test_i66a_newcomer';

    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient member;
    late SecureClient older;
    late SecureClient newcomer;
    late bool on;

    // The template under test, moved through its lifecycle by the tests
    // below in order, and a copy of it.
    late int appId;
    late int copyId;

    Future<void> register(String username, DateTime born, Gender gender) =>
        registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: password,
          firstName: username,
          phone: '0000000066',
          dateOfBirthUtc: born,
          gender: gender,
        );

    Future<SecureClient> signIn(String username) async {
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(username, password);
      expect((await client.auth.getCurrentUser()).username, username);
      return client;
    }

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

    // An English + Marathi selection trial, as an admin would build it:
    // every fact type (kept for the editor, never printed), printed texts
    // as `{language: text}` (club_server#107), a header line of two
    // texts, rules and an attributed note. The footer line has no Marathi,
    // so the first save is refused.
    final content = ApplicationContent(
      languages: const ['en', 'mr'],
      facts: {
        'venue': const ApplicationFact.localizedName({
          'en': 'City Rink',
          'mr': 'सिटी रिंक',
        }),
        'city': const ApplicationFact.name('Example City'),
        'camp': ApplicationFact.dateRange(
          DateTime.utc(2026, 11, 16),
          DateTime.utc(2026, 11, 17),
        ),
        'matches': ApplicationFact.dateRange(
          DateTime.utc(2026, 11, 19),
          DateTime.utc(2026, 11, 21),
        ),
        'arrive': ApplicationFact.date(DateTime.utc(2026, 11, 15)),
        'report': ApplicationFact.date(DateTime.utc(2026, 11, 16)),
        'reportTime': const ApplicationFact.time('6:30'),
        'fee': const ApplicationFact.amount(150000),
        'kinds': const ApplicationFact.choices(['on_ice', 'inline']),
      },
      organisation: const ApplicationText({
        'en': 'EXAMPLE CLUB',
        'mr': 'उदाहरण क्लब',
      }),
      title: const ApplicationText({
        'en': 'Selection Trial — Registration Form',
        'mr': 'निवड चाचणी — नोंदणी अर्ज',
      }),
      subtitle: const ApplicationText({
        'en': '16–17 November 2026',
        'mr': '16–17 नोव्हेंबर 2026',
      }),
      header: const [
        ApplicationHeaderItem.single(
          ApplicationText({'en': 'City Rink', 'mr': 'सिटी रिंक'}),
        ),
        ApplicationHeaderItem.lines([
          ApplicationText({
            'en': 'Training camp: 16–17 November 2026',
            'mr': 'प्रशिक्षण शिबिर: 16–17 नोव्हेंबर 2026',
          }),
          ApplicationText({
            'en': 'Matches: 19–21 November 2026',
            'mr': 'सामने: 19–21 नोव्हेंबर 2026',
          }),
        ]),
      ],
      ageCategories: [
        ApplicationAgeCategory(
          label: const {'en': 'Under-12', 'mr': 'अंडर-12'},
          bornOnOrAfterUtc: DateTime.utc(2014),
        ),
        ApplicationAgeCategory(
          label: const {'en': 'Under-15 Girls', 'mr': 'अंडर-15 मुली'},
          bornOnOrAfterUtc: DateTime.utc(2011),
          genders: const [Gender.female],
        ),
      ],
      selections: const [
        ApplicationText({
          'en': 'I will attend the on-ice and inline practice.',
          'mr': 'मी बर्फावरील आणि इनलाइन सरावास उपस्थित राहीन.',
        }),
      ],
      declaration: const ApplicationText({
        'en': 'I agree to abide by the rules of the trial.',
        'mr': 'मी चाचणीचे नियम पाळण्यास सहमत आहे.',
      }),
      formFooter: const ApplicationText({'en': 'Play fair.'}),
      terms: const [
        ApplicationTerm(
          heading: ApplicationText({'en': 'Identity proof', 'mr': 'ओळखपत्र'}),
          body: ApplicationText({
            'en': 'Bring a proof of identity.',
            'mr': 'ओळखपत्र सोबत आणा.',
          }),
        ),
        ApplicationTerm(
          heading: ApplicationText({'en': 'Fee', 'mr': 'शुल्क'}),
          body: ApplicationText({
            'en': 'A registration fee of ₹1,50,000 is payable.',
            'mr': '₹1,50,000 नोंदणी शुल्क भरावे लागेल.',
          }),
        ),
        ApplicationTerm(
          heading: ApplicationText({'en': 'Kit', 'mr': 'साहित्य'}),
          body: ApplicationText({
            'en': 'Bring your own helmet.',
            'mr': 'स्वतःचे हेल्मेट आणा.',
          }),
        ),
      ],
      termsNotes: const [
        ApplicationTermsNote(
          text: ApplicationText({
            'en': 'Follow the rules.',
            'mr': 'नियम पाळा.',
          }),
        ),
        ApplicationTermsNote(
          text: ApplicationText({
            'en': 'Discipline is the key to success.',
            'mr': 'शिस्त हीच यशाची गुरुकिल्ली.',
          }),
          attribution: ApplicationText({'en': '— Example Club'}),
        ),
      ],
      labelOverrides: const {
        'field.past_experience': {
          'en': 'Past experience — any skating sport',
          'mr': 'पूर्व अनुभव',
        },
      },
    );

    const footer = ApplicationText({
      'en': 'Play fair.',
      'mr': 'खिलाडूवृत्तीने खेळा.',
    });

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      on = (await stackCapabilities(sudo)).applications;

      await register(adminName, DateTime.utc(1985, 2, 3), Gender.male);
      await sudo.users.assignRole(adminName, 'admin');
      await register(memberName, DateTime.utc(2015, 5, 14), Gender.male);
      await register(olderName, DateTime.utc(1990, 6, 7), Gender.male);
      // Signed up, never submitted: `registered`, with no identity document
      // where verification is on.
      await sudo.auth.register(
        username: newcomerName,
        email: '$newcomerName@test.com',
        password: password,
        phone: '0000000068',
        dateOfBirthUtc: DateTime.utc(2016, 3, 4),
        gender: Gender.female,
        firstName: newcomerName,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      expect((await sudo.auth.getCurrentUser()).username, sudoUsername);

      admin = await signIn(adminName);
      member = await signIn(memberName);
      older = await signIn(olderName);
      newcomer = await signIn(newcomerName);
    });

    tearDownAll(() async {
      for (final client in [newcomer, older, member, admin, sudo]) {
        await client.auth.logout();
      }
    });

    // ── The module gate ──────────────────────────────────────────────────

    test('Issue 66: capabilities report applications only with identity '
        'verification', () async {
      final caps = await member.capabilities.getCapabilities();
      expect(caps.applications, on);
      if (caps.applications) expect(caps.identityVerification, isTrue);
      if (!caps.identityVerification) expect(caps.applications, isFalse);
    });

    test('Issue 66: every route answers 503 APPLICATIONS_DISABLED while the '
        'module is off', () async {
      if (skipIf(enabled: on, feature: 'applications')) return;
      final off = throwsModuleDisabled(SdkErrorCode.applicationsDisabled);
      await expectLater(admin.applications.listApplications(), off);
      await expectLater(admin.applications.createApplication(content), off);
      await expectLater(admin.applications.getApplication(1), off);
      await expectLater(admin.applications.getLabels(), off);
      await expectLater(admin.applications.getClauses(), off);
      await expectLater(admin.applications.downloadPreview(1), off);
      await expectLater(member.applications.downloadOwnForm(1), off);
    });

    // ── The editor's catalogues ──────────────────────────────────────────

    test('Issue 66: an admin reads the label catalogue', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final labels = await admin.applications.getLabels();
      expect(labels.languages, containsAll(['en', 'mr', 'hi']));
      expect(labels.labels, contains('field.past_experience'));
      for (final texts in labels.labels.values) {
        expect(texts.keys, containsAll(labels.languages));
      }
    });

    test('Issue 66: an admin reads the clause library', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final library = await admin.applications.getClauses();
      expect(library.languages, containsAll(['en', 'mr', 'hi']));
      expect(library.choices.keys, containsAll(['on_ice', 'inline']));
      final matches = library.clauses['rule.matches']!;
      expect(matches.kind, 'rule');
      expect(matches.gaps, {
        'dates': ApplicationFactType.dateRange,
        'venue': ApplicationFactType.name,
      });
      expect(matches.heading?.keys, containsAll(library.languages));
      expect(
        library.clausesOfKind('declaration'),
        contains('declaration.trial'),
      );
    });

    test('Issue 66: a member may not read the catalogues', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        member.applications.getLabels(),
        refused(403, SdkErrorCode.insufficientPermission),
      );
      await expectLater(
        member.applications.getClauses(),
        refused(403, SdkErrorCode.insufficientPermission),
      );
    });

    // ── Writing a template ───────────────────────────────────────────────

    test('Issue 66: an admin creates a draft whose content reads back as '
        'it was sent', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final created = await admin.applications.createApplication(content);
      appId = created.id;
      expect(created.status, ApplicationStatus.draft);
      expect(created.layout, isNull);
      expect(created.createdBy, adminName);
      expect(created.content, content);
      final read = await admin.applications.getApplication(appId);
      expect(read.content.toMap(), content.toMap());
    });

    test('Issue 66: a member may not create a template', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        member.applications.createApplication(content),
        refused(403, SdkErrorCode.insufficientPermission),
      );
    });

    test('Issue 66: a draft is not offered to a member', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final page = await member.applications.listApplications();
      expect(page.items.map((t) => t.id), isNot(contains(appId)));
      await expectLater(
        member.applications.getApplication(appId),
        refused(404, SdkErrorCode.applicationNotFound),
      );
    });

    test('Issue 66: a draft cannot be published before it is saved', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.publishApplication(appId),
        refused(422, SdkErrorCode.invalidTransition),
      );
      final read = await admin.applications.getApplication(appId);
      expect(read.status, ApplicationStatus.draft);
    });

    test('Issue 66: save refuses a text without a print language, naming '
        'it', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.saveApplication(appId),
        throwsA(
          isA<ApplicationIncompleteException>().having(
            (e) => e.missing,
            'missing',
            contains(
              const ApplicationMissingText(
                field: 'formFooter',
                languages: ['mr'],
              ),
            ),
          ),
        ),
      );
      final read = await admin.applications.getApplication(appId);
      expect(read.status, ApplicationStatus.draft);
    });

    test('Issue 66: a patch replaces what it sends, clears a null and keeps '
        'the rest', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final patched = await admin.applications.updateApplication(
        appId,
        ApplicationPatch(formFooter: () => footer, subtitle: () => null),
      );
      expect(patched.content.formFooter, footer);
      expect(patched.content.subtitle, isNull);
      expect(
        patched.content,
        content.copyWith(formFooter: () => footer, subtitle: () => null),
      );
    });

    test(
      'Issue 66: save stores the layout once the template is complete',
      () async {
        if (skipUnless(enabled: on, module: 'applications')) return;
        final saved = await admin.applications.saveApplication(appId);
        expect(saved.status, ApplicationStatus.saved);
        expect(saved.layout, isNotNull);
        expect(saved.layout!.name, isNotEmpty);
        expect(
          (await admin.applications.getApplication(appId)).layout,
          saved.layout,
        );
      },
    );

    test('Issue 66: a saved template is not edited', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.updateApplication(
          appId,
          ApplicationPatch(title: () => null),
        ),
        refused(422, SdkErrorCode.invalidState),
      );
    });

    test('Issue 66: save refuses a form whose details overflow page 1, '
        'with the overflow', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final crowded = await admin.applications.createApplication(
        content.copyWith(
          formFooter: () => footer,
          ageCategories: [
            for (var i = 0; i < 90; i++)
              ApplicationAgeCategory(label: {'en': 'Group $i', 'mr': 'गट $i'}),
          ],
        ),
      );
      await expectLater(
        admin.applications.saveApplication(crowded.id),
        throwsA(
          isA<ApplicationDoesNotFitException>().having(
            (e) => e.overflowPt,
            'overflowPt',
            greaterThan(0),
          ),
        ),
      );
      await admin.applications.deleteApplication(crowded.id);
    });

    test('Issue 66: an admin previews a template as a PDF', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      expect(await admin.applications.downloadPreview(appId), isPdf());
      await expectLater(
        member.applications.downloadPreview(appId),
        refused(403, SdkErrorCode.insufficientPermission),
      );
    });

    // ── Published: what members see ──────────────────────────────────────

    test('Issue 66: a published template is offered to a member with an '
        'identity document', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final published = await admin.applications.publishApplication(appId);
      expect(published.status, ApplicationStatus.published);
      final page = await member.applications.listApplications();
      expect(page.items.map((t) => t.id), contains(appId));
      expect(
        page.items.every((t) => t.status == ApplicationStatus.published),
        isTrue,
      );
      final read = await member.applications.getApplication(appId);
      expect(read.content, published.content);
    });

    test('Issue 66: a member downloads their own form as a PDF', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      expect(await member.applications.downloadOwnForm(appId), isPdf());
    });

    test(
      'Issue 66: a member no age category matches is not eligible',
      () async {
        if (skipUnless(enabled: on, module: 'applications')) return;
        await expectLater(
          older.applications.downloadOwnForm(appId),
          refused(422, SdkErrorCode.applicationNotEligible),
        );
      },
    );

    test('Issue 66: a member without an identity document is offered '
        'nothing until they upload one', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final me = await newcomer.auth.getCurrentUser();
      expect(me.status, UserStatus.registered);
      final none = await newcomer.applications.listApplications();
      expect(none.items, isEmpty);
      expect(none.total, 0);
      await expectLater(
        newcomer.applications.getApplication(appId),
        refused(422, SdkErrorCode.identityDocumentRequired),
      );
      await expectLater(
        newcomer.applications.downloadOwnForm(appId),
        refused(422, SdkErrorCode.identityDocumentRequired),
      );

      await attachIdentityDocument(newcomer, newcomerName);
      final offered = await newcomer.applications.listApplications();
      expect(offered.items.map((t) => t.id), contains(appId));
      // Born 2016, female: she fits both categories, so she names one
      // (club_server#108).
      expect(
        await newcomer.applications.downloadOwnForm(appId, category: 1),
        isPdf(),
      );
    });

    test("Issue 66: an admin downloads any member's form", () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      expect(
        await admin.applications.downloadMemberForm(appId, memberName),
        isPdf(),
      );
      await expectLater(
        admin.applications.downloadMemberForm(appId, 'test_i66a_nobody'),
        refused(404, SdkErrorCode.userNotFound),
      );
      await expectLater(
        member.applications.downloadMemberForm(appId, olderName),
        refused(403, SdkErrorCode.insufficientPermission),
      );
    });

    test('Issue 66: a published template is not deleted', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.deleteApplication(appId),
        refused(422, SdkErrorCode.invalidState),
      );
    });

    // ── Duplicate, unpublish, revert, delete ─────────────────────────────

    test('Issue 66: duplicate makes a new draft with the same content and '
        'no layout', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final source = await admin.applications.getApplication(appId);
      final copy = await admin.applications.duplicateApplication(appId);
      copyId = copy.id;
      expect(copy.id, isNot(appId));
      expect(copy.status, ApplicationStatus.draft);
      expect(copy.layout, isNull);
      expect(copy.content, source.content);
      expect(await admin.applications.getApplication(appId), source);
    });

    test("Issue 66: a draft's member form is not published", () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.downloadMemberForm(copyId, memberName),
        refused(422, SdkErrorCode.applicationNotPublished),
      );
      expect(await admin.applications.downloadPreview(copyId), isPdf());
    });

    test('Issue 66: an admin lists every state, narrowed by status', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final all = await admin.applications.listApplications(limit: 100);
      expect(all.items.map((t) => t.id), containsAll([appId, copyId]));
      final drafts = await admin.applications.listApplications(
        status: ApplicationStatus.draft,
        limit: 100,
      );
      expect(drafts.items.map((t) => t.id), contains(copyId));
      expect(drafts.items.map((t) => t.id), isNot(contains(appId)));
      expect(
        drafts.items.every((t) => t.status == ApplicationStatus.draft),
        isTrue,
      );
    });

    test('Issue 66: unpublish withdraws the template from members', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final saved = await admin.applications.unpublishApplication(appId);
      expect(saved.status, ApplicationStatus.saved);
      expect(saved.layout, isNotNull);
      await expectLater(
        member.applications.getApplication(appId),
        refused(404, SdkErrorCode.applicationNotFound),
      );
      final page = await member.applications.listApplications();
      expect(page.items.map((t) => t.id), isNot(contains(appId)));
    });

    test(
      'Issue 66: revert makes it a draft again and drops the layout',
      () async {
        if (skipUnless(enabled: on, module: 'applications')) return;
        final draft = await admin.applications.revertApplication(appId);
        expect(draft.status, ApplicationStatus.draft);
        expect(draft.layout, isNull);
        await expectLater(
          admin.applications.revertApplication(appId),
          refused(422, SdkErrorCode.invalidTransition),
        );
      },
    );

    test('Issue 66: a deleted template is no longer listed or read', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      for (final id in [appId, copyId]) {
        final deleted = await admin.applications.deleteApplication(id);
        expect(deleted.id, id);
        await expectLater(
          admin.applications.getApplication(id),
          refused(404, SdkErrorCode.applicationNotFound),
        );
      }
      final all = await admin.applications.listApplications(limit: 100);
      expect(all.items.map((t) => t.id), isNot(contains(appId)));
      expect(all.items.map((t) => t.id), isNot(contains(copyId)));
    });
  });
}
