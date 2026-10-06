import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 7: an age is a length of years, months and days, the unit of the
/// age band on events and groups (club_server#16).
void main() {
  group('Issue 7: Age', () {
    test('months and days default to zero', () {
      const age = Age(years: 12);
      expect(age.years, 12);
      expect(age.months, 0);
      expect(age.days, 0);
    });

    test('fromMap reads years, months and days', () {
      final age = Age.fromMap(const {'years': 9, 'months': 6, 'days': 15});
      expect(age, const Age(years: 9, months: 6, days: 15));
    });

    test('fromMap takes missing months and days as zero', () {
      expect(Age.fromMap(const {'years': 9}), const Age(years: 9));
    });

    test('toMap writes all three parts', () {
      expect(const Age(years: 9, months: 6).toMap(), {
        'years': 9,
        'months': 6,
        'days': 0,
      });
    });

    test('toMap/fromMap and toJson/fromJson round-trip', () {
      const age = Age(years: 14, months: 11, days: 30);
      expect(Age.fromMap(age.toMap()), age);
      expect(Age.fromJson(age.toJson()), age);
    });

    test('copyWith changes one part and keeps the rest', () {
      const age = Age(years: 14, months: 3, days: 2);
      expect(age.copyWith(years: 15), const Age(years: 15, months: 3, days: 2));
      expect(age.copyWith(months: 0), const Age(years: 14, days: 2));
      expect(age.copyWith(days: 9), const Age(years: 14, months: 3, days: 9));
    });

    test('equality and hashCode follow the three parts', () {
      const a = Age(years: 10, months: 1);
      expect(a, const Age(years: 10, months: 1));
      expect(a.hashCode, const Age(years: 10, months: 1).hashCode);
      expect(a, isNot(const Age(years: 10)));
      expect(a, isNot(const Age(years: 10, months: 1, days: 1)));
    });
  });
}
