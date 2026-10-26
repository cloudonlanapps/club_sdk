import 'dart:convert';

import 'package:meta/meta.dart';

/// A member's parent or guardian, part of the extended profile
/// (club_server#92, #66). Separate from the emergency contact.
///
/// Every part is optional. The server accepts these three keys only, and
/// a phone of at most 20 characters.
@immutable
class Guardian {
  const Guardian({this.name, this.relation, this.phone});

  factory Guardian.fromMap(Map<String, dynamic> map) {
    return Guardian(
      name: map['name'] as String?,
      relation: map['relation'] as String?,
      phone: map['phone'] as String?,
    );
  }

  factory Guardian.fromJson(String source) =>
      Guardian.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The guardian's name.
  final String? name;

  /// How they are related to the member (`Mother`, `Uncle`, …).
  final String? relation;

  /// The guardian's phone number.
  final String? phone;

  /// True when every part is null or empty.
  bool get isEmpty =>
      (name == null || name!.isEmpty) &&
      (relation == null || relation!.isEmpty) &&
      (phone == null || phone!.isEmpty);

  Guardian copyWith({
    String? Function()? name,
    String? Function()? relation,
    String? Function()? phone,
  }) {
    return Guardian(
      name: name != null ? name() : this.name,
      relation: relation != null ? relation() : this.relation,
      phone: phone != null ? phone() : this.phone,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'relation': relation, 'phone': phone};
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'Guardian(name: $name, relation: $relation, phone: $phone)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Guardian &&
        other.name == name &&
        other.relation == relation &&
        other.phone == phone;
  }

  @override
  int get hashCode => name.hashCode ^ relation.hashCode ^ phone.hashCode;
}
