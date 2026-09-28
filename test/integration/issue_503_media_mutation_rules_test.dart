import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// club_server#503: only the uploader, an admin or the super admin may change
/// a media item's access roles, soft-delete it or restore it, whatever its
/// access roles. Being able to view an item is not enough: a refused caller
/// who can view it gets 403, one who cannot gets 404.
void main() {
  group('club_server#503: who may change or delete media', () {
    late SecureClient sudoClient;
    late SecureClient adminClient;
    late SecureClient coachClient;
    late SecureClient uploaderClient;
    late SecureClient otherClient;

    const password = 'password123';
    const admin = 'test_i503_admin';
    const coach = 'test_i503_coach';
    const uploader = 'test_i503_uploader';
    const other = 'test_i503_other';

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
        phone: '0000000503',
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

    /// An item the uploader owns, with [accessRoles].
    Future<Media> uploadAsUploader(
      String name,
      List<String> accessRoles,
    ) async {
      final media = await uploaderClient.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i503_$name.png',
        contentType: 'image/png',
        preserveOriginal: true,
        accessRoles: accessRoles,
      );
      uploaded.add(media.id);
      expect(media.uploadedBy, uploader);
      return media;
    }

    Matcher refusedWith(int status) => throwsA(
      isA<ServerException>().having((e) => e.statusCode, 'statusCode', status),
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
      await register(coach, role: 'coach');
      await register(uploader);
      await register(other);

      adminClient = await loggedIn(admin);
      coachClient = await loggedIn(coach);
      uploaderClient = await loggedIn(uploader);
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
      for (final c in [adminClient, coachClient, uploaderClient, otherClient]) {
        await c.auth.logout();
      }
      await sudoClient.auth.logout();
    });

    test('another member cannot change the access roles of a public '
        'item (403)', () async {
      final media = await uploadAsUploader('member_patch', ['public']);
      expect(
        await otherClient.media.download(media.uuid),
        testPngBytes,
        reason: 'the member can view the public item',
      );

      await expectLater(
        otherClient.media.patch(media.id, accessRoles: ['self']),
        refusedWith(403),
      );
      final after = await sudoClient.media.getById(media.id);
      expect(after.accessRoles, ['public']);
    });

    test('another member cannot soft-delete a public item (403)', () async {
      final media = await uploadAsUploader('member_delete', ['public']);

      await expectLater(
        otherClient.media.softDelete(media.id),
        refusedWith(403),
      );
      final after = await sudoClient.media.getById(media.id);
      expect(after.isDeleted, isFalse);
    });

    test('a coach cannot change the access roles of a public item '
        '(403)', () async {
      final media = await uploadAsUploader('coach_patch', ['public']);

      await expectLater(
        coachClient.media.patch(media.id, accessRoles: ['self']),
        refusedWith(403),
      );
      final after = await sudoClient.media.getById(media.id);
      expect(after.accessRoles, ['public']);
    });

    test('a coach cannot soft-delete a public item (403)', () async {
      final media = await uploadAsUploader('coach_delete', ['public']);

      await expectLater(
        coachClient.media.softDelete(media.id),
        refusedWith(403),
      );
      final after = await sudoClient.media.getById(media.id);
      expect(after.isDeleted, isFalse);
    });

    test('another member who cannot view an item gets 404, not '
        '403', () async {
      final media = await uploadAsUploader('member_hidden', ['self']);

      await expectLater(
        otherClient.media.patch(media.id, accessRoles: ['public']),
        refusedWith(404),
      );
      await expectLater(
        otherClient.media.softDelete(media.id),
        refusedWith(404),
      );
      final after = await sudoClient.media.getById(media.id);
      expect(after.accessRoles, ['self']);
      expect(after.isDeleted, isFalse);
    });

    test('an admin can change the access roles of a member item only its '
        'uploader can see', () async {
      final media = await uploadAsUploader('admin_patch', ['self']);

      final updated = await adminClient.media.patch(
        media.id,
        accessRoles: ['admin'],
      );
      expect(updated.accessRoles, ['admin']);
      final after = await sudoClient.media.getById(media.id);
      expect(after.accessRoles, ['admin']);
    });

    test('an admin can soft-delete and restore a member item only its '
        'uploader can see', () async {
      final media = await uploadAsUploader('admin_delete', ['self']);

      await adminClient.media.softDelete(media.id);
      expect((await sudoClient.media.getById(media.id)).isDeleted, isTrue);

      final restored = await adminClient.media.restore(media.id);
      expect(restored.isDeleted, isFalse);
      expect((await sudoClient.media.getById(media.id)).isDeleted, isFalse);
    });

    test('the uploader can change the access roles of their own '
        'item', () async {
      final media = await uploadAsUploader('own_patch', ['public']);

      final updated = await uploaderClient.media.patch(
        media.id,
        accessRoles: ['self'],
      );
      expect(updated.accessRoles, ['self']);
      final after = await sudoClient.media.getById(media.id);
      expect(after.accessRoles, ['self']);
    });

    test('the uploader can soft-delete and restore their own item', () async {
      final media = await uploadAsUploader('own_delete', ['public']);

      await uploaderClient.media.softDelete(media.id);
      expect((await sudoClient.media.getById(media.id)).isDeleted, isTrue);

      final restored = await uploaderClient.media.restore(media.id);
      expect(restored.isDeleted, isFalse);
      expect((await sudoClient.media.getById(media.id)).isDeleted, isFalse);
    });
  });
}
