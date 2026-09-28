import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

import '../utils/clear_test_artifacts.dart';
import '../utils/test_client.dart';
import '../utils/test_png.dart';

/// club_server#504: only media viewable anonymously is marked publicly
/// cacheable. An item restricted by access roles is `private` or `no-store`,
/// so shared caches and proxies do not keep it.
///
/// Read through [RemoteStore.head] on the download route, as
/// `MediaSource.probeVariant` does, since the SDK surfaces no headers.
void main() {
  group('club_server#504: download Cache-Control', () {
    late RemoteStore store;
    late SecureClient sudoClient;
    final uploaded = <int>[];

    Future<Media> upload(String name, List<String> accessRoles) async {
      final media = await sudoClient.media.upload(
        fileBytes: testPngBytes,
        filename: 'test_i504_$name.png',
        contentType: 'image/png',
        preserveOriginal: true,
        accessRoles: accessRoles,
      );
      uploaded.add(media.id);
      expect(media.accessRoles, accessRoles);
      return media;
    }

    Future<String> cacheControl(Media media) async {
      final headers = await store.head(
        '/media/by_id/${media.uuid}/download',
        queryParams: {'variant': 'original'},
      );
      final value = headers['cache-control'];
      expect(value, isNotNull, reason: 'the download names a cache policy');
      return value!;
    }

    setUpAll(() async {
      store = RemoteStore(baseUrl: baseUrl);
      sudoClient = await createRemoteSecureClient(
        baseUrl: baseUrl,
        store: store,
      );
      await clearTestArtifacts(
        client: sudoClient,
        username: sudoUsername,
        password: sudoPassword,
      );
      await sudoClient.auth.login(sudoUsername, sudoPassword);
      expect((await sudoClient.auth.getCurrentUser()).username, sudoUsername);
    });

    tearDownAll(() async {
      for (final id in uploaded) {
        await sudoClient.media.softDelete(id);
        await sudoClient.media.hardDelete(id);
      }
      await sudoClient.auth.logout();
    });

    test('a public item is publicly cacheable', () async {
      final media = await upload('public', ['public']);

      expect(await cacheControl(media), contains('public'));
    });

    test('an item restricted by access roles is not publicly '
        'cacheable', () async {
      final media = await upload('restricted', ['admin', 'coach']);

      final value = await cacheControl(media);
      expect(value, isNot(contains('public')));
      expect(value, anyOf(contains('private'), contains('no-store')));
    });

    test('an item only its uploader sees is not publicly cacheable', () async {
      final media = await upload('self', ['self']);

      final value = await cacheControl(media);
      expect(value, isNot(contains('public')));
      expect(value, anyOf(contains('private'), contains('no-store')));
    });
  });
}
