import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// Issue 8: `media.upload` takes `ownerUsername` (club_server#18). An admin
/// uploads on behalf of a user, who is recorded as the uploader: `self`
/// access, the right to change or delete the file and their own file listing
/// are theirs. Anyone else naming another user is refused.
void main() {
  group('Issue 8: upload on behalf of a user', () {
    late SecureClient sudoClient;
    late SecureClient adminClient;
    late SecureClient memberClient;
    late SecureClient otherClient;

    const password = 'password123';
    const admin = 'test_i8_admin';
    const member = 'test_i8_member';
    const other = 'test_i8_other';

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
        phone: '0000000008',
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

    /// A photo the admin uploads for [member], private to them and staff.
    Future<Media> uploadForMember(String name) async {
      final media = await adminClient.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i8_$name.png',
        contentType: 'image/png',
        preserveOriginal: true,
        accessRoles: ['self', 'admin', 'coach'],
        ownerUsername: member,
      );
      uploaded.add(media.id);
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

    test('Issue 8: a file an admin uploads for a member is recorded as the '
        "member's", () async {
      final media = await uploadForMember('owner');
      expect(media.uploadedBy, member);
      expect(media.accessRoles, unorderedEquals(['self', 'admin', 'coach']));

      final read = await sudoClient.media.getById(media.id);
      expect(read.uploadedBy, member);
    });

    test('Issue 8: the member downloads the file and finds it among their '
        'own files', () async {
      final media = await uploadForMember('download');

      expect(await memberClient.media.download(media.uuid), testPngBytes);
      final mine = await memberClient.media.listMyFiles();
      expect(mine.items.map((m) => m.id), contains(media.id));
      final admins = await adminClient.media.listMyFiles();
      expect(admins.items.map((m) => m.id), isNot(contains(media.id)));
    });

    test('Issue 8: another member cannot read a file private to its '
        'owner and staff', () async {
      final media = await uploadForMember('private');

      await expectLater(
        otherClient.media.download(media.uuid),
        throwsA(isA<ServerException>()),
      );
    });

    test('Issue 8: the member changes the access roles of the file', () async {
      final media = await uploadForMember('patch');

      final patched = await memberClient.media.patch(
        media.id,
        accessRoles: ['public'],
      );
      expect(patched.accessRoles, ['public']);
      final read = await sudoClient.media.getById(media.id);
      expect(read.accessRoles, ['public']);
      expect(await otherClient.media.download(media.uuid), testPngBytes);
    });

    test('Issue 8: the member soft-deletes the file', () async {
      final media = await uploadForMember('delete');

      await memberClient.media.softDelete(media.id);
      final deleted = await sudoClient.media.list(includeDeleted: true);
      final row = deleted.items.singleWhere((m) => m.id == media.id);
      expect(row.deletedAtUtc, isNotNull);
      final active = await sudoClient.media.list();
      expect(active.items.map((m) => m.id), isNot(contains(media.id)));
    });

    test('Issue 8: a member uploading for someone else is refused '
        '(403)', () async {
      final before = await sudoClient.media.list(limit: 1);

      await expectLater(
        otherClient.media.upload(
          fileBytes: testPngBytes,
          filename: 'test_i8_refused.png',
          contentType: 'image/png',
          accessRoles: ['self', 'admin', 'coach'],
          ownerUsername: member,
        ),
        refusedWith(403),
      );
      final after = await sudoClient.media.list(limit: 1);
      expect(after.total, before.total);
    });

    test('Issue 8: a member naming themselves uploads as usual', () async {
      final media = await memberClient.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i8_self.png',
        contentType: 'image/png',
        accessRoles: ['self'],
        ownerUsername: member,
      );
      uploaded.add(media.id);
      expect(media.uploadedBy, member);
    });

    test('Issue 8: an admin naming an unknown user gets 404 '
        'USER_NOT_FOUND', () async {
      await expectLater(
        adminClient.media.upload(
          fileBytes: testPngBytes,
          filename: 'test_i8_unknown.png',
          contentType: 'image/png',
          ownerUsername: 'test_i8_nobody',
        ),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.code, 'code', SdkErrorCode.userNotFound),
        ),
      );
    });
  });
}
