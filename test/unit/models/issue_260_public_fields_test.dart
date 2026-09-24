import 'package:club_sdk_2/sdk/models/media_ref.dart';
import 'package:club_sdk_2/sdk/models/public_profile.dart';
import 'package:club_sdk_2/sdk/models/user.dart';
import 'package:test/test.dart';

/// Unit tests for the public-profile field additions (flutter #260, server
/// #262): `PublicProfile.avatar` and `UserInfo.isPublicProfile`.
///
/// The avatar was a bare uuid until club_server#424 replaced it with a
/// [MediaRef] descriptor; the snake_case `avatar_media_uuid` fallback went
/// with it, the public projection having only ever been camelCase.
void main() {
  const avatar = MediaRef(
    uuid: 'uuid-123',
    mimeType: 'image/webp',
    filename: 'uuid-123-face.webp',
  );

  group('PublicProfile.avatar', () {
    test('Issue 260: fromMap reads the avatar descriptor', () {
      final p = PublicProfile.fromMap({
        'publicId': 'abc',
        'displayName': 'Coach A',
        'avatar': avatar.toMap(),
      });
      expect(p.avatar, avatar);
    });

    test('Issue 424: the descriptor says what the file is', () {
      final p = PublicProfile.fromMap({
        'publicId': 'abc',
        'displayName': 'Coach A',
        'avatar': avatar.toMap(),
      });
      expect(p.avatar!.isImage, isTrue);
      expect(p.avatar!.mayHavePoster, isFalse);
    });

    test('Issue 260: avatar is null when absent', () {
      final p = PublicProfile.fromMap(const {
        'publicId': 'abc',
        'displayName': 'Coach A',
      });
      expect(p.avatar, isNull);
    });

    test('Issue 260: toMap/fromMap roundtrip preserves avatar', () {
      const p = PublicProfile(
        publicId: 'abc',
        displayName: 'Coach A',
        bio: 'bio',
        achievements: 'ach',
        avatar: avatar,
      );
      final restored = PublicProfile.fromMap(p.toMap());
      expect(restored, p);
      expect(restored.avatar, avatar);
    });
  });

  group('UserInfo.isPublicProfile', () {
    Map<String, dynamic> base() => {
      'username': 'coach1',
      'displayName': 'Coach One',
      'status': 'active',
      'roles': ['coach'],
    };

    test('Issue 260: fromMap reads camelCase isPublicProfile', () {
      final u = UserInfo.fromMap({...base(), 'isPublicProfile': true});
      expect(u.isPublicProfile, isTrue);
    });

    test('Issue 260: fromMap reads snake_case is_public_profile', () {
      final u = UserInfo.fromMap({...base(), 'is_public_profile': true});
      expect(u.isPublicProfile, isTrue);
    });

    test('Issue 260: defaults to false when absent', () {
      final u = UserInfo.fromMap(base());
      expect(u.isPublicProfile, isFalse);
    });

    test('Issue 260: server-sent publicId is honoured', () {
      final u = UserInfo.fromMap({...base(), 'publicId': 'hmac-id'});
      expect(u.publicId, 'hmac-id');
    });

    test('Issue 260: toMap/fromMap roundtrip preserves isPublicProfile', () {
      final u = UserInfo.fromMap({
        ...base(),
        'publicId': 'hmac-id',
        'isPublicProfile': true,
      });
      final restored = UserInfo.fromMap(u.toMap());
      expect(restored.isPublicProfile, isTrue);
      expect(restored, u);
    });
  });
}
