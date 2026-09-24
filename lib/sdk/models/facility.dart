import 'dart:convert';

import 'package:meta/meta.dart';

/// A facility the event offers, on its extended marketing block
/// (club_server#410, #22). [iconName] is a hint the client maps to an
/// icon of its own; the server stores it as sent.
@immutable
class Facility {
  const Facility({required this.name, this.description, this.iconName});

  factory Facility.fromMap(Map<String, dynamic> map) {
    return Facility(
      name: map['name'] as String,
      description: map['description'] as String?,
      iconName: map['iconName'] as String?,
    );
  }

  factory Facility.fromJson(String source) =>
      Facility.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The facility, e.g. `Rink`.
  final String name;

  /// A line about it, e.g. `Olympic size`.
  final String? description;

  /// A client-side icon key; the server does not interpret it.
  final String? iconName;

  Facility copyWith({
    String? name,
    String? Function()? description,
    String? Function()? iconName,
  }) {
    return Facility(
      name: name ?? this.name,
      description: description != null ? description() : this.description,
      iconName: iconName != null ? iconName() : this.iconName,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'description': description, 'iconName': iconName};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'Facility(name: $name, description: $description, iconName: $iconName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Facility &&
        other.name == name &&
        other.description == description &&
        other.iconName == iconName;
  }

  @override
  int get hashCode => name.hashCode ^ description.hashCode ^ iconName.hashCode;
}
