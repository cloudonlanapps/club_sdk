import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/pdf_text.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 94: an admin's blank form of a template (club_server#129), and
/// the guardian block printed on every form (club_server#128).
///
/// A saved or published template's blank form is every label and box
/// with no member in it and no watermark. A published one's is the
/// drawing stored when it was published, carrying the side mark
/// `Form <publishId>`; a saved one's is drawn on request, with no mark.
///
/// Applications need identity verification: `sdk_test_server1.conf` turns
/// both on, so the cases run on `just test-one`; `sdk_test_server2.conf`
/// turns both off, so the 503 case runs on `just test-server2` (#86).
///
/// The forms' text is read with `pdfShows` (`test/utils/pdf_text.dart`).
/// Every check that a text is absent from a form is paired with a check
/// that a text is present in the same form, so a form the helper cannot
/// read fails the case instead of passing it.
void main() {
  group('Issue 94: blank forms', () {
    const password = 'password123';
    const adminName = 'test_i94_admin';
    const coachName = 'test_i94_coach';
    const memberName = 'test_i94_member';
    // The member's first name, printed on their own form only.
    const memberFirstName = 'Zorawar';
    const title = 'Issue 94 Trial Entry Sheet';
    // Plain English texts, none with the word of the publish mark, so the
    // mark is the only "Form " a form can show.
    const content = ApplicationContent(
      title: ApplicationText({'en': title}),
      declaration: ApplicationText({'en': 'I agree to the rules.'}),
      formFooter: ApplicationText({'en': 'Play fair.'}),
    );

    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient coach;
    late SecureClient member;
    late bool on;

    late ApplicationTemplate draft;
    late ApplicationTemplate saved;
    late ApplicationTemplate published;

    Future<void> register(String username, String firstName) =>
        registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: username,
          email: '$username@test.com',
          password: password,
          firstName: firstName,
          phone: '0000000094',
          dateOfBirthUtc: DateTime.utc(1990, 6, 7),
          gender: Gender.male,
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

    void expectPdf(List<int> bytes) {
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      on = (await stackCapabilities(sudo)).applications;

      await register(adminName, adminName);
      await sudo.users.assignRole(adminName, 'admin');
      await register(coachName, coachName);
      await sudo.users.assignRole(coachName, 'coach');
      // An adult with no guardian (club_server#128).
      await register(memberName, memberFirstName);

      admin = await signIn(adminName);
      coach = await signIn(coachName);
      member = await signIn(memberName);

      if (on) {
        draft = await admin.applications.createApplication(content);
        final toSave = await admin.applications.createApplication(content);
        saved = await admin.applications.saveApplication(toSave.id);
        final toPublish = await admin.applications.createApplication(content);
        await admin.applications.saveApplication(toPublish.id);
        published = await admin.applications.publishApplication(toPublish.id);
        expect(published.status, ApplicationStatus.published);
        expect(published.publishId, isNotNull);
      }
    });

    tearDownAll(() async {
      if (on) {
        await admin.applications.unpublishApplication(published.id);
        for (final id in [published.id, saved.id]) {
          await admin.applications.revertApplication(id);
        }
        for (final id in [published.id, saved.id, draft.id]) {
          await admin.applications.deleteApplication(id);
        }
      }
      for (final client in [member, coach, admin, sudo]) {
        await client.auth.logout();
      }
    });

    test('Issue 94: the blank form answers 503 APPLICATIONS_DISABLED while '
        'the module is off', () async {
      if (skipIf(enabled: on, feature: 'applications')) return;
      await expectLater(
        admin.applications.downloadBlankForm(1),
        throwsModuleDisabled(SdkErrorCode.applicationsDisabled),
      );
    });

    test("Issue 94: a published template's blank form is its stored "
        'drawing, with the "Form <publishId>" mark and no member', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final blank = await admin.applications.downloadBlankForm(published.id);
      expectPdf(blank);
      expect(pdfShows(blank, title), isTrue);
      expect(pdfShows(blank, 'Form ${published.publishId}'), isTrue);
      // The stored drawing: the same bytes on every download.
      expect(
        await admin.applications.downloadBlankForm(published.id),
        orderedEquals(blank),
      );

      // The member's own form carries their name; the blank form does not.
      final own = await member.applications.downloadOwnForm(published.id);
      expect(pdfShows(own, memberFirstName), isTrue);
      expect(pdfShows(blank, memberFirstName), isFalse);
      // The preview carries the watermark; the blank form does not.
      final preview = await admin.applications.downloadPreview(published.id);
      expect(pdfShows(preview, 'PREVIEW'), isTrue);
      expect(pdfShows(blank, 'PREVIEW'), isFalse);
    });

    test("Issue 94: a saved template's blank form is drawn with no publish "
        'mark and no watermark', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final blank = await admin.applications.downloadBlankForm(saved.id);
      expectPdf(blank);
      expect(pdfShows(blank, title), isTrue);
      expect(pdfShows(blank, 'Form '), isFalse);
      expect(pdfShows(blank, 'PREVIEW'), isFalse);
      expect(pdfShows(blank, memberFirstName), isFalse);
    });

    test("Issue 94: a draft's blank form is refused with "
        'APPLICATION_NOT_SAVED', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.downloadBlankForm(draft.id),
        refused(422, SdkErrorCode.applicationNotSaved),
      );
    });

    test("Issue 94: an unknown template's blank form is "
        'APPLICATION_NOT_FOUND', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.downloadBlankForm(999999),
        refused(404, SdkErrorCode.applicationNotFound),
      );
    });

    test('Issue 94: a coach or a member may not download a blank '
        'form', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      for (final caller in [coach, member]) {
        await expectLater(
          caller.applications.downloadBlankForm(published.id),
          refused(403, SdkErrorCode.insufficientPermission),
        );
      }
    });

    test("Issue 94: an adult's form with no guardian prints the guardian "
        'block (club_server#128)', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final labels = await admin.applications.getLabels();
      final heading = labels.label('section.guardian', 'en');
      final note = labels.label('note.guardian', 'en');
      expect(heading, isNotNull);
      expect(note, isNotNull);
      expect(
        (await member.auth.getCurrentUser()).guardian,
        isNull,
        reason: 'the member has no guardian',
      );

      final own = await member.applications.downloadOwnForm(published.id);
      expect(pdfShows(own, memberFirstName), isTrue);
      expect(pdfShows(own, heading!), isTrue);
      expect(pdfShows(own, note!), isTrue);
      final blank = await admin.applications.downloadBlankForm(published.id);
      expect(pdfShows(blank, heading), isTrue);
    });

    test('Issue 94: a saved layout still parses, its two spreads equal now '
        'the guardian block always prints (club_server#128)', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      for (final template in [
        saved,
        await admin.applications.getApplication(published.id),
      ]) {
        final layout = template.layout;
        expect(layout, isNotNull);
        expect(layout!.name, isNotEmpty);
        expect(layout.spreadWithGuardian, greaterThanOrEqualTo(0));
        expect(layout.spreadWithoutGuardian, layout.spreadWithGuardian);
      }
    });
  });
}
