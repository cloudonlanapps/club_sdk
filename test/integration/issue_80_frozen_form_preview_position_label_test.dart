import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 80: three server fixes seen through the SDK.
///
/// - club_server#97: a published template is frozen with the profile
///   options it was saved with, so its forms still download, under the
///   same `publishId`, after the club's positions change.
/// - club_server#100: the admin preview's demo member fits a first age
///   category bounded only by `bornOnOrAfterUtc`.
/// - club_server#103: every profile position needs an English label.
///
/// They need applications and the extended profile, both on in
/// `sdk_test_server1.conf` (`just test-one`) and off in
/// `sdk_test_server2.conf`, where every case skips.
void main() {
  group('Issue 80: frozen form, preview demo member, English position '
      'label', () {
    const password = 'password123';
    const memberName = 'test_i80_member';
    const positionCount = 40;

    late SecureClient sudo;
    late SecureClient member;
    late Capabilities capabilities;
    late ProfileOptions originalOptions;
    final created = <int>[];

    const content = ApplicationContent(
      title: ApplicationText({'en': 'Issue 80 — Registration Form'}),
      declaration: ApplicationText({'en': 'I agree to the rules.'}),
      formFooter: ApplicationText({'en': 'Play fair.'}),
    );

    Matcher refused(int status, String code) => throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', status)
          .having((e) => e.code, 'code', code),
    );

    void expectPdf(List<int> bytes) {
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }

    bool skipUnlessBoth() =>
        skipUnless(
          enabled: capabilities.applications,
          module: 'applications',
        ) ||
        skipUnless(
          enabled: capabilities.extendedProfile,
          module: 'extended profile',
        );

    Future<ApplicationTemplate> create(ApplicationContent c) async {
      final draft = await sudo.applications.createApplication(c);
      created.add(draft.id);
      return draft;
    }

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      expect((await sudo.auth.getCurrentUser()).username, sudoUsername);
      capabilities = await stackCapabilities(sudo);
      originalOptions = await sudo.users.getProfileOptions();
      if (capabilities.extendedProfile) {
        await sudo.users.setProfileOptions(const ProfileOptions());
      }

      await registerAndApprove(
        client: sudo,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: memberName,
        email: '$memberName@test.com',
        password: password,
        firstName: memberName,
        phone: '0000000080',
        dateOfBirthUtc: DateTime.utc(1990, 6, 7),
        gender: Gender.male,
      );
      member = await createRemoteSecureClient(baseUrl: baseUrl);
      await member.auth.login(memberName, password);
      expect((await member.auth.getCurrentUser()).username, memberName);
    });

    tearDownAll(() async {
      if (capabilities.extendedProfile) {
        await sudo.users.setProfileOptions(originalOptions);
      }
      for (final id in created) {
        var t = await sudo.applications.getApplication(id);
        if (t.status == ApplicationStatus.published) {
          t = await sudo.applications.unpublishApplication(id);
        }
        if (t.status == ApplicationStatus.saved) {
          await sudo.applications.revertApplication(id);
        }
        await sudo.applications.deleteApplication(id);
      }
      await member.auth.logout();
      await sudo.auth.logout();
    });

    test('club_server#97: a published form still downloads, under the same '
        'publishId, after the club writes $positionCount positions', () async {
      if (skipUnlessBoth()) return;
      final draft = await create(content);
      await sudo.applications.saveApplication(draft.id);
      final published = await sudo.applications.publishApplication(draft.id);
      final publishId = published.publishId;
      expect(publishId, isNotNull);

      final positions = [
        for (var i = 1; i <= positionCount; i++)
          ProfilePosition(
            value: 'Position $i',
            label: {'en': 'Position number $i'},
          ),
      ];
      final written = await sudo.users.setProfileOptions(
        ProfileOptions(positions: positions),
      );
      expect(written.positions, hasLength(positionCount));

      expectPdf(await member.applications.downloadOwnForm(draft.id));
      expectPdf(
        await sudo.applications.downloadMemberForm(draft.id, memberName),
      );
      final read = await sudo.applications.getApplication(draft.id);
      expect(read.status, ApplicationStatus.published);
      expect(read.publishId, publishId);
    });

    for (final (name, before) in [
      ('only bornOnOrAfterUtc 2010-09-01', null),
      ('2010-09-01 to 2011-12-31', DateTime.utc(2011, 12, 31)),
    ]) {
      test('club_server#100: the preview draws a first age category with '
          '$name', () async {
        if (skipUnlessBoth()) return;
        final draft = await create(
          content.copyWith(
            ageCategories: [
              ApplicationAgeCategory(
                label: const {'en': 'Under-16'},
                bornOnOrAfterUtc: DateTime.utc(2010, 9),
                bornOnOrBeforeUtc: before,
              ),
            ],
          ),
        );
        expectPdf(await sudo.applications.downloadPreview(draft.id));
      });
    }

    test('club_server#103: a position labelled without English is refused '
        'and nothing is stored', () async {
      if (skipUnlessBoth()) return;
      final before = await sudo.users.getProfileOptions();
      await expectLater(
        sudo.users.setProfileOptions(
          const ProfileOptions(
            positions: [
              ProfilePosition(value: 'Forward', label: {'hi': 'फॉरवर्ड'}),
            ],
          ),
        ),
        refused(422, SdkErrorCode.invalidPreferenceValue),
      );
      expect(await sudo.users.getProfileOptions(), before);
    });

    test('club_server#103: the same position with an English label is '
        'stored', () async {
      if (skipUnlessBoth()) return;
      const options = ProfileOptions(
        positions: [
          ProfilePosition(
            value: 'Forward',
            label: {'en': 'Forward', 'hi': 'फॉरवर्ड'},
          ),
        ],
      );
      expect(await sudo.users.setProfileOptions(options), options);
      expect(await member.users.getProfileOptions(), options);
    });
  });
}
