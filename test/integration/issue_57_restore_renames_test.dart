import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/evaluation_fixtures.dart';
import '../utils/module_gate.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';

/// Issue 57: restoring an evaluation template whose name a live template
/// took meanwhile renames it (club_server#71, R49b).
///
/// The restore no longer answers 422 `TEMPLATE_NAME_TAKEN`: the template
/// comes back live under the first free `<name> -- Restored #N`, names
/// compared ignoring case and surrounding spaces. A free name is kept.
///
/// Runs against both stacks: `just test` (module off) asserts the 503,
/// `just test-server2 issue_57_restore_renames_test.dart` the behaviour.
void main() {
  group('Issue 57: restoring a template onto a taken name', () {
    late SecureClient sudo;
    late SecureClient admin;
    late SecureClient coach;
    late bool evaluationsOn;

    const coachName = 'test_i57_coach';
    const adminName = 'test_i57_admin';
    const password = 'password123';
    final suffix = DateTime.now().millisecondsSinceEpoch;

    Future<SecureClient> loginAs(String username) async {
      final client = await createRemoteSecureClient(baseUrl: baseUrl);
      await client.auth.login(username, password);
      expect((await client.auth.getCurrentUser()).username, username);
      return client;
    }

    /// A unique base name per case, so the cases never share a name.
    String nameFor(String tag) => 'test_i57_${tag}_$suffix';

    Future<EvaluationTemplate> create(String name) =>
        admin.evaluations.createTemplate(name: name, layout: standardLayout());

    /// A template named [name], soft-deleted and checked to be so.
    Future<EvaluationTemplate> deleted(String name) async {
      final t = await create(name);
      expect(t.name, name);
      final gone = await admin.evaluations.deleteTemplate(t.id);
      expect(gone.deletedAtUtc, isNotNull);
      return t;
    }

    Future<Iterable<int>> liveIds() async =>
        (await admin.evaluations.listTemplates(limit: 100)).items.map(
          (t) => t.id,
        );

    Future<Iterable<int>> deletedIds() async =>
        (await admin.evaluations.listDeletedTemplates(limit: 100)).items.map(
          (t) => t.id,
        );

    setUpAll(() async {
      sudo = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudo,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudo.auth.login(sudoUsername, sudoPassword);
      evaluationsOn = (await stackCapabilities(sudo)).evaluations;

      for (final name in [coachName, adminName]) {
        await registerAndApprove(
          client: sudo,
          adminUsername: sudoUsername,
          adminPassword: sudoPassword,
          username: name,
          email: '$name@example.com',
          password: password,
          phone: '+919000000057',
          dateOfBirthUtc: DateTime.utc(2000),
          gender: Gender.male,
          firstName: 'Test',
          lastName: name,
        );
      }
      await sudo.users.assignRole(coachName, 'coach');
      await sudo.users.assignRole(adminName, 'admin');

      admin = await loginAs(adminName);
      coach = await loginAs(coachName);
    });

    tearDownAll(() async {
      for (final c in [admin, coach, sudo]) {
        await c.auth.logout();
      }
    });

    test('57.00: restore answers 503 where the module is off', () async {
      if (skipIf(enabled: evaluationsOn, feature: 'evaluations')) return;

      await expectLater(
        admin.evaluations.restoreTemplate(1),
        throwsModuleDisabled(SdkErrorCode.evaluationsDisabled),
      );
    });

    test('57.01: a restore onto a taken name comes back live as '
        '"<name> -- Restored #1"', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final name = nameFor('taken');
      final old = await deleted(name);
      final newer = await create(name);
      expect(newer.name, name);

      final restored = await coach.evaluations.restoreTemplate(old.id);
      expect(restored.id, old.id);
      expect(restored.name, '$name -- Restored #1');
      expect(restored.deletedAtUtc, isNull);

      expect(
        (await admin.evaluations.getTemplate(old.id)).name,
        '$name -- Restored #1',
      );
      expect((await admin.evaluations.getTemplate(newer.id)).name, name);
      expect(await liveIds(), containsAll([old.id, newer.id]));
      expect(await deletedIds(), isNot(contains(old.id)));
    });

    test('57.02: with "#1" also taken the restore takes "#2"', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final name = nameFor('next');
      final old = await deleted(name);
      await create(name);
      final first = await create('$name -- Restored #1');
      expect(first.name, '$name -- Restored #1');

      final restored = await admin.evaluations.restoreTemplate(old.id);
      expect(restored.name, '$name -- Restored #2');
      expect(restored.deletedAtUtc, isNull);
      expect(
        (await admin.evaluations.getTemplate(old.id)).name,
        '$name -- Restored #2',
      );
      expect(await deletedIds(), isNot(contains(old.id)));
    });

    test('57.03: the name check ignores case and surrounding spaces', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final name = nameFor('case');
      final old = await deleted(name);
      await create('  ${name.toUpperCase()} ');
      await create(' ${name.toUpperCase()} -- restored #1  ');

      final restored = await admin.evaluations.restoreTemplate(old.id);
      expect(restored.name, '$name -- Restored #2');
      expect(restored.deletedAtUtc, isNull);
      expect(await liveIds(), contains(old.id));
      expect(await deletedIds(), isNot(contains(old.id)));
    });

    test('57.04: a restore whose name is free keeps it', () async {
      if (skipUnless(enabled: evaluationsOn, module: 'evaluations')) return;

      final name = nameFor('free');
      final old = await deleted(name);
      final other = await create(nameFor('other'));
      expect(other.name, isNot(name));

      final restored = await admin.evaluations.restoreTemplate(old.id);
      expect(restored.name, name);
      expect(restored.deletedAtUtc, isNull);
      expect((await admin.evaluations.getTemplate(old.id)).name, name);
      expect(await liveIds(), contains(old.id));
      expect(await deletedIds(), isNot(contains(old.id)));
    });
  });
}
