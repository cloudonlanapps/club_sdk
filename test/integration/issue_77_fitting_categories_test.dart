import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 77: a member's read of a published template lists the age
/// categories they fit, and a form download names the one to tick when
/// they fit several (club_server#108).
void main() {
  group('Issue 77: fitting age categories and the category choice', () {
    const password = 'password123';
    const girlName = 'test_i77_girl';
    const boyName = 'test_i77_boy';
    const adultName = 'test_i77_adult';

    late SecureClient admin;
    late SecureClient girl;
    late SecureClient boy;
    late SecureClient adult;
    late bool on;
    late int appId;

    // Under-12 and Under-15 Girls overlap: a girl born in 2015 fits both.
    final content = ApplicationContent(
      title: const ApplicationText({'en': 'Issue 77 — Trial'}),
      ageCategories: [
        ApplicationAgeCategory(
          label: const {'en': 'Under-12'},
          bornOnOrAfterUtc: DateTime.utc(2014),
        ),
        ApplicationAgeCategory(
          label: const {'en': 'Under-15 Girls'},
          bornOnOrAfterUtc: DateTime.utc(2011),
          genders: const [Gender.female],
        ),
        ApplicationAgeCategory(
          label: const {'en': 'Veterans'},
          bornOnOrBeforeUtc: DateTime.utc(1980),
        ),
      ],
      declaration: const ApplicationText({'en': 'I agree to the rules.'}),
      formFooter: const ApplicationText({'en': 'Play fair.'}),
    );

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

    Future<SecureClient> member(
      String username,
      DateTime born,
      Gender gender,
    ) async {
      await registerAndApprove(
        client: admin,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: username,
        phone: '0000000077',
        dateOfBirthUtc: born,
        gender: gender,
      );
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(username, password);
      expect((await client.auth.getCurrentUser()).username, username);
      return client;
    }

    setUpAll(() async {
      admin = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: admin,
        username: sudoUsername,
        password: sudoPassword,
      );
      girl = await member(girlName, DateTime.utc(2015, 5, 6), Gender.female);
      boy = await member(boyName, DateTime.utc(2015, 7, 8), Gender.male);
      adult = await member(adultName, DateTime.utc(1995, 1, 2), Gender.male);
      await admin.auth.login(sudoUsername, sudoPassword);
      expect((await admin.auth.getCurrentUser()).username, sudoUsername);
      on = (await stackCapabilities(admin)).applications;
      if (!on) return;
      appId = (await admin.applications.createApplication(content)).id;
      await admin.applications.saveApplication(appId);
      await admin.applications.publishApplication(appId);
    });

    tearDownAll(() async {
      if (on) {
        await admin.applications.unpublishApplication(appId);
        await admin.applications.revertApplication(appId);
        await admin.applications.deleteApplication(appId);
      }
      for (final client in [adult, boy, girl, admin]) {
        await client.auth.logout();
      }
    });

    test("Issue 77: a member's read lists the categories they fit", () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      expect(
        (await girl.applications.getApplication(appId)).fittingCategories,
        [0, 1],
      );
      expect(
        (await boy.applications.getApplication(appId)).fittingCategories,
        [0],
      );
      expect(
        (await adult.applications.getApplication(appId)).fittingCategories,
        isEmpty,
      );
      final listed = await girl.applications.listApplications(limit: 100);
      expect(listed.items.map((t) => t.id), contains(appId));
    });

    test("Issue 77: an admin's read carries no fitting categories", () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final read = await admin.applications.getApplication(appId);
      expect(read.fittingCategories, isNull);
    });

    test('Issue 77: a member fitting several categories must choose one, '
        'told which', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        girl.applications.downloadOwnForm(appId),
        throwsA(
          isA<ApplicationCategoryRequiredException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.categories, 'categories', [0, 1]),
        ),
      );
    });

    test('Issue 77: with a category she fits, her form is a PDF', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      expect(
        await girl.applications.downloadOwnForm(appId, category: 1),
        isPdf(),
      );
      expect(
        await girl.applications.downloadOwnForm(appId, category: 0),
        isPdf(),
      );
    });

    test('Issue 77: a category she does not fit is refused, naming those '
        'she fits', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        girl.applications.downloadOwnForm(appId, category: 2),
        throwsA(
          isA<ApplicationCategoryNotFittingException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.categories, 'categories', [0, 1]),
        ),
      );
    });

    test('Issue 77: a member fitting one category needs no choice', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      expect(await boy.applications.downloadOwnForm(appId), isPdf());
      await expectLater(
        boy.applications.downloadOwnForm(appId, category: 1),
        throwsA(
          isA<ApplicationCategoryNotFittingException>().having(
            (e) => e.categories,
            'categories',
            [0],
          ),
        ),
      );
    });

    test('Issue 77: fitting none is still APPLICATION_NOT_ELIGIBLE', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        adult.applications.downloadOwnForm(appId),
        refused(422, SdkErrorCode.applicationNotEligible),
      );
      await expectLater(
        adult.applications.downloadOwnForm(appId, category: 2),
        refused(422, SdkErrorCode.applicationNotEligible),
      );
    });

    test("Issue 77: an admin's download of a member's form takes the "
        'choice too', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      await expectLater(
        admin.applications.downloadMemberForm(appId, girlName),
        throwsA(
          isA<ApplicationCategoryRequiredException>().having(
            (e) => e.categories,
            'categories',
            [0, 1],
          ),
        ),
      );
      expect(
        await admin.applications.downloadMemberForm(
          appId,
          girlName,
          category: 1,
        ),
        isPdf(),
      );
      await expectLater(
        admin.applications.downloadMemberForm(appId, girlName, category: 2),
        throwsA(isA<ApplicationCategoryNotFittingException>()),
      );
    });
  });
}
