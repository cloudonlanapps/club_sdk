import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 27: `member` left the server's `Role` enum (club_server#400). The
/// SDK must stop offering it, so an app cannot assign a role the server
/// refuses with 422.
void main() {
  group('Issue 27: Role', () {
    test('Issue 27: values are superAdmin, admin and coach only', () {
      expect(Role.values, [Role.superAdmin, Role.admin, Role.coach]);
    });

    test('Issue 27: fromName rejects member like any unknown value', () {
      expect(() => Role.fromName('member'), throwsArgumentError);
      expect(() => Role.fromName('bogus'), throwsArgumentError);
    });

    test('Issue 27: tryFromName returns null for member', () {
      expect(Role.tryFromName('member'), isNull);
      expect(Role.tryFromName('coach'), Role.coach);
      expect(Role.tryFromName('super_admin'), Role.superAdmin);
    });

    test('Issue 27: UserRoles.fromList drops member from rawRoles', () {
      final roles = UserRoles.fromList(const ['member', 'coach']);
      expect(roles.rawRoles, [Role.coach]);
      expect(roles.toList(), ['coach']);
    });

    test('Issue 27: a user with no roles reads as an empty list', () {
      final user = UserInfo.fromMap(const {
        'publicId': 'p',
        'username': 'u',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': <String>[],
      });
      expect(user.roles.rawRoles, isEmpty);
      expect(user.roles.isAdmin, isFalse);
      expect(user.roles.isCoach, isFalse);
    });
  });
}
