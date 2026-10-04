import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 1, 10);
  final occurrence = DateTime.utc(2026, 9, 1, 18);
  final payload = <String, dynamic>{
    'id': 41,
    'accountId': 'AB12CD34',
    'membername': 'alice',
    'amount': -1,
    'entryType': 'sessionDeduction',
    'eventId': 9,
    'occurrenceTimeUtc': occurrence.millisecondsSinceEpoch,
    'reason': 'Attendance',
    'actorUsername': 'coach1',
    'createdAtUtc': createdAt.millisecondsSinceEpoch,
    'offsetsEntryId': null,
    'balanceAfter': 9,
    'totalAfter': 29,
  };

  group('CreditEntry', () {
    test('Issue 22: fromMap reads balanceAfter and totalAfter', () {
      final entry = CreditEntry.fromMap(payload);

      expect(entry.id, 41);
      expect(entry.amount, -1);
      expect(entry.entryType, CreditEntryType.sessionDeduction);
      expect(entry.occurrenceTimeUtc, occurrence);
      expect(entry.balanceAfter, 9);
      expect(entry.totalAfter, 29);
    });

    test('Issue 22: fromMap reads null running figures from an older '
        'server', () {
      final entry = CreditEntry.fromMap(
        Map.of(payload)
          ..remove('balanceAfter')
          ..remove('totalAfter'),
      );

      expect(entry.balanceAfter, isNull);
      expect(entry.totalAfter, isNull);
    });

    test('Issue 22: toMap and fromMap round-trip', () {
      final entry = CreditEntry.fromMap(payload);

      expect(entry.toMap()['balanceAfter'], 9);
      expect(entry.toMap()['totalAfter'], 29);
      expect(CreditEntry.fromMap(entry.toMap()), entry);
      expect(CreditEntry.fromJson(entry.toJson()), entry);
    });

    test('Issue 22: copyWith sets and clears the running figures', () {
      final entry = CreditEntry.fromMap(payload);

      final changed = entry.copyWith(
        balanceAfter: () => 8,
        totalAfter: () => 28,
      );
      final cleared = entry.copyWith(
        balanceAfter: () => null,
        totalAfter: () => null,
      );

      expect(changed.balanceAfter, 8);
      expect(changed.totalAfter, 28);
      expect(cleared.balanceAfter, isNull);
      expect(cleared.totalAfter, isNull);
      expect(entry.copyWith(), entry);
    });

    test('Issue 22: the running figures take part in equality', () {
      final a = CreditEntry.fromMap(payload);

      expect(a, CreditEntry.fromMap(payload));
      expect(a.hashCode, CreditEntry.fromMap(payload).hashCode);
      expect(a, isNot(a.copyWith(balanceAfter: () => 8)));
      expect(a, isNot(a.copyWith(totalAfter: () => 28)));
      expect(a.hashCode, isNot(a.copyWith(totalAfter: () => 28).hashCode));
      expect(a.toString(), contains('balanceAfter: 9'));
      expect(a.toString(), contains('totalAfter: 29'));
    });
  });
}
