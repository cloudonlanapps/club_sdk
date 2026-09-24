import 'package:club_sdk_2/sdk/models/public_profile.dart';
import 'package:test/test.dart';

/// Public Profile Model Unit Tests.
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
///
/// Also supports requirement 16.01-16.02 (Public Staff) from Public API.
void main() {
  group('PublicProfile', () {
    group('serialization', () {
      test('toMap/fromMap roundtrip preserves all fields', () {
        const profile = PublicProfile(
          publicId: 'abc123xyz',
          displayName: 'John Doe',
          bio: 'A software developer',
          achievements: 'Gold medal in coding',
        );

        final map = profile.toMap();
        final restored = PublicProfile.fromMap(map);

        expect(restored.publicId, profile.publicId);
        expect(restored.displayName, profile.displayName);
        expect(restored.bio, profile.bio);
        expect(restored.achievements, profile.achievements);
      });

      test('toJson/fromJson roundtrip preserves all fields', () {
        const profile = PublicProfile(
          publicId: 'abc123xyz',
          displayName: 'Jane Smith',
          bio: 'A coach',
        );

        final json = profile.toJson();
        final restored = PublicProfile.fromJson(json);

        expect(restored, profile);
      });

      test('fromMap handles null optional fields', () {
        final map = {
          'publicId': 'test_id',
          'displayName': 'Test User',
        };

        final profile = PublicProfile.fromMap(map);

        expect(profile.publicId, 'test_id');
        expect(profile.displayName, 'Test User');
        expect(profile.bio, isNull);
        expect(profile.achievements, isNull);
      });
    });

    group('copyWith', () {
      test('creates new instance with changed non-nullable field', () {
        const profile = PublicProfile(
          publicId: 'original_id',
          displayName: 'Original Name',
        );

        final updated = profile.copyWith(displayName: 'New Name');

        expect(updated.publicId, 'original_id');
        expect(updated.displayName, 'New Name');
      });

      test('can set nullable field to new value via ValueGetter', () {
        const profile = PublicProfile(
          publicId: 'test_id',
          displayName: 'Test',
        );

        final updated = profile.copyWith(bio: () => 'New bio');

        expect(updated.bio, 'New bio');
      });

      test('can reset nullable field to null via ValueGetter', () {
        const profile = PublicProfile(
          publicId: 'test_id',
          displayName: 'Test',
          bio: 'Has a bio',
        );

        final updated = profile.copyWith(bio: () => null);

        expect(updated.bio, isNull);
      });

      test('preserves unchanged fields', () {
        const profile = PublicProfile(
          publicId: 'test_id',
          displayName: 'Test',
          bio: 'Bio here',
          achievements: 'Some achievements',
        );

        final updated = profile.copyWith(displayName: 'New Name');

        expect(updated.bio, 'Bio here');
        expect(updated.achievements, 'Some achievements');
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        const profile1 = PublicProfile(
          publicId: 'same_id',
          displayName: 'Same Name',
          bio: 'Same bio',
        );
        const profile2 = PublicProfile(
          publicId: 'same_id',
          displayName: 'Same Name',
          bio: 'Same bio',
        );

        expect(profile1, profile2);
      });

      test('two instances with different values are not equal', () {
        const profile1 = PublicProfile(
          publicId: 'id1',
          displayName: 'Name 1',
        );
        const profile2 = PublicProfile(
          publicId: 'id2',
          displayName: 'Name 2',
        );

        expect(profile1, isNot(profile2));
      });

      test('equal instances have same hashCode', () {
        const profile1 = PublicProfile(
          publicId: 'same_id',
          displayName: 'Same Name',
        );
        const profile2 = PublicProfile(
          publicId: 'same_id',
          displayName: 'Same Name',
        );

        expect(profile1.hashCode, profile2.hashCode);
      });
    });

    group('toString', () {
      test('returns descriptive string', () {
        const profile = PublicProfile(
          publicId: 'test_id',
          displayName: 'Test User',
        );

        final str = profile.toString();

        expect(str, contains('PublicProfile'));
        expect(str, contains('test_id'));
        expect(str, contains('Test User'));
      });
    });
  });

  // Note: generatePublicId was removed from client SDK - it's server-only now

  group('computePublicDisplayName', () {
    test('returns real name when useNamePublicly is true with both names', () {
      final name = computePublicDisplayName(
        useNamePublicly: true,
        firstName: 'John',
        lastName: 'Doe',
      );

      expect(name, 'John Doe');
    });

    test(
      'returns first name only when lastName is null and useNamePublicly',
      () {
        final name = computePublicDisplayName(
          useNamePublicly: true,
          firstName: 'John',
        );

        expect(name, 'John');
      },
    );

    test(
      'returns last name only when firstName is null and useNamePublicly',
      () {
        final name = computePublicDisplayName(
          useNamePublicly: true,
          lastName: 'Doe',
        );

        expect(name, 'Doe');
      },
    );

    test(
      'returns "Name not provided" when useNamePublicly true but no name',
      () {
        final name = computePublicDisplayName(useNamePublicly: true);

        expect(name, 'Name not provided');
      },
    );

    test('returns "Name not provided" when useNamePublicly true with empty '
        'strings', () {
      final name = computePublicDisplayName(
        useNamePublicly: true,
        firstName: '',
        lastName: '',
      );

      expect(name, 'Name not provided');
    });

    test('returns nickname when useNamePublicly is false', () {
      final name = computePublicDisplayName(
        useNamePublicly: false,
        firstName: 'John',
        lastName: 'Doe',
        nickname: 'JD',
      );

      expect(name, 'JD');
    });

    test('returns "Name not provided" when no nickname and useNamePublicly is '
        'false', () {
      final name = computePublicDisplayName(
        useNamePublicly: false,
        firstName: 'John',
        lastName: 'Doe',
      );

      expect(name, 'Name not provided');
    });

    test('returns "Name not provided" when nickname is null and '
        'useNamePublicly is false', () {
      final name = computePublicDisplayName(
        useNamePublicly: false,
      );

      expect(name, 'Name not provided');
    });

    test(
      'prioritizes nickname over real name when useNamePublicly is false',
      () {
        final name = computePublicDisplayName(
          useNamePublicly: false,
          firstName: 'Jonathan',
          lastName: 'Doe',
          nickname: 'Johnny',
        );

        expect(name, 'Johnny');
      },
    );
  });

  group('computeDisplayName (authenticated, rich fallback)', () {
    test('returns real name when useNamePublicly is true with both names', () {
      final name = computeDisplayName(
        username: 'jdoe',
        useNamePublicly: true,
        firstName: 'John',
        lastName: 'Doe',
      );

      expect(name, 'John Doe');
    });

    test(
      'returns nickname when useNamePublicly is false and nickname is set',
      () {
        final name = computeDisplayName(
          username: 'jdoe',
          useNamePublicly: false,
          firstName: 'John',
          lastName: 'Doe',
          nickname: 'JD',
        );

        expect(name, 'JD');
      },
    );

    test('falls back to firstName + lastName when useNamePublicly is false '
        'and no nickname', () {
      final name = computeDisplayName(
        username: 'jdoe',
        useNamePublicly: false,
        firstName: 'John',
        lastName: 'Doe',
      );

      expect(name, 'John Doe');
    });

    test(
      'falls back to firstName-only when lastName is null and no nickname',
      () {
        final name = computeDisplayName(
          username: 'sudo',
          useNamePublicly: false,
          firstName: 'Sudo',
        );

        expect(name, 'Sudo');
      },
    );

    test(
      'falls back to lastName-only when firstName is null and no nickname',
      () {
        final name = computeDisplayName(
          username: 'admin1',
          useNamePublicly: false,
          lastName: 'Smith',
        );

        expect(name, 'Smith');
      },
    );

    test(
      'falls back to nickname when useNamePublicly is true but no real name',
      () {
        final name = computeDisplayName(
          username: 'jd',
          useNamePublicly: true,
          nickname: 'JD',
        );

        expect(name, 'JD');
      },
    );

    test('falls back to username as the last resort', () {
      final name = computeDisplayName(
        username: 'plain_user',
        useNamePublicly: false,
      );

      expect(name, 'plain_user');
    });

    test('treats whitespace-only nickname as empty', () {
      final name = computeDisplayName(
        username: 'jdoe',
        useNamePublicly: false,
        firstName: 'John',
        nickname: '   ',
      );

      expect(name, 'John');
    });

    test('never returns the "Name not provided" placeholder', () {
      // Exhaustive: every shape of (useNamePublicly × name fields) should
      // produce something derived from real input, never the placeholder.
      final samples = [
        computeDisplayName(username: 'u', useNamePublicly: true),
        computeDisplayName(username: 'u', useNamePublicly: false),
        computeDisplayName(
          username: 'u',
          useNamePublicly: true,
          firstName: '',
          lastName: '',
        ),
        computeDisplayName(
          username: 'u',
          useNamePublicly: false,
          nickname: '',
        ),
      ];
      for (final n in samples) {
        expect(n, isNot('Name not provided'));
        expect(n, isNotEmpty);
      }
    });
  });
}
