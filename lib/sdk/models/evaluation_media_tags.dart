/// The media tags of an evaluation (club_server#535, R56a, R63).
///
/// Evidence for an answer is linked under its item's id; the stored member
/// copy of a published evaluation under [memberCopy].
abstract final class EvaluationMediaTags {
  /// The tag of the member copy PDF stored on publication.
  static const memberCopy = 'member_copy';

  /// The tag evidence for item [itemId] is linked under.
  static String evidence(int itemId) => '$itemId';

  /// The item id an evidence tag names, or null for any other tag.
  static int? itemIdOf(String tag) => int.tryParse(tag);
}
