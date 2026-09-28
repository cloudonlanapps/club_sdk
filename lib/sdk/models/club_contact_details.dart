import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'localized_text.dart';

const _deepEquality = DeepCollectionEquality();

/// The `contact` block of the club's identity document (#90).
///
/// Every field is optional: a deployment fills in what it has. Keys this
/// model does not know, and known keys whose stored value it cannot read,
/// are kept in [extra] and written back unchanged by [toMap], so saving the
/// block never destroys what another client stored in it.
@immutable
class ClubContactDetails {
  const ClubContactDetails({
    this.phoneNumber,
    this.email,
    this.whatsappNumber,
    this.whatsappMessage,
    this.emailSubject,
    this.tagline,
    this.address,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.instagramUrl,
    this.extra = const {},
  });

  factory ClubContactDetails.fromMap(Map<String, dynamic> map) {
    final extra = Map<String, dynamic>.from(map);

    String? text(String key) {
      final value = map[key];
      if (value is! String) return null;
      extra.remove(key);
      return value;
    }

    LocalizedText? localized(String key) {
      final value = LocalizedText.fromWire(map[key]);
      if (value != null) extra.remove(key);
      return value;
    }

    return ClubContactDetails(
      phoneNumber: text(phoneNumberKey),
      email: text(emailKey),
      whatsappNumber: text(whatsappNumberKey),
      whatsappMessage: localized(whatsappMessageKey),
      emailSubject: localized(emailSubjectKey),
      tagline: localized(taglineKey),
      address: localized(addressKey),
      addressLine2: localized(addressLine2Key),
      city: localized(cityKey),
      state: localized(stateKey),
      postalCode: text(postalCodeKey),
      instagramUrl: text(instagramUrlKey),
      extra: extra,
    );
  }

  factory ClubContactDetails.fromJson(String source) =>
      ClubContactDetails.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Wire key of [phoneNumber].
  static const String phoneNumberKey = 'phoneNumber';

  /// Wire key of [email].
  static const String emailKey = 'email';

  /// Wire key of [whatsappNumber].
  static const String whatsappNumberKey = 'whatsappNumber';

  /// Wire key of [whatsappMessage].
  static const String whatsappMessageKey = 'whatsappMessage';

  /// Wire key of [emailSubject].
  static const String emailSubjectKey = 'emailSubject';

  /// Wire key of [tagline].
  static const String taglineKey = 'tagline';

  /// Wire key of [address].
  static const String addressKey = 'address';

  /// Wire key of [addressLine2].
  static const String addressLine2Key = 'addressLine2';

  /// Wire key of [city].
  static const String cityKey = 'city';

  /// Wire key of [state].
  static const String stateKey = 'state';

  /// Wire key of [postalCode].
  static const String postalCodeKey = 'postalCode';

  /// Wire key of [instagramUrl].
  static const String instagramUrlKey = 'instagramUrl';

  /// The club's public phone number.
  final String? phoneNumber;

  /// The club's public email address.
  final String? email;

  /// A separate WhatsApp number, when the club has one.
  final String? whatsappNumber;

  /// The message a WhatsApp link opens with.
  final LocalizedText? whatsappMessage;

  /// The subject an email link opens with.
  final LocalizedText? emailSubject;

  /// A one-line description of the club.
  final LocalizedText? tagline;

  /// First line of the postal address.
  final LocalizedText? address;

  /// Second line of the postal address.
  final LocalizedText? addressLine2;

  /// City of the postal address.
  final LocalizedText? city;

  /// State or region of the postal address.
  final LocalizedText? state;

  /// Postal code of the postal address.
  final String? postalCode;

  /// The club's Instagram profile URL.
  final String? instagramUrl;

  /// Stored keys this model does not read, written back unchanged.
  final Map<String, dynamic> extra;

  ClubContactDetails copyWith({
    String? Function()? phoneNumber,
    String? Function()? email,
    String? Function()? whatsappNumber,
    LocalizedText? Function()? whatsappMessage,
    LocalizedText? Function()? emailSubject,
    LocalizedText? Function()? tagline,
    LocalizedText? Function()? address,
    LocalizedText? Function()? addressLine2,
    LocalizedText? Function()? city,
    LocalizedText? Function()? state,
    String? Function()? postalCode,
    String? Function()? instagramUrl,
    Map<String, dynamic>? extra,
  }) {
    return ClubContactDetails(
      phoneNumber: phoneNumber != null ? phoneNumber() : this.phoneNumber,
      email: email != null ? email() : this.email,
      whatsappNumber: whatsappNumber != null
          ? whatsappNumber()
          : this.whatsappNumber,
      whatsappMessage: whatsappMessage != null
          ? whatsappMessage()
          : this.whatsappMessage,
      emailSubject: emailSubject != null ? emailSubject() : this.emailSubject,
      tagline: tagline != null ? tagline() : this.tagline,
      address: address != null ? address() : this.address,
      addressLine2: addressLine2 != null ? addressLine2() : this.addressLine2,
      city: city != null ? city() : this.city,
      state: state != null ? state() : this.state,
      postalCode: postalCode != null ? postalCode() : this.postalCode,
      instagramUrl: instagramUrl != null ? instagramUrl() : this.instagramUrl,
      extra: extra ?? this.extra,
    );
  }

  /// The block as stored: [extra], then every field that is set. A field
  /// that is `null` is left out rather than written as `null`.
  Map<String, dynamic> toMap() {
    return {
      ...extra,
      phoneNumberKey: ?phoneNumber,
      emailKey: ?email,
      whatsappNumberKey: ?whatsappNumber,
      whatsappMessageKey: ?whatsappMessage?.toWire(),
      emailSubjectKey: ?emailSubject?.toWire(),
      taglineKey: ?tagline?.toWire(),
      addressKey: ?address?.toWire(),
      addressLine2Key: ?addressLine2?.toWire(),
      cityKey: ?city?.toWire(),
      stateKey: ?state?.toWire(),
      postalCodeKey: ?postalCode,
      instagramUrlKey: ?instagramUrl,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() => 'ClubContactDetails(${toMap()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClubContactDetails &&
        other.phoneNumber == phoneNumber &&
        other.email == email &&
        other.whatsappNumber == whatsappNumber &&
        other.whatsappMessage == whatsappMessage &&
        other.emailSubject == emailSubject &&
        other.tagline == tagline &&
        other.address == address &&
        other.addressLine2 == addressLine2 &&
        other.city == city &&
        other.state == state &&
        other.postalCode == postalCode &&
        other.instagramUrl == instagramUrl &&
        _deepEquality.equals(other.extra, extra);
  }

  @override
  int get hashCode => Object.hash(
    phoneNumber,
    email,
    whatsappNumber,
    whatsappMessage,
    emailSubject,
    tagline,
    address,
    addressLine2,
    city,
    state,
    postalCode,
    instagramUrl,
    _deepEquality.hash(extra),
  );
}
