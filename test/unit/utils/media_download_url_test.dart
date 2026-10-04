import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Issue 553: mediaDownloadUrlParts', () {
    test(
      'Issue 553: parses uuid with default variant when query is absent',
      () {
        final parts = mediaDownloadUrlParts(
          'https://api.example.com/v1/media/by_id/abc-123/download',
        );
        expect(parts, isNotNull);
        expect(parts!.uuid, 'abc-123');
        expect(parts.variant, 'original');
      },
    );

    test('Issue 553: parses explicit variant=original', () {
      final parts = mediaDownloadUrlParts(
        'https://api.example.com/v1/media/by_id/abc-123/download?variant=original',
      );
      expect(parts, isNotNull);
      expect(parts!.uuid, 'abc-123');
      expect(parts.variant, 'original');
    });

    test('Issue 553: parses variant=poster', () {
      final parts = mediaDownloadUrlParts(
        'https://api.example.com/v1/media/by_id/uu/download?variant=poster',
      );
      expect(parts, isNotNull);
      expect(parts!.uuid, 'uu');
      expect(parts.variant, 'poster');
    });

    test('Issue 553: parses variant=animated', () {
      final parts = mediaDownloadUrlParts(
        'https://api.example.com/v1/media/by_id/u/download?variant=animated',
      );
      expect(parts, isNotNull);
      expect(parts!.variant, 'animated');
    });

    test('Issue 553: works without a version path prefix', () {
      final parts = mediaDownloadUrlParts(
        'https://api.example.com/media/by_id/abc/download',
      );
      expect(parts, isNotNull);
      expect(parts!.uuid, 'abc');
    });

    test('Issue 553: returns null for legacy /uploaded/... URLs', () {
      final parts = mediaDownloadUrlParts(
        'https://api.example.com/v1/uploaded/by_id/abc/download',
      );
      expect(parts, isNull);
    });

    test('Issue 553: returns null when path does not end in /download', () {
      final parts = mediaDownloadUrlParts(
        'https://api.example.com/v1/media/by_id/abc',
      );
      expect(parts, isNull);
    });

    test('Issue 553: returns null for malformed strings', () {
      expect(mediaDownloadUrlParts(''), isNull);
      expect(mediaDownloadUrlParts('not-a-url'), isNull);
    });
  });

  group('Issue 424: mediaDownloadUrl', () {
    const video = MediaRef(
      uuid: 'vid-1',
      mimeType: 'video/mp4',
      filename: 'vid-1-club_christmas_camp.mp4',
    );
    const photo = MediaRef(
      uuid: 'img-1',
      mimeType: 'image/webp',
      filename: 'img-1-rink.webp',
    );
    const base = 'https://api.example.com/v1';

    test('Issue 424: the original carries the filename in the path', () {
      expect(
        mediaDownloadUrl(base, video),
        'https://api.example.com/v1/media/by_id/vid-1/download/'
        'vid-1-club_christmas_camp.mp4',
      );
    });

    test('Issue 424: a trailing slash on the base is not doubled', () {
      expect(
        mediaDownloadUrl('$base/', photo),
        'https://api.example.com/v1/media/by_id/img-1/download/img-1-rink.webp',
      );
    });

    test('Issue 424: a variant is a query, and carries no filename', () {
      expect(
        mediaDownloadUrl(base, video, variant: 'poster'),
        'https://api.example.com/v1/media/by_id/vid-1/download?variant=poster',
      );
    });

    test('Issue 424: the built URL parses back to uuid and variant', () {
      final original = mediaDownloadUrlParts(mediaDownloadUrl(base, video));
      expect(original!.uuid, 'vid-1');
      expect(original.variant, 'original');

      final poster = mediaDownloadUrlParts(
        mediaDownloadUrl(base, video, variant: 'poster'),
      );
      expect(poster!.uuid, 'vid-1');
      expect(poster.variant, 'poster');
    });

    test('Issue 424: previews exist only where the server has them', () {
      expect(
        mediaPosterUrl(base, video),
        'https://api.example.com/v1/media/by_id/vid-1/download?variant=poster',
      );
      expect(
        mediaAnimatedUrl(base, video),
        'https://api.example.com/v1/media/by_id/vid-1/download?variant=animated',
      );
      // An image is its own preview: null beats a URL that cannot exist.
      expect(mediaPosterUrl(base, photo), isNull);
      expect(mediaAnimatedUrl(base, photo), isNull);
    });
  });
}
