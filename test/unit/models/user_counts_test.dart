import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 30: `GET /users/count` wrapper model.
void main() {
  group('Issue 30: UserCounts', () {
    const wire = {
      'byStatus': {
        'registered': 2,
        'pending': 1,
        'active': 10,
        'blocked': 0,
        'left': 3,
      },
      'total': 16,
    };

    test('Issue 30: fromMap keys every status', () {
      final counts = UserCounts.fromMap(wire);
      expect(counts.of(UserStatus.registered), 2);
      expect(counts.of(UserStatus.pending), 1);
      expect(counts.of(UserStatus.active), 10);
      expect(counts.of(UserStatus.blocked), 0);
      expect(counts.of(UserStatus.left), 3);
      expect(counts.total, 16);
      expect(counts.byStatus.keys, containsAll(UserStatus.values));
    });

    test('Issue 30: a missing bucket reads as zero', () {
      final counts = UserCounts.fromMap(const {
        'byStatus': {'active': 4},
        'total': 4,
      });
      expect(counts.of(UserStatus.left), 0);
      expect(counts.byStatus.length, UserStatus.values.length);
    });

    test('Issue 30: toMap/fromMap and toJson/fromJson round-trip', () {
      final counts = UserCounts.fromMap(wire);
      expect(UserCounts.fromMap(counts.toMap()), counts);
      expect(UserCounts.fromJson(counts.toJson()), counts);
      expect(counts.toMap(), wire);
    });

    test('Issue 30: value equality and copyWith', () {
      final a = UserCounts.fromMap(wire);
      final b = UserCounts.fromMap(wire);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(total: 17), isNot(a));
      expect(a.copyWith(total: 17).total, 17);
    });
  });
}
