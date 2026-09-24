import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Pagination Model Unit Tests (PaginatedList).
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
/// - 20.12: Pagination - List-based APIs return PaginatedList
void main() {
  group('PaginatedList', () {
    test('hasMore returns true when more items available', () {
      const list = PaginatedList<int>(
        items: [1, 2],
        total: 5,
        limit: 2,
        offset: 0,
      );
      expect(list.hasMore, isTrue);
    });

    test('hasMore returns false when no more items', () {
      const list = PaginatedList<int>(
        items: [5],
        total: 5,
        limit: 2,
        offset: 4,
      );
      expect(list.hasMore, isFalse);
    });

    test('hasMore returns false when items equal total', () {
      const list = PaginatedList<int>(
        items: [1, 2, 3],
        total: 3,
        limit: 10,
        offset: 0,
      );
      expect(list.hasMore, isFalse);
    });

    test('two instances with same values are equal', () {
      const list1 = PaginatedList<int>(
        items: [1, 2, 3],
        total: 10,
        limit: 3,
        offset: 0,
      );
      const list2 = PaginatedList<int>(
        items: [1, 2, 3],
        total: 10,
        limit: 3,
        offset: 0,
      );
      expect(list1, list2);
    });

    test('two instances with different values are not equal', () {
      const list1 = PaginatedList<int>(
        items: [1, 2, 3],
        total: 10,
        limit: 3,
        offset: 0,
      );
      const list2 = PaginatedList<int>(
        items: [4, 5, 6],
        total: 10,
        limit: 3,
        offset: 3,
      );
      expect(list1, isNot(list2));
    });

    test('equal instances have same hashCode', () {
      const list1 = PaginatedList<int>(
        items: [1, 2, 3],
        total: 10,
        limit: 3,
        offset: 0,
      );
      const list2 = PaginatedList<int>(
        items: [1, 2, 3],
        total: 10,
        limit: 3,
        offset: 0,
      );
      expect(list1.hashCode, list2.hashCode);
    });

    test('copyWith creates new instance with changed field', () {
      const list = PaginatedList<int>(
        items: [1, 2, 3],
        total: 10,
        limit: 3,
        offset: 0,
      );
      final updated = list.copyWith(offset: 3, items: [4, 5, 6]);
      expect(updated.offset, 3);
      expect(updated.items, [4, 5, 6]);
      expect(updated.total, list.total);
      expect(updated.limit, list.limit);
    });

    test('toMap produces correct map structure', () {
      const list = PaginatedList<int>(
        items: [1, 2, 3],
        total: 10,
        limit: 3,
        offset: 0,
      );
      final map = list.toMap((item) => {'value': item});
      expect(map['items'], [
        {'value': 1},
        {'value': 2},
        {'value': 3},
      ]);
      expect(map['total'], 10);
      expect(map['limit'], 3);
      expect(map['offset'], 0);
    });

    test('fromMap restores equivalent instance with custom type', () {
      final list = PaginatedList<UserInfo>(
        items: [
          UserInfo.create(
            publicId: 'dummyID',
            username: 'testuser',
            firstName: 'Test',
            status: UserStatus.active,
            isSuperAdmin: false,
            roles: const UserRoles(),
          ),
        ],
        total: 50,
        limit: 20,
        offset: 0,
      );

      final map = list.toMap((u) => u.toMap());
      final restored = PaginatedList.fromMap(map, UserInfo.fromMap);

      expect(restored.items.length, 1);
      expect(restored.items.first.username, 'testuser');
      expect(restored.total, 50);
      expect(restored.limit, 20);
      expect(restored.offset, 0);
      expect(restored.hasMore, isTrue);
    });

    test('empty list has correct hasMore', () {
      const list = PaginatedList<int>(
        items: [],
        total: 0,
        limit: 10,
        offset: 0,
      );
      expect(list.hasMore, isFalse);
    });

    test('fromMap handles empty items list', () {
      final map = {
        'items': <Map<String, dynamic>>[],
        'total': 0,
        'limit': 10,
        'offset': 0,
      };
      final list = PaginatedList<int>.fromMap(map, (m) => m['value'] as int);
      expect(list.items, isEmpty);
      expect(list.total, 0);
    });
  });
}
