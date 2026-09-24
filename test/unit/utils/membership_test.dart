import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('MembershipShim', () {
    tearDown(() => MembershipShim.overrideResolver(null));

    test('default resolver treats every user as a member', () {
      const memberRoles = UserRoles(isMember: true);
      const nonMemberRoles = UserRoles(isAdmin: true);

      expect(MembershipShim.isMember(memberRoles), isTrue);
      expect(MembershipShim.isMember(nonMemberRoles), isTrue);
    });

    test('overrideResolver swaps in a custom predicate', () {
      MembershipShim.overrideResolver((roles) => roles.isMember);

      expect(MembershipShim.isMember(const UserRoles(isMember: true)), isTrue);
      expect(MembershipShim.isMember(const UserRoles()), isFalse);
    });

    test('overrideResolver(null) restores the default everybody-is-member', () {
      MembershipShim.overrideResolver((_) => false);
      expect(MembershipShim.isMember(const UserRoles()), isFalse);

      MembershipShim.overrideResolver(null);
      expect(MembershipShim.isMember(const UserRoles()), isTrue);
    });
  });
}
