import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// The membership pitch on an event's extended marketing block
/// (club_server#410, #22): what joining the club adds to this event.
@immutable
class ClubMembership {
  const ClubMembership({required this.title, this.description, this.benefits});

  factory ClubMembership.fromMap(Map<String, dynamic> map) {
    return ClubMembership(
      title: map['title'] as String,
      description: map['description'] as String?,
      benefits: map['benefits'] != null
          ? List<String>.from(map['benefits'] as List)
          : null,
    );
  }

  factory ClubMembership.fromJson(String source) =>
      ClubMembership.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The headline, e.g. `Members`.
  final String title;

  /// The pitch, in a sentence.
  final String? description;

  /// What members get, as bullets.
  final List<String>? benefits;

  ClubMembership copyWith({
    String? title,
    String? Function()? description,
    List<String>? Function()? benefits,
  }) {
    return ClubMembership(
      title: title ?? this.title,
      description: description != null ? description() : this.description,
      benefits: benefits != null ? benefits() : this.benefits,
    );
  }

  Map<String, dynamic> toMap() {
    return {'title': title, 'description': description, 'benefits': benefits};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'ClubMembership(title: $title, description: $description, '
      'benefits: $benefits)';

  static const _listEquality = ListEquality<String>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClubMembership &&
        other.title == title &&
        other.description == description &&
        _listEquality.equals(other.benefits, benefits);
  }

  @override
  int get hashCode =>
      title.hashCode ^ description.hashCode ^ _listEquality.hash(benefits);
}
