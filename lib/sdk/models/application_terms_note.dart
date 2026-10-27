import 'package:meta/meta.dart';

import 'application_text.dart';

/// A closing note boxed under an application's terms (club_server#93,
/// R6; #107): a [text] with an optional [attribution] (a motto and who
/// said it), each custom text.
@immutable
class ApplicationTermsNote {
  const ApplicationTermsNote({required this.text, this.attribution});

  /// Reads `{"text", "attribution"?}`.
  factory ApplicationTermsNote.fromMap(Map<String, dynamic> map) =>
      ApplicationTermsNote(
        text: ApplicationText.fromMap(map['text'] as Map<String, dynamic>),
        attribution: ApplicationText.fromWire(map['attribution']),
      );

  /// The note's text.
  final ApplicationText text;

  /// Who the note is from, printed under it.
  final ApplicationText? attribution;

  /// Leaves out an unset attribution, as the server returns it.
  Map<String, dynamic> toMap() => {
    'text': text.toMap(),
    'attribution': ?attribution?.toMap(),
  };

  @override
  String toString() => 'ApplicationTermsNote(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationTermsNote &&
          other.text == text &&
          other.attribution == attribution;

  @override
  int get hashCode => Object.hash(text, attribution);
}
