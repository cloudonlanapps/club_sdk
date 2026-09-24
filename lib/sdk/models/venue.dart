import 'dart:convert';

import 'package:meta/meta.dart';

/// Unified Venue model merged from auth/Venue (thin) + events/VenueInfo (thick).
@immutable
class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.address,
    this.description,
    this.mapUri,
    this.isDefault = false,
    this.isFeatured = false,
    this.deletedAtUtc,
    this.primaryVenueBadge,
  });

  factory Venue.fromMap(Map<String, dynamic> map) {
    return Venue(
      id: map['id'] as int,
      name: map['name'] as String,
      address: map['address'] as String?,
      description: map['description'] as String?,
      mapUri: map['mapUri'] as String?,
      isDefault: map['isDefault'] as bool? ?? false,
      isFeatured: map['isFeatured'] as bool? ?? false,
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAtUtc'] as int,
        isUtc: true,
      ),
      deletedAtUtc: map['deletedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['deletedAtUtc'] as int,
              isUtc: true,
            )
          : null,
      primaryVenueBadge: map['primaryVenueBadge'] as String?,
    );
  }

  factory Venue.fromJson(String source) =>
      Venue.fromMap(json.decode(source) as Map<String, dynamic>);
  final int id;
  final String name;
  final String? address;
  final String? description;
  final String? mapUri;
  final bool isDefault;
  final bool isFeatured;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? deletedAtUtc;

  /// Badge text for default/primary venue (e.g., "Primary Training Venue").
  /// Server-derived: populated only when isDefault is true.
  final String? primaryVenueBadge;

  /// Returns true if venue is active (not deleted).
  bool get isActive => deletedAtUtc == null;

  Venue copyWith({
    int? id,
    String? name,
    String? Function()? address,
    String? Function()? description,
    String? Function()? mapUri,
    bool? isDefault,
    bool? isFeatured,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? Function()? deletedAtUtc,
    String? Function()? primaryVenueBadge,
  }) {
    return Venue(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address != null ? address() : this.address,
      description: description != null ? description() : this.description,
      mapUri: mapUri != null ? mapUri() : this.mapUri,
      isDefault: isDefault ?? this.isDefault,
      isFeatured: isFeatured ?? this.isFeatured,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
      primaryVenueBadge: primaryVenueBadge != null
          ? primaryVenueBadge()
          : this.primaryVenueBadge,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'description': description,
      'mapUri': mapUri,
      'isDefault': isDefault,
      'isFeatured': isFeatured,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
      'primaryVenueBadge': primaryVenueBadge,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'Venue(id: $id, name: $name, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Venue &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.description == description &&
        other.mapUri == mapUri &&
        other.isDefault == isDefault &&
        other.isFeatured == isFeatured &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.deletedAtUtc == deletedAtUtc &&
        other.primaryVenueBadge == primaryVenueBadge;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        address.hashCode ^
        description.hashCode ^
        mapUri.hashCode ^
        isDefault.hashCode ^
        isFeatured.hashCode ^
        createdAtUtc.hashCode ^
        updatedAtUtc.hashCode ^
        deletedAtUtc.hashCode ^
        primaryVenueBadge.hashCode;
  }
}
