import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 7: a group member row reports `eligible` (club_server#17): false
/// for a semi-auto member who no longer meets the group's criteria.
void main() {
  group('Issue 7: GroupMember.eligible', () {
    test('fromMap reads eligible', () {
      final member = GroupMember.fromMap(const {
        'membername': 'amy',
        'eligible': false,
      });
      expect(member.eligible, isFalse);
    });

    test('eligible is true when the server omits it', () {
      expect(GroupMember.fromMap(const {'membername': 'amy'}).eligible, isTrue);
      expect(const GroupMember(membername: 'amy').eligible, isTrue);
    });

    test('eligible round-trips and takes part in equality', () {
      const out = GroupMember(membername: 'amy', eligible: false);
      expect(out.toMap()['eligible'], isFalse);
      expect(GroupMember.fromMap(out.toMap()), out);
      expect(GroupMember.fromJson(out.toJson()), out);
      expect(out, isNot(const GroupMember(membername: 'amy')));
      expect(
        out.copyWith(eligible: true),
        const GroupMember(membername: 'amy'),
      );
      expect(out.copyWith(firstName: () => 'Amy').eligible, isFalse);
    });
  });
}
