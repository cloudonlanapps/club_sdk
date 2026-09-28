import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'club_contact_details.dart';

const _deepEquality = DeepCollectionEquality();

/// The club's public identity: the `club_info` system preference, typed
/// (#90).
///
/// The server reads [name] and [shortName] to brand its email and
/// [inquiryEmail] to route inquiries; a website reads [name] and [contact].
/// The public club-info read carries the same document (`clubInfo`).
///
/// The preference is free-form, and deployments store more in it than this
/// model names. Keys this model does not know, and known keys whose stored
/// value it cannot read, are kept in [extra] and written back unchanged by
/// [toMap], so saving the identity never destroys the rest of the document.
@immutable
class ClubIdentity {
  const ClubIdentity({
    this.name,
    this.shortName,
    this.inquiryEmail,
    this.contact,
    this.extra = const {},
  });

  factory ClubIdentity.fromMap(Map<String, dynamic> map) {
    final extra = Map<String, dynamic>.from(map);

    String? text(String key) {
      final value = map[key];
      if (value is! String) return null;
      extra.remove(key);
      return value;
    }

    final block = map[contactKey];
    ClubContactDetails? contact;
    if (block is Map) {
      contact = ClubContactDetails.fromMap(Map<String, dynamic>.from(block));
      extra.remove(contactKey);
    }

    return ClubIdentity(
      name: text(nameKey),
      shortName: text(shortNameKey),
      inquiryEmail: text(inquiryEmailKey),
      contact: contact,
      extra: extra,
    );
  }

  factory ClubIdentity.fromJson(String source) =>
      ClubIdentity.fromMap(json.decode(source) as Map<String, dynamic>);

  /// The system-preference key this document is stored under.
  static const String preferenceKey = 'club_info';

  /// Wire key of [name].
  static const String nameKey = 'name';

  /// Wire key of [shortName].
  static const String shortNameKey = 'shortName';

  /// Wire key of [inquiryEmail].
  static const String inquiryEmailKey = 'inquiryEmail';

  /// Wire key of [contact].
  static const String contactKey = 'contact';

  /// The club's full name. A plain string: the server's email branding
  /// reads it as one.
  final String? name;

  /// The club's short name, used where the full name does not fit.
  final String? shortName;

  /// Where the server sends inquiries submitted through the public form.
  final String? inquiryEmail;

  /// The public contact block.
  final ClubContactDetails? contact;

  /// Stored keys this model does not read, written back unchanged.
  final Map<String, dynamic> extra;

  ClubIdentity copyWith({
    String? Function()? name,
    String? Function()? shortName,
    String? Function()? inquiryEmail,
    ClubContactDetails? Function()? contact,
    Map<String, dynamic>? extra,
  }) {
    return ClubIdentity(
      name: name != null ? name() : this.name,
      shortName: shortName != null ? shortName() : this.shortName,
      inquiryEmail: inquiryEmail != null ? inquiryEmail() : this.inquiryEmail,
      contact: contact != null ? contact() : this.contact,
      extra: extra ?? this.extra,
    );
  }

  /// The document as stored: [extra], then every field that is set. A field
  /// that is `null` is left out rather than written as `null`.
  Map<String, dynamic> toMap() {
    return {
      ...extra,
      nameKey: ?name,
      shortNameKey: ?shortName,
      inquiryEmailKey: ?inquiryEmail,
      contactKey: ?contact?.toMap(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ClubIdentity(${toMap()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClubIdentity &&
        other.name == name &&
        other.shortName == shortName &&
        other.inquiryEmail == inquiryEmail &&
        other.contact == contact &&
        _deepEquality.equals(other.extra, extra);
  }

  @override
  int get hashCode => Object.hash(
    name,
    shortName,
    inquiryEmail,
    contact,
    _deepEquality.hash(extra),
  );
}
