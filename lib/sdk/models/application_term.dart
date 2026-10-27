import 'package:meta/meta.dart';

import 'application_text.dart';

/// One rule printed on an application's page 2 (club_server#93, R6;
/// #107): a [heading] and a [body], each custom text. A library rule is
/// filled with `ApplicationSource.fillClause`, whose heading and text
/// become these.
@immutable
class ApplicationTerm {
  const ApplicationTerm({required this.heading, required this.body});

  /// Reads `{"heading", "body"}`.
  factory ApplicationTerm.fromMap(Map<String, dynamic> map) => ApplicationTerm(
    heading: ApplicationText.fromMap(map['heading'] as Map<String, dynamic>),
    body: ApplicationText.fromMap(map['body'] as Map<String, dynamic>),
  );

  /// The rule's heading.
  final ApplicationText heading;

  /// The rule's text.
  final ApplicationText body;

  Map<String, dynamic> toMap() => {
    'heading': heading.toMap(),
    'body': body.toMap(),
  };

  @override
  String toString() => 'ApplicationTerm(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationTerm &&
          other.heading == heading &&
          other.body == body;

  @override
  int get hashCode => Object.hash(heading, body);
}
