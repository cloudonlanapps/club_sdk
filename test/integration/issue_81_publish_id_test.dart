import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/module_gate.dart';
import '../utils/test_client.dart';

/// Issue 81: every application response carries `publishId`, a UUID new
/// on each publish and null unless the template is published
/// (club_server#97, #119).
void main() {
  group('Issue 81: publishId', () {
    late SecureClient admin;
    late bool on;
    late int appId;
    late String firstPublishId;

    final uuid = matches(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
    );

    const content = ApplicationContent(
      title: ApplicationText({'en': 'Issue 81 — Registration Form'}),
      declaration: ApplicationText({'en': 'I agree to the rules.'}),
      formFooter: ApplicationText({'en': 'Play fair.'}),
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
        var t = await admin.applications.getApplication(appId);
        if (t.status == ApplicationStatus.published) {
          t = await admin.applications.unpublishApplication(appId);
        }
        if (t.status == ApplicationStatus.saved) {
          await admin.applications.revertApplication(appId);
        }
        await admin.applications.deleteApplication(appId);
      }
      await admin.auth.logout();
    });

    test('Issue 81: a draft and a saved template have none', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      expect(
        (await admin.applications.getApplication(appId)).publishId,
        isNull,
      );
      final saved = await admin.applications.saveApplication(appId);
      expect(saved.publishId, isNull);
    });

    test('Issue 81: publish sets a UUID, read back the same', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final published = await admin.applications.publishApplication(appId);
      expect(published.publishId, uuid);
      firstPublishId = published.publishId!;
      expect(
        (await admin.applications.getApplication(appId)).publishId,
        firstPublishId,
      );
      final listed = await admin.applications.listApplications(
        status: ApplicationStatus.published,
        limit: 100,
      );
      expect(
        listed.items.singleWhere((t) => t.id == appId).publishId,
        firstPublishId,
      );
    });

    test('Issue 81: unpublish clears it', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final saved = await admin.applications.unpublishApplication(appId);
      expect(saved.publishId, isNull);
      expect(
        (await admin.applications.getApplication(appId)).publishId,
        isNull,
      );
    });

    test('Issue 81: publishing again gives a different one', () async {
      if (skipUnless(enabled: on, module: 'applications')) return;
      final again = await admin.applications.publishApplication(appId);
      expect(again.publishId, uuid);
      expect(again.publishId, isNot(firstPublishId));
    });
  });
}
