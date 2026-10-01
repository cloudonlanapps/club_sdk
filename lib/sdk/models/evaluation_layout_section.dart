part of 'evaluation_layout_entry.dart';

/// A titled group of [items] in a layout. Sections hold items only.
@immutable
final class EvaluationLayoutSection<T> extends EvaluationLayoutEntry<T> {
  const EvaluationLayoutSection(this.section, this.items);

  /// Reads a section, decoding each item with [decodeItem].
  factory EvaluationLayoutSection.fromMap(
    Map<String, dynamic> map,
    T Function(Object? wire) decodeItem,
  ) {
    return EvaluationLayoutSection<T>(
      map[sectionKey] as String,
      ((map[itemsKey] as List?) ?? const <dynamic>[])
          .map(decodeItem)
          .toList(growable: false),
    );
  }

  /// The wire key of the section title.
  static const sectionKey = 'section';

  /// The wire key of the section's items.
  static const itemsKey = 'items';

  /// The section title.
  final String section;

  @override
  final List<T> items;

  EvaluationLayoutSection<T> copyWith({String? section, List<T>? items}) =>
      EvaluationLayoutSection<T>(section ?? this.section, items ?? this.items);

  /// The wire shape, with each item written by [encodeItem].
  Map<String, dynamic> toMap(Object? Function(T item) encodeItem) =>
      <String, dynamic>{
        sectionKey: section,
        itemsKey: items.map(encodeItem).toList(),
      };

  @override
  Object? toWire(Object? Function(T item) encodeItem) => toMap(encodeItem);

  @override
  String toString() => 'EvaluationLayoutSection($section, $items)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationLayoutSection<T> &&
        other.section == section &&
        evaluationLayoutEquality.equals(other.items, items);
  }

  @override
  int get hashCode =>
      Object.hash(section, evaluationLayoutEquality.hash(items));
}
