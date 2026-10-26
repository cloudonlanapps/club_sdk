import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_text.dart';

/// One item of an application's header strip (club_server#93, R6): a
/// single text, or a list of texts printed one per line.
///
/// A list of one text stays a list: [toWire] writes the shape
/// `fromWire` read.
@immutable
class ApplicationHeaderItem {
  /// One text.
  const ApplicationHeaderItem.single(ApplicationText this.text) : lines = null;

  /// Several texts, one per line.
  const ApplicationHeaderItem.lines(List<ApplicationText> this.lines)
    : text = null;

  /// Reads a text (a map) or a list of texts.
  factory ApplicationHeaderItem.fromWire(Object value) => value is List
      ? ApplicationHeaderItem.lines([
          for (final e in value)
            ApplicationText.fromMap(e as Map<String, dynamic>),
        ])
      : ApplicationHeaderItem.single(
          ApplicationText.fromMap(value as Map<String, dynamic>),
        );

  /// The single text, when this is not a list.
  final ApplicationText? text;

  /// The texts, when this is a list.
  final List<ApplicationText>? lines;

  /// Whether this item is a list of texts.
  bool get isLines => lines != null;

  /// The texts in print order, either way.
  List<ApplicationText> get texts => lines ?? [text!];

  /// The JSON value: a map, or a list of maps.
  Object toWire() => lines?.map((t) => t.toMap()).toList() ?? text!.toMap();

  @override
  String toString() => 'ApplicationHeaderItem(${toWire()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationHeaderItem &&
          other.text == text &&
          const ListEquality<ApplicationText>().equals(other.lines, lines);

  @override
  int get hashCode =>
      Object.hash(text, const ListEquality<ApplicationText>().hash(lines));
}
