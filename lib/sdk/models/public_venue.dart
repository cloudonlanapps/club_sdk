import 'dart:convert';

import 'package:meta/meta.dart';

import 'media_ref.dart';

/// A venue as the public website sees it (club_server#307, #22).
///
/// Addressed by an opaque [publicId] (an HMAC of the venue id); the
/// projection carries no integer id and no timestamps. Only live venues
/// are published.
@immutable
class PublicVenue {
  const PublicVenue({
    required this.publicId,
    required this.name,
    this.address,
    this.description,
    this.mapUri,
    this.isDefault = false,
    this.isFeatured = false,
    this.primaryVenueBadge,
    this.image,
  });

  factory PublicVenue.fromMap(Map<String, dynamic> map) {
    return PublicVenue(
      publicId: map['publicId'] as String,
      name: map['name'] as String,
      address: map['address'] as String?,
      description: map['description'] as String?,
      mapUri: map['mapUri'] as String?,
      isDefault: (map['isDefault'] as bool?) ?? false,
      isFeatured: (map['isFeatured'] as bool?) ?? false,
      primaryVenueBadge: map['primaryVenueBadge'] as String?,
      image: map['image'] != null
          ? MediaRef.fromMap(map['image'] as Map<String, dynamic>)
          : null,
    );
  }

  factory PublicVenue.fromJson(String source) =>
      PublicVenue.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Opaque public identifier; the key for `getPublicVenue` and the
  /// `venueId` filter of the public event catalogue.
  final String publicId;
  final String name;
  final String? address;
  final String? description;
  final String? mapUri;
  final bool isDefault;
  final bool isFeatured;

  /// Badge text for the default venue; server-derived, set only when
  /// [isDefault].
  final String? primaryVenueBadge;

  /// The newest publicly viewable `venue_image` media, or `null`.
  final MediaRef? image;

  PublicVenue copyWith({
    String? publicId,
    String? name,
    String? Function()? address,
    String? Function()? description,
    String? Function()? mapUri,
    bool? isDefault,
    bool? isFeatured,
    String? Function()? primaryVenueBadge,
    MediaRef? Function()? image,
  }) {
    return PublicVenue(
      publicId: publicId ?? this.publicId,
      name: name ?? this.name,
      address: address != null ? address() : this.address,
      description: description != null ? description() : this.description,
      mapUri: mapUri != null ? mapUri() : this.mapUri,
      isDefault: isDefault ?? this.isDefault,
      isFeatured: isFeatured ?? this.isFeatured,
      primaryVenueBadge: primaryVenueBadge != null
          ? primaryVenueBadge()
          : this.primaryVenueBadge,
      image: image != null ? image() : this.image,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'publicId': publicId,
      'name': name,
      'address': address,
      'description': description,
      'mapUri': mapUri,
      'isDefault': isDefault,
      'isFeatured': isFeatured,
      'primaryVenueBadge': primaryVenueBadge,
      'image': image?.toMap(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'PublicVenue(publicId: $publicId, name: $name, address: $address)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicVenue &&
        other.publicId == publicId &&
        other.name == name &&
        other.address == address &&
        other.description == description &&
        other.mapUri == mapUri &&
        other.isDefault == isDefault &&
        other.isFeatured == isFeatured &&
        other.primaryVenueBadge == primaryVenueBadge &&
        other.image == image;
  }

  @override
  int get hashCode =>
      publicId.hashCode ^
      name.hashCode ^
      address.hashCode ^
      description.hashCode ^
      mapUri.hashCode ^
      isDefault.hashCode ^
      isFeatured.hashCode ^
      primaryVenueBadge.hashCode ^
      image.hashCode;
}
