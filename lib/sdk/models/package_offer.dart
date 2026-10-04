import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// A priced package on an event's extended marketing block
/// (club_server#410, #22).
@immutable
class PackageOffer {
  const PackageOffer({
    required this.name,
    required this.price,
    this.description,
    this.features,
  });

  factory PackageOffer.fromMap(Map<String, dynamic> map) {
    return PackageOffer(
      name: map['name'] as String,
      price: map['price'] as int,
      description: map['description'] as String?,
      features: map['features'] != null
          ? List<String>.from(map['features'] as List)
          : null,
    );
  }

  factory PackageOffer.fromJson(String source) =>
      PackageOffer.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The package's name, e.g. `Standard`.
  final String name;

  /// The package price, whole units.
  final int price;

  /// What the package is, in a sentence.
  final String? description;

  /// What the package includes, as bullets.
  final List<String>? features;

  PackageOffer copyWith({
    String? name,
    int? price,
    String? Function()? description,
    List<String>? Function()? features,
  }) {
    return PackageOffer(
      name: name ?? this.name,
      price: price ?? this.price,
      description: description != null ? description() : this.description,
      features: features != null ? features() : this.features,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'description': description,
      'features': features,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'PackageOffer(name: $name, price: $price, description: $description, '
      'features: $features)';

  static const _listEquality = ListEquality<String>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PackageOffer &&
        other.name == name &&
        other.price == price &&
        other.description == description &&
        _listEquality.equals(other.features, features);
  }

  @override
  int get hashCode =>
      name.hashCode ^
      price.hashCode ^
      description.hashCode ^
      _listEquality.hash(features);
}
