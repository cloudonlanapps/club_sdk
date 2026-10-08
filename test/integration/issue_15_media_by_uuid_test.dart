import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// Issue 15: `media.getByUuid` (club_server#27). A media link carries a
/// file's uuid; the calls that change the file take its id. Reading the
/// record by uuid gives the id, to the same callers as reading it by id.
void main() {
  group('Issue 15: read a media record by its uuid', () {
    late SecureClient sudoClient;
    late SecureClient adminClient;
    late SecureClient memberClient;
    late SecureClient otherClient;

    const password = 'password123';
    const admin = 'test_i15m_admin';
    const member = 'test_i15m_member';
    const other = 'test_i15m_other';
    const unknownUuid = '00000000-0000-4000-8000-000000000000';

    final uploaded = <int>[];

    Future<void> register(String username, {String? role}) async {
      await registerAndApprove(
        client: sudoClient,
        adminUsername: sudoUsername,
        adminPassword: sudoPassword,
        username: username,
        email: '$username@test.com',
        password: password,
        firstName: 'User $username',
        phone: '0000000015',
        dateOfBirthUtc: DateTime.utc(1995),
        gender: Gender.male,
      );
      if (role != null) await sudoClient.users.assignRole(username, role);
    }

    Future<SecureClient> loggedIn(String username) async {
      final c = await createRemoteSecureClient(baseUrl: baseUrl);
      await c.auth.login(username, password);
      expect((await c.auth.getCurrentUser()).username, username);
      return c;
    }

    /// A file of the member's that only the member may download.
    Future<Media> memberFile(String name) async {
      final media = await memberClient.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i15m_$name.png',
        contentType: 'image/png',
        preserveOriginal: true,
        accessRoles: ['self'],
      );
      uploaded.add(media.id);
      return media;
    }

    final notFound = throwsA(
      isA<ServerException>()
          .having((e) => e.statusCode, 'statusCode', 404)
          .having((e) => e.code, 'code', 'MEDIA_NOT_FOUND'),
    );

    setUpAll(() async {
      sudoClient = await createRemoteSecureClient(baseUrl: baseUrl);
      await clearTestArtifacts(
        client: sudoClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudoClient.auth.login(sudoUsername, sudoPassword);

      await register(admin, role: 'admin');
      await register(member);
      await register(other);

      adminClient = await loggedIn(admin);
      memberClient = await loggedIn(member);
      otherClient = await loggedIn(other);
    });

    tearDownAll(() async {
      for (final id in uploaded) {
        try {
          await sudoClient.media.softDelete(id);
        } on ServerException catch (_) {}
        try {
          await sudoClient.media.hardDelete(id);
        } on ServerException catch (_) {}
      }
      for (final c in [adminClient, memberClient, otherClient]) {
        await c.auth.logout();
      }
      await sudoClient.auth.logout();
    });

    test('Issue 15: the uploader reads the same record by uuid as by '
        'id', () async {
      final media = await memberFile('own');

      final byUuid = await memberClient.media.getByUuid(media.uuid);
      final byId = await memberClient.media.getById(media.id);

      expect(byUuid.id, media.id);
      expect(byUuid.toMap(), byId.toMap());
    });

    test('Issue 15: an admin reads a file private to its owner by '
        'uuid', () async {
      final media = await memberFile('admin');

      final read = await adminClient.media.getByUuid(media.uuid);

      expect(read.id, media.id);
      expect(read.uploadedBy, member);
      expect(read.accessRoles, ['self']);
    });

    test('Issue 15: the id read by uuid works with the calls that take '
        'an id', () async {
      final media = await memberFile('patch');

      final id = (await adminClient.media.getByUuid(media.uuid)).id;
      final patched = await adminClient.media.patch(
        id,
        accessRoles: ['self', 'admin', 'coach'],
      );

      expect(patched.uuid, media.uuid);
      final read = await memberClient.media.getByUuid(media.uuid);
      expect(read.accessRoles, unorderedEquals(['self', 'admin', 'coach']));
    });

    test('Issue 15: a soft-deleted file is read by uuid with its deleted '
        'time', () async {
      final media = await memberFile('deleted');
      await memberClient.media.softDelete(media.id);

      final read = await memberClient.media.getByUuid(media.uuid);

      expect(read.id, media.id);
      expect(read.deletedAtUtc, isNotNull);
    });

    test('Issue 15: another member is answered not found', () async {
      final media = await memberFile('other');

      await expectLater(otherClient.media.getByUuid(media.uuid), notFound);
    });

    test('Issue 15: a uuid no file has is answered not found', () async {
      await expectLater(adminClient.media.getByUuid(unknownUuid), notFound);
    });
  });
}
