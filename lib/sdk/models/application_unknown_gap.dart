import 'package:meta/meta.dart';

/// One gap a save found naming no fact of the template (club_server#126,
/// `APPLICATION_UNKNOWN_FACT`): the text's [place], the [language] of the
/// text it is in, and the [gap]'s name.
///
/// [place] is one of `organisation`, `title`, `subtitle`, `header[i]`,
/// `header[i][j]` (line `j` of a header item of lines), `selections[i]`,
/// `declaration`, `form_footer`, `terms[i].heading`, `terms[i].body`,
/// `terms_notes[i].text` or `terms_notes[i].attribution`; indexes are
/// 0-based.
@immutable
class ApplicationUnknownGap {
  const ApplicationUnknownGap({
    required this.place,
    required this.language,
    required this.gap,
  });

  /// Reads `{"place", "language", "gap"}`.
  factory ApplicationUnknownGap.fromMap(Map<String, dynamic> map) =>
      ApplicationUnknownGap(
        place: map['place'] as String,
        language: map['language'] as String,
        gap: map['gap'] as String,
      );

  /// Where the text is on the template.
  final String place;

  /// The language of the text the gap is in.
  final String language;

  /// The gap's name, without its braces.
  final String gap;

  Map<String, dynamic> toMap() => {
    'place': place,
    'language': language,
    'gap': gap,
  };

  @override
  String toString() => '$place ($language): $gap';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationUnknownGap &&
          other.place == place &&
          other.language == language &&
          other.gap == gap;

  @override
  int get hashCode => Object.hash(place, language, gap);
}
