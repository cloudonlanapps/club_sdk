import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('RosterCreditFilter', () {
    test('Issue 20: wire names are the two the roster understands', () {
      expect(RosterCreditFilter.blocked.wireName, 'blocked');
      expect(RosterCreditFilter.expiringSoon.wireName, 'expiringSoon');
      expect(RosterCreditFilter.values, hasLength(2));
    });
  });
}
