import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 27: `member` left the server's `Role` enum (club_server#400). The
/// SDK must stop offering it, so an app cannot assign a role the server
/// refuses with 422. `super_admin` followed (club_server#514): super admin is
/// the `isSuperAdmin` flag, changed only by transfer, never a role.
void main() {
  group('Issue 27: Role', () {
    test('club_server#514: values are admin and coach only', () {
      expect(Role.values, [Role.admin, Role.coach]);
    });

    test('Issue 27: fromName rejects member like any unknown value', () {
      expect(() => Role.fromName('member'), throwsArgumentError);
      expect(() => Role.fromName('bogus'), throwsArgumentError);
    });

    test('Issue 27: tryFromName returns null for member', () {
      expect(Role.tryFromName('member'), isNull);
      expect(Role.tryFromName('coach'), Role.coach);
    });

    test('club_server#514: super_admin is not a role, in either spelling', () {
      expect(() => Role.fromName('super_admin'), throwsArgumentError);
      expect(Role.tryFromName('super_admin'), isNull);
      expect(Role.tryFromName('superAdmin'), isNull);
    });

    test('club_server#514: UserRoles.fromList drops a stored super_admin', () {
      final roles = UserRoles.fromList(const ['super_admin', 'admin']);
      expect(roles.rawRoles, [Role.admin]);
      expect(roles.isAdmin, isTrue);
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
