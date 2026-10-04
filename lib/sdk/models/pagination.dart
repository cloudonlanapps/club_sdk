import 'package:meta/meta.dart';

@immutable
class PaginatedList<T> {
  const PaginatedList({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PaginatedList.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) fromMapT,
  ) {
    return PaginatedList<T>(
      items: (map['items'] as List)
          .map((e) => fromMapT(e as Map<String, dynamic>))
          .toList(),
      total: map['total'] as int,
      limit: map['limit'] as int,
      offset: map['offset'] as int,
    );
  }
  final List<T> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  PaginatedList<T> copyWith({
    List<T>? items,
    int? total,
    int? limit,
    int? offset,
  }) {
    return PaginatedList<T>(
      items: items ?? this.items,
      total: total ?? this.total,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }

  Map<String, dynamic> toMap(Map<String, dynamic> Function(T) toMapT) {
    return {
      'items': items.map(toMapT).toList(),
      'total': total,
      'limit': limit,
      'offset': offset,
    };
  }

  @override
  String toString() {
    return 'PaginatedList(items: ${items.length}, total: $total, '
        'limit: $limit, offset: $offset)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaginatedList<T> &&
        other.total == total &&
        other.limit == limit &&
        other.offset == offset &&
        _listEquals(other.items, items);
  }

  bool _listEquals(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      items.hashCode ^ total.hashCode ^ limit.hashCode ^ offset.hashCode;
}
