import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// The basic marketing block as the public catalogue projects it
/// (club_server#409, #22): the four presentation fields an event card
/// shows. `PublicEvent.marketing` is `null` when none of the four is set;
/// on the authenticated `Event` the same four live as top-level fields.
@immutable
class EventMarketingBasic {
  const EventMarketingBasic({
    this.shortDescription,
    this.stamp,
    this.highlights,
    this.includes,
  });

  factory EventMarketingBasic.fromMap(Map<String, dynamic> map) {
    return EventMarketingBasic(
      shortDescription: map['shortDescription'] as String?,
      stamp: map['stamp'] as String?,
      highlights: map['highlights'] != null
          ? List<String>.from(map['highlights'] as List)
          : null,
      includes: map['includes'] != null
          ? List<String>.from(map['includes'] as List)
          : null,
    );
  }

  factory EventMarketingBasic.fromJson(String source) =>
      EventMarketingBasic.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The line under the title on a card (up to 300 characters).
  final String? shortDescription;

  /// Badge text such as `New` or `Sold out` (up to 60 characters).
  final String? stamp;

  /// Selling points, up to 20 bullets.
  final List<String>? highlights;

  /// What is included, up to 20 bullets.
  final List<String>? includes;

  EventMarketingBasic copyWith({
    String? Function()? shortDescription,
    String? Function()? stamp,
    List<String>? Function()? highlights,
    List<String>? Function()? includes,
  }) {
    return EventMarketingBasic(
      shortDescription: shortDescription != null
          ? shortDescription()
          : this.shortDescription,
      stamp: stamp != null ? stamp() : this.stamp,
      highlights: highlights != null ? highlights() : this.highlights,
      includes: includes != null ? includes() : this.includes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shortDescription': shortDescription,
      'stamp': stamp,
      'highlights': highlights,
      'includes': includes,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EventMarketingBasic(shortDescription: $shortDescription, '
      'stamp: $stamp, highlights: $highlights, includes: $includes)';

  static const _listEquality = ListEquality<String>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventMarketingBasic &&
        other.shortDescription == shortDescription &&
        other.stamp == stamp &&
        _listEquality.equals(other.highlights, highlights) &&
        _listEquality.equals(other.includes, includes);
  }

  @override
  int get hashCode =>
      shortDescription.hashCode ^
      stamp.hashCode ^
      _listEquality.hash(highlights) ^
      _listEquality.hash(includes);
}
