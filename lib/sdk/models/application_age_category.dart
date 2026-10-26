import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'gender.dart';

/// An age group on an application's form (club_server#93, R11): a member
/// born within the cutoffs, both inclusive, and of one of the [genders]
/// matches it. Every category prints; the matching one is ticked. A
/// template with categories offers its form only to a member one of them
/// matches (422 `APPLICATION_NOT_ELIGIBLE` otherwise).
///
/// [toMap] leaves out what is not set, as the server returns it.
@immutable
class ApplicationAgeCategory {
  const ApplicationAgeCategory({
    required this.label,
    this.bornOnOrAfterUtc,
    this.bornOnOrBeforeUtc,
    this.genders,
  });

  factory ApplicationAgeCategory.fromMap(Map<String, dynamic> map) {
    final genders = map['genders'] as List?;
    return ApplicationAgeCategory(
      label: {
        for (final e in (map['label'] as Map).entries)
          e.key as String: e.value as String,
      },
      bornOnOrAfterUtc: dateFromWire(map['bornOnOrAfterUtc']),
      bornOnOrBeforeUtc: dateFromWire(map['bornOnOrBeforeUtc']),
      genders: genders
          ?.map((g) => Gender.fromName(g as String))
          .toList(growable: false),
    );
  }

  /// A UTC date from ms, or null.
  static DateTime? dateFromWire(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;

  /// The category's name per language (`Under-12`).
  final Map<String, String> label;

  /// The earliest birth day, a UTC midnight; null is no lower bound.
  final DateTime? bornOnOrAfterUtc;

  /// The latest birth day, a UTC midnight; null is no upper bound.
  final DateTime? bornOnOrBeforeUtc;

  /// The genders it admits; null admits any.
  final List<Gender>? genders;

  Map<String, dynamic> toMap() => {
    'label': {...label},
    'bornOnOrAfterUtc': ?bornOnOrAfterUtc?.millisecondsSinceEpoch,
    'bornOnOrBeforeUtc': ?bornOnOrBeforeUtc?.millisecondsSinceEpoch,
    'genders': ?genders?.map((g) => g.serverValue).toList(),
  };

  @override
  String toString() => 'ApplicationAgeCategory(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationAgeCategory &&
          const MapEquality<String, String>().equals(other.label, label) &&
          other.bornOnOrAfterUtc == bornOnOrAfterUtc &&
          other.bornOnOrBeforeUtc == bornOnOrBeforeUtc &&
          const ListEquality<Gender>().equals(other.genders, genders);

  @override
  int get hashCode => Object.hash(
    const MapEquality<String, String>().hash(label),
    bornOnOrAfterUtc,
    bornOnOrBeforeUtc,
    const ListEquality<Gender>().hash(genders),
  );
}
