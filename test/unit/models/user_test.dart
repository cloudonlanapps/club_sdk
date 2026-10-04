import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// User Model Unit Tests (UserInfo, UserPrivate, UserRoles, UserStatus).
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('UserStatus', () {
    test('fromName parses active status', () {
      expect(UserStatus.fromName('active'), UserStatus.active);
    });

    test('fromName parses pending status', () {
      expect(UserStatus.fromName('pending'), UserStatus.pending);
    });

    test('Issue 374: fromName parses registered status', () {
      expect(UserStatus.fromName('registered'), UserStatus.registered);
    });

    test('Issue 374: registered status round-trips through name', () {
      const status = UserStatus.registered;
      expect(status.name, 'registered');
      expect(UserStatus.fromName(status.name), status);
    });

    test('fromName parses blocked status', () {
      expect(UserStatus.fromName('blocked'), UserStatus.blocked);
    });

    test('fromName parses left status', () {
      expect(UserStatus.fromName('left'), UserStatus.left);
    });

    test('fromName defaults to pending for unknown value', () {
      expect(UserStatus.fromName('unknown'), UserStatus.pending);
    });

    test('fromName is case-insensitive', () {
      expect(UserStatus.fromName('ACTIVE'), UserStatus.active);
    });
  });

  group('UserRoles', () {
    test('fromList creates roles with correct boolean flags', () {
      final roles = UserRoles.fromList(const ['admin', 'coach']);
      expect(roles.isCoach, isTrue);
      expect(roles.isAdmin, isTrue);
      expect(roles.rawRoles, [Role.admin, Role.coach]);
    });

    test('hasRole returns correct values for all role types', () {
      final roles = UserRoles.fromList(const ['admin', 'coach']);
      expect(roles.hasRole('admin'), isTrue);
      expect(roles.hasRole('coach'), isTrue);
      expect(roles.hasRole('member'), isFalse);
    });

    test('toMap produces correct map structure', () {
      final roles = UserRoles.fromList(const ['admin']);
      final map = roles.toMap();
      expect(map['isAdmin'], isTrue);
      expect(map['isCoach'], isFalse);
      expect(map['rawRoles'], ['admin']);
    });

    test('fromMap restores equivalent instance', () {
      final original = UserRoles.fromList(const ['member', 'coach']);
      final restored = UserRoles.fromMap(original.toMap());
      expect(restored, original);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final original = UserRoles.fromList(const ['admin', 'member']);
      final restored = UserRoles.fromJson(original.toJson());
      expect(restored, original);
    });

    test('copyWith creates new instance with changed field', () {
      final roles = UserRoles.fromList(const ['member']);
      final updated = roles.copyWith(isCoach: true);
      expect(updated.isMember, isTrue);
      expect(updated.isCoach, isTrue);
    });

    test('two instances with same values are equal', () {
      final roles1 = UserRoles.fromList(const ['member']);
      final roles2 = UserRoles.fromList(const ['member']);
      expect(roles1, roles2);
    });

    test('two instances with different values are not equal', () {
      final roles1 = UserRoles.fromList(const ['member']);
      final roles2 = UserRoles.fromList(const ['coach']);
      expect(roles1, isNot(roles2));
    });

    test('equal instances have same hashCode', () {
      final roles1 = UserRoles.fromList(const ['admin']);
      final roles2 = UserRoles.fromList(const ['admin']);
      expect(roles1.hashCode, roles2.hashCode);
    });
  });

  group('UserInfo', () {
    test('toMap/fromMap roundtrip preserves all fields', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john_doe',
        firstName: 'John',
        lastName: 'Doe',
        bio: 'My bio',
        achievements: 'My achievements',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member', 'coach']),
      );
      final map = user.toMap();
      final restored = UserInfo.fromMap(map);

      expect(restored.username, user.username);
      expect(restored.firstName, user.firstName);
      expect(restored.lastName, user.lastName);
      expect(restored.bio, 'My bio');
      expect(restored.achievements, 'My achievements');
      expect(restored.status, user.status);
      expect(restored.roles, user.roles);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john_doe',
        firstName: 'John',
        lastName: 'Doe',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final jsonStr = user.toJson();
      final restored = UserInfo.fromJson(jsonStr);
      expect(restored, user);
    });

    test('fromMap handles all optional fields as null', () {
      final map = {
        'publicId': 'test_id',
        'username': 'jane',
        'firstName': null,
        'lastName': null,
        'status': 'pending',
        'isSuperAdmin': false,
        'roles': <String>[],
      };
      final user = UserInfo.fromMap(map);
      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
      expect(user.bio, isNull);
      expect(user.achievements, isNull);
    });

    test('firstName-only user is valid', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'coach1',
        firstName: 'Coach',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['coach']),
      );
      expect(user.firstName, 'Coach');
      expect(user.lastName, isNull);
    });

    test('lastName-only user is valid', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'admin1',
        lastName: 'Smith',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['admin']),
      );
      expect(user.firstName, isNull);
      expect(user.lastName, 'Smith');
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final updated = user.copyWith(username: 'johnny');
      expect(updated.username, 'johnny');
      expect(updated.firstName, 'John');
    });

    test('copyWith preserves unchanged fields', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        lastName: 'Doe',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final updated = user.copyWith(status: UserStatus.blocked);

      expect(updated.username, 'john');
      expect(updated.firstName, 'John');
      expect(updated.lastName, 'Doe');
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final updated = user.copyWith(firstName: () => 'Johnny');
      expect(updated.firstName, 'Johnny');
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        lastName: 'Doe',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final updated = user.copyWith(
        firstName: () => 'Johnny',
        lastName: () => null,
      );
      expect(updated.firstName, 'Johnny');
      expect(updated.lastName, isNull);
    });

    test('two instances with same values are equal', () {
      final user1 = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final user2 = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      expect(user1, user2);
    });

    test('two instances with different values are not equal', () {
      final user1 = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final user2 = UserInfo.create(
        publicId: 'test_id',
        username: 'jane',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      expect(user1, isNot(user2));
    });

    test('equal instances have same hashCode', () {
      final user1 = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      final user2 = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
      );
      expect(user1.hashCode, user2.hashCode);
    });

    test('fromMap handles roles as List', () {
      final map = {
        'publicId': 'test_id',
        'username': 'john',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': ['member', 'coach'],
      };
      final user = UserInfo.fromMap(map);
      expect(user.roles.isMember, isTrue);
      expect(user.roles.isCoach, isTrue);
    });

    test('fromMap handles roles as Map', () {
      final map = {
        'publicId': 'test_id',
        'username': 'john',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': {
          'isAdmin': false,
          'isCoach': true,
          'isMember': true,
          'rawRoles': ['member', 'coach'],
        },
      };
      final user = UserInfo.fromMap(map);
      expect(user.roles.isMember, isTrue);
      expect(user.roles.isCoach, isTrue);
    });
  });

  group('UserInfo privacy fields', () {
    test('extends PublicProfile', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john_doe',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      expect(user, isA<PublicProfile>());
    });

    test('publicId is passed through from create', () {
      final user = UserInfo.create(
        publicId: 'test_public_id_123',
        username: 'john_doe',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      expect(user.publicId, 'test_public_id_123');
    });

    // Note: publicId generation was moved to server-side only

    test('nickname field is preserved in toMap/fromMap', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        nickname: 'Johnny',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      final map = user.toMap();
      final restored = UserInfo.fromMap(map);

      expect(restored.nickname, 'Johnny');
    });

    test('useNamePublicly defaults to false', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      expect(user.useNamePublicly, false);
    });

    test('useNamePublicly can be set to true', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        useNamePublicly: true,
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      expect(user.useNamePublicly, true);
    });

    test('displayName uses real name when useNamePublicly is true', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        lastName: 'Doe',
        useNamePublicly: true,
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      expect(user.displayName, 'John Doe');
    });

    test('displayName uses nickname when useNamePublicly is false', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        lastName: 'Doe',
        nickname: 'Johnny',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      expect(user.displayName, 'Johnny');
    });

    test(
      'displayName falls back to firstName + lastName when no nickname and '
      'useNamePublicly is false',
      () {
        // UserInfo is authenticated-only — when the privacy-respecting
        // computeDisplayName would yield "Name not provided", UserInfo should
        // fall back to whatever real data it already holds.
        final user = UserInfo.create(
          publicId: 'test_id',
          username: 'john',
          firstName: 'John',
          lastName: 'Doe',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
        );

        expect(user.displayName, 'John Doe');
      },
    );

    test(
      'displayName falls back to firstName when only firstName is set and '
      'useNamePublicly is false',
      () {
        final user = UserInfo.create(
          publicId: 'test_id',
          username: 'sudo',
          firstName: 'Sudo',
          status: UserStatus.active,
          isSuperAdmin: true,
          roles: const UserRoles(),
        );

        expect(user.displayName, 'Sudo');
      },
    );

    test(
      'displayName falls back to lastName when only lastName is set and '
      'useNamePublicly is false',
      () {
        final user = UserInfo.create(
          publicId: 'test_id',
          username: 'admin1',
          lastName: 'Smith',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
        );

        expect(user.displayName, 'Smith');
      },
    );

    test(
      'displayName falls back to username when no name fields are set',
      () {
        final user = UserInfo.create(
          publicId: 'test_id',
          username: 'plain_user',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
        );

        expect(user.displayName, 'plain_user');
      },
    );

    test(
      'displayName falls back to nickname when useNamePublicly is true but '
      'no real name is set',
      () {
        final user = UserInfo.create(
          publicId: 'test_id',
          username: 'jd',
          nickname: 'JD',
          useNamePublicly: true,
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
        );

        expect(user.displayName, 'JD');
      },
    );

    test(
      'fromMap normalizes a "Name not provided" displayName by recomputing '
      'from real fields',
      () {
        // Simulates a server response where the pre-computed displayName is
        // the privacy placeholder but the underlying name fields are present.
        final map = {
          'publicId': 'test_id',
          'displayName': 'Name not provided',
          'username': 'sudo',
          'firstName': 'Sudo',
          'status': 'active',
          'isSuperAdmin': true,
          'roles': <String>[],
        };

        final user = UserInfo.fromMap(map);

        expect(user.displayName, 'Sudo');
      },
    );

    test('copyWith can update nickname via ValueGetter', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      final updated = user.copyWith(nickname: () => 'Johnny');

      expect(updated.nickname, 'Johnny');
    });

    test('copyWith can update useNamePublicly', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      final updated = user.copyWith(useNamePublicly: true);

      expect(updated.useNamePublicly, true);
    });

    test('toMap includes nickname and useNamePublicly', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        nickname: 'Johnny',
        useNamePublicly: true,
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      final map = user.toMap();

      expect(map['nickname'], 'Johnny');
      expect(map['useNamePublicly'], true);
    });

    test('fromMap restores nickname and useNamePublicly', () {
      final map = {
        'publicId': 'test_id',
        'username': 'john',
        'nickname': 'Johnny',
        'useNamePublicly': true,
        'status': 'active',
        'isSuperAdmin': false,
        'roles': <String>[],
      };

      final user = UserInfo.fromMap(map);

      expect(user.nickname, 'Johnny');
      expect(user.useNamePublicly, true);
    });

    test('toMap includes publicId and displayName', () {
      final user = UserInfo.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        useNamePublicly: true,
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
      );

      final map = user.toMap();

      expect(map['publicId'], isNotEmpty);
      expect(map['displayName'], 'John');
    });

    group('RELEASE_3_0 deletedAtUtc', () {
      // ignore: but explicit deletedAtUtc makes intent clearer
      final deletedAt = DateTime.utc(2024, 7, 1);

      test('construction with deletedAtUtc', () {
        final user = UserInfo(
          username: 'john',
          displayName: 'John',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
          deletedAtUtc: deletedAt,
        );
        expect(user.deletedAtUtc, deletedAt);
      });

      test('toMap/fromMap roundtrip preserves deletedAtUtc', () {
        final user = UserInfo(
          username: 'john',
          displayName: 'John',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
          deletedAtUtc: deletedAt,
        );
        final restored = UserInfo.fromMap(user.toMap());
        expect(restored.deletedAtUtc, deletedAt);
      });

      test('fromMap handles null deletedAtUtc', () {
        final map = {
          'username': 'john',
          'status': 'active',
          'isSuperAdmin': false,
          'roles': <String>[],
        };
        final user = UserInfo.fromMap(map);
        expect(user.deletedAtUtc, isNull);
      });

      test('copyWith can set deletedAtUtc', () {
        const user = UserInfo(
          username: 'john',
          displayName: 'John',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: UserRoles(),
        );
        final updated = user.copyWith(deletedAtUtc: () => deletedAt);
        expect(updated.deletedAtUtc, deletedAt);
      });

      test('copyWith can clear deletedAtUtc to null', () {
        final user = UserInfo(
          username: 'john',
          displayName: 'John',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
          deletedAtUtc: deletedAt,
        );
        final cleared = user.copyWith(deletedAtUtc: () => null);
        expect(cleared.deletedAtUtc, isNull);
      });

      test('equality includes deletedAtUtc', () {
        final a = UserInfo(
          username: 'john',
          displayName: 'John',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
          deletedAtUtc: deletedAt,
        );
        final b = UserInfo(
          username: 'john',
          displayName: 'John',
          status: UserStatus.active,
          isSuperAdmin: false,
          roles: const UserRoles(),
          deletedAtUtc: deletedAt,
        );
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });
    });
  });

  group('UserPrivate', () {
    test('toMap/fromMap roundtrip preserves all fields', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john_doe',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+91-9000000000',
        dateOfBirthUtc: DateTime.utc(2010, 5, 20),
        bio: 'No allergies',
        achievements: 'State Champ',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: DateTime.utc(2024, 1, 15),
        medicalInfo: 'No allergies',
        emergencyContact: 'Jane Doe: +91-9111111111',
        lastLoginAtUtc: DateTime.utc(2024, 6),
      );
      final map = user.toMap();
      final restored = UserPrivate.fromMap(map);
      expect(restored.medicalInfo, user.medicalInfo);
      expect(restored.emergencyContact, user.emergencyContact);
      expect(restored.lastLoginAtUtc, user.lastLoginAtUtc);
      expect(restored.email, user.email);
      expect(restored.phone, user.phone);
      expect(restored.dateOfBirthUtc?.year, 2010);
      expect(restored.createdAtUtc, user.createdAtUtc);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        email: 'john@example.com',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: DateTime.utc(2024, 1, 15),
      );
      final jsonStr = user.toJson();
      final restored = UserPrivate.fromJson(jsonStr);
      expect(restored, user);
    });

    test(' dateOfBirthUtc serializes as millisecondsSinceEpoch', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'member1',
        firstName: 'Sam',
        dateOfBirthUtc: DateTime.utc(2010, 3, 7),
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: DateTime.utc(2024),
      );
      final map = user.toMap();
      expect(map['dateOfBirthUtc'], isA<int>());
      expect(
        map['dateOfBirthUtc'],
        DateTime.utc(2010, 3, 7).millisecondsSinceEpoch,
      );
    });

    test('copyWith handles password via ValueGetter', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        email: 'john@example.com',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: DateTime.utc(2024),
      );
      final updated = user.copyWith(password: () => 'new-secret');
      expect(updated.password, 'new-secret');
    });

    test('copyWith can set nullable field to null via ValueGetter', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        email: 'john@example.com',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: DateTime.utc(2024),
      );
      final updated = user.copyWith(email: () => null);
      expect(updated.email, isNull);
    });

    test('two instances with same values are equal', () {
      final createdAt = DateTime.utc(2024);
      final user1 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: createdAt,
      );
      final user2 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: createdAt,
      );
      expect(user1, user2);
    });

    test('two instances with different values are not equal', () {
      final createdAt = DateTime.utc(2024);
      final user1 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: createdAt,
      );
      final user2 = UserPrivate.create(
        publicId: 'test_id',
        username: 'jane',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: createdAt,
      );
      expect(user1, isNot(user2));
    });

    test('equal instances have same hashCode', () {
      final createdAt = DateTime.utc(2024);
      final user1 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: createdAt,
      );
      final user2 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: UserRoles.fromList(const ['member']),
        createdAtUtc: createdAt,
      );
      expect(user1.hashCode, user2.hashCode);
    });
  });

  group('UserPrivate privacy fields', () {
    test('extends UserInfo which extends PublicProfile', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john_doe',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      expect(user, isA<UserInfo>());
      expect(user, isA<PublicProfile>());
    });

    test('publicId is passed through from create', () {
      final user = UserPrivate.create(
        publicId: 'test_public_id',
        username: 'john_doe',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      expect(user.publicId, 'test_public_id');
    });

    test('nickname field is preserved in toMap/fromMap', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        nickname: 'Johnny',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final map = user.toMap();
      final restored = UserPrivate.fromMap(map);

      expect(restored.nickname, 'Johnny');
    });

    test('useNamePublicly field is preserved in toMap/fromMap', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        useNamePublicly: true,
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final map = user.toMap();
      final restored = UserPrivate.fromMap(map);

      expect(restored.useNamePublicly, true);
    });

    test('displayName reflects privacy settings', () {
      final publicUser = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        firstName: 'John',
        lastName: 'Doe',
        useNamePublicly: true,
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final privateUser = UserPrivate.create(
        publicId: 'test_id',
        username: 'jane',
        firstName: 'Jane',
        lastName: 'Doe',
        nickname: 'JD',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      expect(publicUser.displayName, 'John Doe');
      expect(privateUser.displayName, 'JD');
    });

    test('copyWith can update nickname via ValueGetter', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final updated = user.copyWith(nickname: () => 'Johnny');

      expect(updated.nickname, 'Johnny');
    });

    test('copyWith can update useNamePublicly', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final updated = user.copyWith(useNamePublicly: true);

      expect(updated.useNamePublicly, true);
    });
  });

  group('UserPrivate gender & address', () {
    test('create with gender and address', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        gender: Gender.male,
        address: const Address(
          addrLine1: '123 Main St',
          city: 'Pune',
          pincode: '411001',
        ),
      );

      expect(user.gender, Gender.male);
      expect(user.address?.addrLine1, '123 Main St');
      expect(user.address?.city, 'Pune');
      expect(user.address?.pincode, '411001');
    });

    test('create without gender and address defaults to null', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      expect(user.gender, isNull);
      expect(user.address, isNull);
    });

    test('toMap/fromMap roundtrip preserves gender and address', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        gender: Gender.female,
        address: const Address(
          addrLine1: '456 Oak Ave',
          addrLine2: 'Floor 2',
          city: 'Mumbai',
          state: 'Maharashtra',
          pincode: '400001',
        ),
      );

      final restored = UserPrivate.fromMap(user.toMap());

      expect(restored.gender, Gender.female);
      expect(restored.address?.addrLine1, '456 Oak Ave');
      expect(restored.address?.addrLine2, 'Floor 2');
      expect(restored.address?.city, 'Mumbai');
      expect(restored.address?.state, 'Maharashtra');
      expect(restored.address?.pincode, '400001');
    });

    test('toMap/fromMap roundtrip preserves null gender and address', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final restored = UserPrivate.fromMap(user.toMap());

      expect(restored.gender, isNull);
      expect(restored.address, isNull);
    });

    test('fromMap parses gender from snake_case server value', () {
      final map = {
        'publicId': 'test_id',
        'username': 'john',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': <String>[],
        'createdAtUtc': DateTime.utc(2024).millisecondsSinceEpoch,
        'gender': 'prefer_not_to_say',
      };

      final user = UserPrivate.fromMap(map);

      expect(user.gender, Gender.preferNotToSay);
    });

    test('fromMap parses address from nested map', () {
      final map = {
        'publicId': 'test_id',
        'username': 'john',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': <String>[],
        'createdAtUtc': DateTime.utc(2024).millisecondsSinceEpoch,
        'address': {
          'addrLine1': '789 Pine Rd',
          'city': 'Chennai',
        },
      };

      final user = UserPrivate.fromMap(map);

      expect(user.address?.addrLine1, '789 Pine Rd');
      expect(user.address?.city, 'Chennai');
      expect(user.address?.addrLine2, isNull);
    });

    test('toMap serializes gender as serverValue', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        gender: Gender.preferNotToSay,
      );

      final map = user.toMap();

      expect(map['gender'], 'prefer_not_to_say');
    });

    test('toMap serializes address as nested map', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        address: const Address(city: 'Pune'),
      );

      final map = user.toMap();

      expect(map['address'], isA<Map<String, dynamic>>());
      expect((map['address'] as Map<String, dynamic>)['city'], 'Pune');
    });

    test('copyWith can set gender', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final updated = user.copyWith(gender: () => Gender.other);

      expect(updated.gender, Gender.other);
    });

    test('copyWith can clear gender to null', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        gender: Gender.male,
      );

      final updated = user.copyWith(gender: () => null);

      expect(updated.gender, isNull);
    });

    test('copyWith can set address', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );

      final updated = user.copyWith(
        address: () => const Address(city: 'Pune', pincode: '411001'),
      );

      expect(updated.address?.city, 'Pune');
      expect(updated.address?.pincode, '411001');
    });

    group('Issue 377: adminReviewNote', () {
      test('Issue 377: defaults to null on UserPrivate(...)', () {
        final user = UserPrivate.create(
          publicId: 'test_id',
          username: 'john',
          status: UserStatus.registered,
          isSuperAdmin: false,
          roles: const UserRoles(),
          createdAtUtc: DateTime.utc(2024),
        );
        expect(user.adminReviewNote, isNull);
      });

      test('Issue 377: fromMap parses adminReviewNote when present', () {
        final map = {
          'publicId': 'test_id',
          'username': 'john',
          'status': 'registered',
          'isSuperAdmin': false,
          'roles': <String>[],
          'createdAtUtc': DateTime.utc(2024).millisecondsSinceEpoch,
          'adminReviewNote': 'fix DOB',
        };
        final user = UserPrivate.fromMap(map);
        expect(user.adminReviewNote, 'fix DOB');
      });

      test('Issue 377: fromMap leaves adminReviewNote null when absent', () {
        final map = {
          'publicId': 'test_id',
          'username': 'john',
          'status': 'registered',
          'isSuperAdmin': false,
          'roles': <String>[],
          'createdAtUtc': DateTime.utc(2024).millisecondsSinceEpoch,
        };
        final user = UserPrivate.fromMap(map);
        expect(user.adminReviewNote, isNull);
      });

      test('Issue 377: fromMap leaves adminReviewNote null when explicitly '
          'null', () {
        final map = {
          'publicId': 'test_id',
          'username': 'john',
          'status': 'registered',
          'isSuperAdmin': false,
          'roles': <String>[],
          'createdAtUtc': DateTime.utc(2024).millisecondsSinceEpoch,
          'adminReviewNote': null,
        };
        final user = UserPrivate.fromMap(map);
        expect(user.adminReviewNote, isNull);
      });

      test('Issue 377: toMap/fromMap roundtrip preserves adminReviewNote', () {
        final user = UserPrivate.create(
          publicId: 'test_id',
          username: 'john',
          status: UserStatus.registered,
          isSuperAdmin: false,
          roles: const UserRoles(),
          createdAtUtc: DateTime.utc(2024),
          adminReviewNote: 'please verify documents',
        );
        final restored = UserPrivate.fromMap(user.toMap());
        expect(restored.adminReviewNote, 'please verify documents');
      });

      test('Issue 377: copyWith can set adminReviewNote via ValueGetter', () {
        final user = UserPrivate.create(
          publicId: 'test_id',
          username: 'john',
          status: UserStatus.registered,
          isSuperAdmin: false,
          roles: const UserRoles(),
          createdAtUtc: DateTime.utc(2024),
        );
        final updated = user.copyWith(adminReviewNote: () => 'note');
        expect(updated.adminReviewNote, 'note');
      });

      test('Issue 377: copyWith can clear adminReviewNote to null', () {
        final user = UserPrivate.create(
          publicId: 'test_id',
          username: 'john',
          status: UserStatus.registered,
          isSuperAdmin: false,
          roles: const UserRoles(),
          createdAtUtc: DateTime.utc(2024),
          adminReviewNote: 'note',
        );
        final cleared = user.copyWith(adminReviewNote: () => null);
        expect(cleared.adminReviewNote, isNull);
      });

      test('Issue 377: equality includes adminReviewNote', () {
        final createdAt = DateTime.utc(2024);
        final a = UserPrivate.create(
          publicId: 'test_id',
          username: 'john',
          status: UserStatus.registered,
          isSuperAdmin: false,
          roles: const UserRoles(),
          createdAtUtc: createdAt,
          adminReviewNote: 'note',
        );
        final b = UserPrivate.create(
          publicId: 'test_id',
          username: 'john',
          status: UserStatus.registered,
          isSuperAdmin: false,
          roles: const UserRoles(),
          createdAtUtc: createdAt,
          adminReviewNote: 'note',
        );
        final c = b.copyWith(adminReviewNote: () => 'other');

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      });

      test('Issue 377: UserInfo.toMap does not include adminReviewNote', () {
        // Privacy invariant — the public/list model must not surface the
        // admin's review note. UserInfo neither declares the field nor
        // emits the key.
        final user = UserInfo.create(
          publicId: 'test_id',
          username: 'john',
          status: UserStatus.registered,
          isSuperAdmin: false,
          roles: const UserRoles(),
        );
        expect(user.toMap().containsKey('adminReviewNote'), isFalse);
      });

      test(
        'Issue 377: UserInfo.fromMap drops adminReviewNote when the server '
        'mistakenly leaks it',
        () {
          // Defence-in-depth: if a server bug ever surfaces the field on the
          // list payload, the SDK still does not retain it on UserInfo.
          final map = {
            'publicId': 'test_id',
            'username': 'john',
            'status': 'registered',
            'isSuperAdmin': false,
            'roles': <String>[],
            'adminReviewNote': 'leaked',
          };
          final user = UserInfo.fromMap(map);
          expect(user.toMap().containsKey('adminReviewNote'), isFalse);
        },
      );
    });

    test('copyWith can clear address to null', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        address: const Address(city: 'Pune'),
      );

      final updated = user.copyWith(address: () => null);

      expect(updated.address, isNull);
    });

    test('equality includes gender and address', () {
      final createdAt = DateTime.utc(2024);
      final user1 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: createdAt,
        gender: Gender.male,
        address: const Address(city: 'Pune'),
      );
      final user2 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: createdAt,
        gender: Gender.male,
        address: const Address(city: 'Pune'),
      );

      expect(user1, user2);
      expect(user1.hashCode, user2.hashCode);
    });

    test('different gender makes instances unequal', () {
      final createdAt = DateTime.utc(2024);
      final user1 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: createdAt,
        gender: Gender.male,
      );
      final user2 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: createdAt,
        gender: Gender.female,
      );

      expect(user1, isNot(user2));
    });

    test('different address makes instances unequal', () {
      final createdAt = DateTime.utc(2024);
      final user1 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: createdAt,
        address: const Address(city: 'Pune'),
      );
      final user2 = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: createdAt,
        address: const Address(city: 'Mumbai'),
      );

      expect(user1, isNot(user2));
    });

    test('deletedAtUtc is threaded through from UserInfo', () {
      // ignore: but explicit deletedAtUtc makes intent clearer
      final deletedAt = DateTime.utc(2024, 7, 1);
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        deletedAtUtc: deletedAt,
      );
      expect(user.deletedAtUtc, deletedAt);
    });

    test('toMap/fromMap roundtrip preserves deletedAtUtc on UserPrivate', () {
      // ignore: but explicit deletedAtUtc makes intent clearer
      final deletedAt = DateTime.utc(2024, 7, 1);
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
        deletedAtUtc: deletedAt,
      );
      final restored = UserPrivate.fromMap(user.toMap());
      expect(restored.deletedAtUtc, deletedAt);
    });

    test('copyWith can set deletedAtUtc on UserPrivate', () {
      final user = UserPrivate.create(
        publicId: 'test_id',
        username: 'john',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2024),
      );
      // ignore: but explicit deletedAtUtc makes intent clearer
      final deletedAt = DateTime.utc(2024, 7, 1);
      final updated = user.copyWith(deletedAtUtc: () => deletedAt);
      expect(updated.deletedAtUtc, deletedAt);
    });
  });
}
