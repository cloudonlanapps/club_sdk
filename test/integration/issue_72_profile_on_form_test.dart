import 'dart:convert';

import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 72: where the extended profile meets applications (club_server#92,
/// #93) — the club's profile options on a form, the guardian block and the
/// layout's `spreadWithGuardian`, and the member's `membershipDateUtc`.
///
/// Applications need identity verification; `sdk_test_server1.conf` turns both on
/// together with `extended_profile_enabled`, which writing the profile
/// options needs, and `sdk_test_server2.conf` turns all three off (#86). So
/// every case runs on `just test` and skips on `just test-server2`.
///
/// The forms embed their fonts and print glyph ids, so no text can be read
/// back from the bytes. A form is drawn deterministically, though: two
/// downloads of the same form differ only in `/CreationDate` and the
/// document `/ID` derived from it. The cases therefore assert that changing
/// a profile field changes the form and that restoring it restores the
/// form exactly.
void main() {
  group('Issue 72: the extended profile on an application form', () {
    const password = 'password123';
    const adminName = 'test_i72_admin';
    const memberName = 'test_i72_member';
    const guardian = Guardian(
      name: 'Ravi',
      relation: 'Father',
      phone: '+91 98000 00000',
    );
    const options = ProfileOptions(
      positions: [
        ProfilePosition(value: 'Forward', label: {'en': 'Forward'}),
        ProfilePosition(value: 'Goalie', label: {'en': 'Goalie'}),
      ],
      languages: ['English'],
    );
    // Plain custom texts in English only: the least a template needs to
    // save (a declaration and a footer line), so the form's page 1 is
    // mostly the member's details.
    const content = ApplicationContent(
      title: ApplicationText({'en': 'Issue 72 — Registration Form'}),
      declaration: ApplicationText({'en': 'I agree to the rules.'}),
      formFooter: ApplicationText({'en': 'Play fair.'}),
    );

    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient member;
    late Capabilities capabilities;
    late ProfileOptions originalOptions;

    // A published template saved while the club had no positions, and one
    // saved after the club's positions were written.
    late ApplicationTemplate published;
    ApplicationTemplate? withPositions;

    Future<void> register(String username, DateTime born) => registerAndApprove(
      client: sudo,
      adminUsername: sudoUsername,
      adminPassword: sudoPassword,
      username: username,
      email: '$username@test.com',
      password: password,
      firstName: username,
      phone: '0000000072',
      dateOfBirthUtc: born,
      gender: Gender.male,
    );

    Future<SecureClient> signIn(String username) async {
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(username, password);
      expect((await client.auth.getCurrentUser()).username, username);
      return client;
    }

    // Only the super admin writes the club's profile options.
    Future<void> writeOptions(ProfileOptions value) =>
        sudo.users.setProfileOptions(value);

    // The form without the two entries that record when it was drawn.
    final drawnAt = RegExp(r'/CreationDate \([^)]*\)|/ID \[[^\]]*\]');
    String drawing(List<int> pdf) => latin1.decode(pdf).replaceAll(drawnAt, '');

    void expectPdf(List<int> bytes) {
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }

    Future<List<int>> ownForm([ApplicationTemplate? of]) async {
      final pdf = await member.applications.downloadOwnForm(
        (of ?? published).id,
      );
      expectPdf(pdf);
      return pdf;
    }

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      capabilities = await stackCapabilities(sudo);
      originalOptions = await sudo.users.getProfileOptions();
      if (capabilities.extendedProfile) {
        await writeOptions(const ProfileOptions());
      }

      await register(adminName, DateTime.utc(1985, 2, 3));
      await sudo.users.assignRole(adminName, 'admin');
      // An adult, so the guardian block prints only once a guardian is set.
      await register(memberName, DateTime.utc(1990, 6, 7));

      admin = await signIn(adminName);
      member = await signIn(memberName);

      if (capabilities.applications) {
        final draft = await admin.applications.createApplication(content);
        await admin.applications.saveApplication(draft.id);
        published = await admin.applications.publishApplication(draft.id);
      }
    });

    tearDownAll(() async {
      if (capabilities.extendedProfile) await writeOptions(originalOptions);
      for (final client in [member, admin, sudo]) {
        await client.auth.logout();
      }
    });

    test('Issue 72: applications and the extended profile are on or off '
        'together on this stack', () async {
      // Each conf turns them on or off together (#86), so no stack runs
      // only half of the cases below.
      expect(capabilities.extendedProfile, capabilities.applications);
      if (capabilities.applications) {
        expect(capabilities.identityVerification, isTrue);
      }
    });

    test('Issue 72: the saved layout leaves less spread with the guardian '
        'block than without it', () async {
      if (skipUnless(
        enabled: capabilities.applications,
        module: 'applications',
      )) {
        return;
      }
      final layout = published.layout!;
      expect(layout.spreadWithGuardian, greaterThan(0));
      expect(
        layout.spreadWithGuardian,
        lessThan(layout.spreadWithoutGuardian),
      );
    });

    test("Issue 72: setting an adult's guardian prints the guardian block, "
        'and clearing it takes it off', () async {
      if (skipUnless(
        enabled: capabilities.applications,
        module: 'applications',
      )) {
        return;
      }
      final before = await ownForm();

      final updated = await member.users.updateUser(
        memberName,
        guardian: () => guardian,
      );
      expect(updated.guardian, guardian);
      final withGuardian = await ownForm();
      expect(drawing(withGuardian), isNot(drawing(before)));
      // An admin's download of the member's form is the same form.
      final adminCopy = await admin.applications.downloadMemberForm(
        published.id,
        memberName,
      );
      expectPdf(adminCopy);
      expect(drawing(adminCopy) == drawing(withGuardian), isTrue);

      await member.users.updateUser(memberName, guardian: () => null);
      expect(drawing(await ownForm()) == drawing(before), isTrue);
    });

    test(
      'Issue 72: the membership date an admin sets is on the form',
      () async {
        if (skipUnless(
          enabled: capabilities.applications,
          module: 'applications',
        )) {
          return;
        }
        final original = (await admin.users.getUserPrivate(
          memberName,
        )).membershipDateUtc;
        // Approval gave the member the day of approval.
        expect(original, isNotNull);
        final before = await ownForm();

        final set = await admin.users.updateUser(
          memberName,
          membershipDateUtc: () => DateTime.utc(2020),
        );
        expect(set.membershipDateUtc, DateTime.utc(2020));
        expect(drawing(await ownForm()), isNot(drawing(before)));

        await admin.users.updateUser(
          memberName,
          membershipDateUtc: () => original,
        );
        expect(drawing(await ownForm()) == drawing(before), isTrue);
      },
    );

    test("Issue 72: the club's positions are measured into a saved layout "
        'and frozen there', () async {
      if (skipUnless(
            enabled: capabilities.applications,
            module: 'applications',
          ) ||
          skipUnless(
            enabled: capabilities.extendedProfile,
            module: 'extended profile',
          )) {
        return;
      }
      final draft = await admin.applications.duplicateApplication(
        published.id,
      );
      final draftBefore = await admin.applications.downloadPreview(draft.id);
      final formBefore = await ownForm();

      await writeOptions(options);
      expect(await member.users.getProfileOptions(), options);

      // A draft's preview is drawn with the club's options as they are now.
      final draftAfter = await admin.applications.downloadPreview(draft.id);
      expectPdf(draftAfter);
      expect(drawing(draftAfter), isNot(drawing(draftBefore)));

      // Saved now, the positions row takes its share of page 1.
      final saved = await admin.applications.saveApplication(draft.id);
      final before = published.layout!;
      final after = saved.layout!;
      expect(after.name, before.name);
      expect(after.spreadWithGuardian, lessThan(before.spreadWithGuardian));
      expect(
        after.spreadWithoutGuardian,
        lessThan(before.spreadWithoutGuardian),
      );

      // The template published before the positions keeps its frozen copy.
      expect(drawing(await ownForm()) == drawing(formBefore), isTrue);
      withPositions = await admin.applications.publishApplication(draft.id);
    });

    test(
      "Issue 72: a member's preferred position is ticked on their form",
      () async {
        if (skipUnless(
              enabled: capabilities.applications,
              module: 'applications',
            ) ||
            skipUnless(
              enabled: capabilities.extendedProfile,
              module: 'extended profile',
            )) {
          return;
        }
        final template = withPositions;
        expect(template, isNotNull, reason: 'published by the case above');
        final before = await ownForm(template);

        final picked = await member.users.updateUser(
          memberName,
          preferredPositions: const ['Forward'],
        );
        expect(picked.preferredPositions, ['Forward']);
        final ticked = await ownForm(template);
        expect(drawing(ticked), isNot(drawing(before)));
        // The template without positions has no row to tick.
        final plain = await ownForm();
        await member.users.updateUser(memberName, preferredPositions: const []);
        expect(drawing(await ownForm()) == drawing(plain), isTrue);
        expect(drawing(await ownForm(template)) == drawing(before), isTrue);
      },
    );
  });
}
