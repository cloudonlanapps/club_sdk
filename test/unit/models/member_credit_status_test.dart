import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  final expiry = DateTime.utc(2026, 12, 31);
  final payload = <String, dynamic>{
    'membername': 'alice',
    'usableCredits': 0,
    'boundCredits': 5,
    'payingAccountId': null,
    'blocked': true,
    'nextExpiryUtc': null,
    'message': 'Blocked',
  };

  group('MemberCreditStatus', () {
    test('Issue 20: fromMap reads boundCredits', () {
      final status = MemberCreditStatus.fromMap(payload);

      expect(status.membername, 'alice');
      expect(status.usableCredits, 0);
      expect(status.boundCredits, 5);
      expect(status.blocked, isTrue);
      expect(status.payingAccountId, isNull);
    });

    test('Issue 20: fromMap defaults boundCredits to 0 from an older '
        'server', () {
      final status = MemberCreditStatus.fromMap(
        Map.of(payload)..remove('boundCredits'),
      );

      expect(status.boundCredits, 0);
    });

    test('toMap and fromMap round-trip', () {
      final status = MemberCreditStatus(
        membername: 'bob',
        usableCredits: 7,
        boundCredits: 4,
        blocked: false,
        payingAccountId: 'AB12CD34',
        nextExpiryUtc: expiry,
      );

      expect(MemberCreditStatus.fromMap(status.toMap()), status);
      expect(MemberCreditStatus.fromJson(status.toJson()), status);
      expect(status.toMap()['boundCredits'], 4);
    });

    test('Issue 20: copyWith replaces boundCredits and keeps the rest', () {
      final status = MemberCreditStatus.fromMap(payload);

      final copy = status.copyWith(boundCredits: 2);

      expect(copy.boundCredits, 2);
      expect(copy.membername, status.membername);
      expect(copy.usableCredits, status.usableCredits);
      expect(status.copyWith(), status);
    });

    test('copyWith clears a nullable field through its ValueGetter', () {
      final status = MemberCreditStatus.fromMap(
        Map.of(payload)
          ..['payingAccountId'] = 'AB12CD34'
          ..['nextExpiryUtc'] = expiry.millisecondsSinceEpoch,
      );

      final copy = status.copyWith(
        payingAccountId: () => null,
        nextExpiryUtc: () => null,
      );

      expect(copy.payingAccountId, isNull);
      expect(copy.nextExpiryUtc, isNull);
    });

    test('Issue 20: boundCredits takes part in equality and hashCode', () {
      final a = MemberCreditStatus.fromMap(payload);
      final b = a.copyWith(boundCredits: 6);

      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
      expect(a, MemberCreditStatus.fromMap(payload));
      expect(a.hashCode, MemberCreditStatus.fromMap(payload).hashCode);
      expect(a.toString(), contains('boundCredits: 5'));
    });
  });
}
