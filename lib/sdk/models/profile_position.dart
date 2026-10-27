import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

const _labelEquality = MapEquality<String, String>();

/// One of the club's positions in its `ProfileOptions` (club_server#92,
/// #66): the [value] stored in a member's `preferredPositions`, and its name
/// in each language a form may print it in.
@immutable
class ProfilePosition {
  const ProfilePosition({required this.value, this.label = const {}});

  /// Reads `{value, label: {<language>: name}}`. Label entries whose value
  /// is not a string are skipped.
  factory ProfilePosition.fromMap(Map<String, dynamic> map) {
    final label = map['label'];
    return ProfilePosition(
      value: map['value'] as String,
      label: label is Map
          ? {
              for (final entry in label.entries)
                if (entry.value is String)
                  entry.key.toString(): entry.value as String,
            }
          : const {},
    );
  }

  factory ProfilePosition.fromJson(String source) =>
      ProfilePosition.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The stored value, sent in `preferredPositions`.
  final String value;

  /// The position's name keyed by language (`en`, `mr`, …). The server
  /// requires at least one entry when it is written.
  final Map<String, String> label;

  /// The name for [language], else [value].
  String labelFor(String language) => label[language] ?? value;

  ProfilePosition copyWith({String? value, Map<String, String>? label}) {
    return ProfilePosition(
      value: value ?? this.value,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toMap() => {'value': value, 'label': label};

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ProfilePosition(value: $value, label: $label)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfilePosition &&
        other.value == value &&
        _labelEquality.equals(other.label, label);
  }

  @override
  int get hashCode => value.hashCode ^ _labelEquality.hash(label);
}
