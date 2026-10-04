import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

part 'evaluation_layout_item.dart';
part 'evaluation_layout_section.dart';

/// One entry of a template's layout (club_server#535, R12c): a single item,
/// or a titled section of items. Sections do not nest.
///
/// [T] is what an entry holds. A template read from the server lays out
/// item ids (`EvaluationLayoutEntry<int>`); a template being created lays
/// out its new items inline (`EvaluationLayoutEntry<EvaluationTemplateItem>`).
@immutable
sealed class EvaluationLayoutEntry<T> {
  const EvaluationLayoutEntry();

  /// Reads one wire entry: a map with a `section` key is a section, anything
  /// else an item, decoded by [decodeItem].
  factory EvaluationLayoutEntry.fromWire(
    Object? wire,
    T Function(Object? wire) decodeItem,
  ) {
    if (wire is Map && wire.containsKey(EvaluationLayoutSection.sectionKey)) {
      return EvaluationLayoutSection<T>.fromMap(
        Map<String, dynamic>.from(wire),
        decodeItem,
      );
    }
    return EvaluationLayoutItem<T>(decodeItem(wire));
  }

  /// Reads a layout of item ids, as the server returns it.
  static List<EvaluationLayoutEntry<int>> idsFromWire(List<dynamic>? wire) =>
      (wire ?? const <dynamic>[])
          .map((e) => EvaluationLayoutEntry<int>.fromWire(e, idFromWire))
          .toList(growable: false);

  /// Decodes one item id.
  static int idFromWire(Object? wire) => (wire! as num).toInt();

  /// Every item this entry holds, in order.
  List<T> get items;

  /// The wire shape, with each item written by [encodeItem].
  Object? toWire(Object? Function(T item) encodeItem);
}

/// Deep equality for layouts.
const evaluationLayoutEquality = DeepCollectionEquality();
