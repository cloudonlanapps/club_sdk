part of 'evaluation_layout_entry.dart';

/// A layout entry holding one [item], outside any section.
@immutable
final class EvaluationLayoutItem<T> extends EvaluationLayoutEntry<T> {
  const EvaluationLayoutItem(this.item);

  final T item;

  @override
  List<T> get items => [item];

  EvaluationLayoutItem<T> copyWith({T? item}) =>
      EvaluationLayoutItem<T>(item ?? this.item);

  @override
  Object? toWire(Object? Function(T item) encodeItem) => encodeItem(item);

  @override
  String toString() => 'EvaluationLayoutItem($item)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EvaluationLayoutItem<T> && other.item == item;
  }

  @override
  int get hashCode => item.hashCode;
}
