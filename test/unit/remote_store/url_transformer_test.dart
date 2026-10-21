import 'dart:convert';

import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Issue 32: urlTransformer rewrites URLs only, never a bare filename.
void main() {
  http.Response json(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  RemoteStore storeReturning(Object body) => RemoteStore(
    baseUrl: 'https://example.test/v1',
    client: MockClient((_) async => json(body, 200)),
    urlTransformer: (url) => '$url?v=20260101',
  );

  group('Issue 32 (R1): urlTransformer must not rewrite a bare filename', () {
    test(
      'Issue 32: a Media filename ending in .jpg is returned as the server '
      'sent it',
      () async {
        final body = await storeReturning({
          'filename': 'photo.jpg',
        }).get('/media/by_id/1');
        // Actual today: "photo.jpg?v=20260101".
        expect(body['filename'], 'photo.jpg');
      },
    );

    test('Issue 32: a bare name ending in .json is left alone', () async {
      final body = await storeReturning({'name': 'rules.json'}).get('/x');
      expect(body['name'], 'rules.json');
    });

    test('Issue 32: URLs are still transformed', () async {
      final body = await storeReturning({
        'abs': 'https://cdn.example.test/a.jpg',
        'path': '/static/media/a.jpg',
      }).get('/x');
      expect(body['abs'], 'https://cdn.example.test/a.jpg?v=20260101');
      expect(body['path'], endsWith('/static/media/a.jpg?v=20260101'));
    });

    test(
      'Issue 32: a relative name with a static folder is left alone',
      () async {
        final body = await storeReturning({
          'name': 'old/static/a.txt',
        }).get('/x');
        expect(body['name'], 'old/static/a.txt');
      },
    );

    test('Issue 32: a root-relative media path is transformed', () async {
      final body = await storeReturning({'p': '/media/a.mp4'}).get('/x');
      expect(body['p'], '/media/a.mp4?v=20260101');
    });

    test('Issue 32: an http URL to a page is left alone', () async {
      final body = await storeReturning({
        'site': 'http://www.myexampleclub.com/about',
      }).get('/x');
      expect(body['site'], 'http://www.myexampleclub.com/about');
    });
  });
}
