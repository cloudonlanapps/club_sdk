import 'dart:convert';

import 'package:meta/meta.dart';

/// Structured postal address for a user.
@immutable
class Address {
  const Address({
    this.addrLine1,
    this.addrLine2,
    this.city,
    this.state,
    this.pincode,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      addrLine1: map['addrLine1'] as String?,
      addrLine2: map['addrLine2'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      pincode: map['pincode'] as String?,
    );
  }

  factory Address.fromJson(String source) =>
      Address.fromMap(json.decode(source) as Map<String, dynamic>);

  final String? addrLine1;
  final String? addrLine2;
  final String? city;
  final String? state;
  final String? pincode;

  /// True when all fields are null or empty.
  bool get isEmpty =>
      (addrLine1 == null || addrLine1!.isEmpty) &&
      (addrLine2 == null || addrLine2!.isEmpty) &&
      (city == null || city!.isEmpty) &&
      (state == null || state!.isEmpty) &&
      (pincode == null || pincode!.isEmpty);

  Address copyWith({
    String? Function()? addrLine1,
    String? Function()? addrLine2,
    String? Function()? city,
    String? Function()? state,
    String? Function()? pincode,
  }) {
    return Address(
      addrLine1: addrLine1 != null ? addrLine1() : this.addrLine1,
      addrLine2: addrLine2 != null ? addrLine2() : this.addrLine2,
      city: city != null ? city() : this.city,
      state: state != null ? state() : this.state,
      pincode: pincode != null ? pincode() : this.pincode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'addrLine1': addrLine1,
      'addrLine2': addrLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'Address(addrLine1: $addrLine1, addrLine2: $addrLine2, '
        'city: $city, state: $state, pincode: $pincode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Address &&
        other.addrLine1 == addrLine1 &&
        other.addrLine2 == addrLine2 &&
        other.city == city &&
        other.state == state &&
        other.pincode == pincode;
  }

  @override
  int get hashCode =>
      addrLine1.hashCode ^
      addrLine2.hashCode ^
      city.hashCode ^
      state.hashCode ^
      pincode.hashCode;
}
