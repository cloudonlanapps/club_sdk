/// The kind of an evaluation template item (club_server#535, R12).
///
/// Every kind but [info] is a question and takes an answer: a [rating] on
/// a scale or labelled levels, [yesNo], a [singleChoice] or
/// [multipleChoice] among the item's choices, any [number], or written
/// text for a [qa]. An [info] item is markdown shown to the reader.
enum EvaluationItemType {
  rating('rating'),
  yesNo('yesNo'),
  singleChoice('singleChoice'),
  multipleChoice('multipleChoice'),
  number('number'),
  qa('qa'),
  info('info');

  const EvaluationItemType(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Whether an item of this kind takes an answer.
  bool get isQuestion => this != info;

  /// Parse a wire value.
  static EvaluationItemType fromWire(String wire) {
    for (final v in EvaluationItemType.values) {
      if (v.wireName == wire) return v;
    }
    throw ArgumentError('Unknown evaluation item type: $wire');
  }
}
