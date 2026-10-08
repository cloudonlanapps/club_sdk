import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/register_and_approve.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// Issue 16: a user has one avatar (club_server#28). Attaching a link under
/// `user_avatar` removes the user's other links under that tag, whether or
/// not the caller may view their files, and soft-deletes the files nothing
/// else uses. No SDK call changed; these tests guard the rule.
void main() {
  group('Issue 16: a new avatar replaces the old one', () {
    late SecureClient sudoClient;
    late SecureClient adminClient;
    late SecureClient memberClient;

    const password = 'password123';
    const admin = 'test_i16a_admin';
    const member = 'test_i16a_member';
    const avatarTag = 'user_avatar';
    const otherTag = 'test_i16a_gallery';

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
        phone: '0000000016',
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

    /// A photo [by] uploads for the member, with [accessRoles].
    Future<Media> photo(
      SecureClient by,
      String name, {
      List<String> accessRoles = const ['self', 'admin', 'coach'],
    }) async {
      final media = await by.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i16a_$name.png',
        contentType: 'image/png',
        preserveOriginal: true,
        accessRoles: accessRoles,
        ownerUsername: member,
      );
      uploaded.add(media.id);
      return media;
    }

    Future<List<String>> linked(SecureClient as, String tag) async =>
        (await as.userMedia.listByTag(
          member,
          tag,
        )).map((l) => l.mediaUuid).toList();

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

      adminClient = await loggedIn(admin);
      memberClient = await loggedIn(member);
    });

    tearDown(() async {
      for (final tag in [avatarTag, otherTag]) {
        try {
          await sudoClient.userMedia.detachTag(member, tag);
        } on ServerException catch (_) {}
      }
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
      for (final c in [adminClient, memberClient]) {
        await c.auth.logout();
      }
      await sudoClient.auth.logout();
    });

    test('Issue 16: a second attach under user_avatar leaves one link, the '
        'new one, and soft-deletes the first file', () async {
      final first = await photo(memberClient, 'first');
      await memberClient.userMedia.attach(
        member,
        tag: avatarTag,
        mediaUuid: first.uuid,
      );
      expect(await linked(memberClient, avatarTag), [first.uuid]);

      final second = await photo(memberClient, 'second');
      await memberClient.userMedia.attach(
        member,
        tag: avatarTag,
        mediaUuid: second.uuid,
      );

      expect(await linked(memberClient, avatarTag), [second.uuid]);
      expect(await linked(sudoClient, avatarTag), [second.uuid]);
      final old = await sudoClient.media.getById(first.id);
      expect(old.deletedAtUtc, isNotNull);
      final current = await sudoClient.media.getById(second.id);
      expect(current.deletedAtUtc, isNull);
    });

    test('Issue 16: an admin who is not a super admin replaces an avatar '
        'private to the member', () async {
      final first = await photo(memberClient, 'private', accessRoles: ['self']);
      await memberClient.userMedia.attach(
        member,
        tag: avatarTag,
        mediaUuid: first.uuid,
      );
      // The admin may not view the file, so its link is left out of what
      // the admin lists: there is nothing for a client to detach.
      expect(await linked(adminClient, avatarTag), isEmpty);

      final second = await photo(adminClient, 'by_admin');
      await adminClient.userMedia.attach(
        member,
        tag: avatarTag,
        mediaUuid: second.uuid,
      );

      expect(await linked(memberClient, avatarTag), [second.uuid]);
      expect(await linked(sudoClient, avatarTag), [second.uuid]);
      final old = await sudoClient.media.getById(first.id);
      expect(old.deletedAtUtc, isNotNull);
    });

    test('Issue 16: a replaced file another link still uses is kept', () async {
      final first = await photo(memberClient, 'shared');
      await memberClient.userMedia.attach(
        member,
        tag: avatarTag,
        mediaUuid: first.uuid,
      );
      await memberClient.userMedia.attach(
        member,
        tag: otherTag,
        mediaUuid: first.uuid,
      );

      final second = await photo(memberClient, 'after_shared');
      await memberClient.userMedia.attach(
        member,
        tag: avatarTag,
        mediaUuid: second.uuid,
      );

      expect(await linked(memberClient, avatarTag), [second.uuid]);
      expect(await linked(memberClient, otherTag), [first.uuid]);
      final old = await sudoClient.media.getById(first.id);
      expect(old.deletedAtUtc, isNull);
    });

    test('Issue 16: a second attach under another tag keeps both '
        'links', () async {
      final first = await photo(memberClient, 'gallery_one');
      final second = await photo(memberClient, 'gallery_two');

      await memberClient.userMedia.attach(
        member,
        tag: otherTag,
        mediaUuid: first.uuid,
      );
      await memberClient.userMedia.attach(
        member,
        tag: otherTag,
        mediaUuid: second.uuid,
      );

      expect(
        await linked(memberClient, otherTag),
        unorderedEquals([first.uuid, second.uuid]),
      );
      final kept = await sudoClient.media.getById(first.id);
      expect(kept.deletedAtUtc, isNull);
    });
  });
}
