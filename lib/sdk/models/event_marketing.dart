import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'club_membership.dart';
import 'facility.dart';
import 'fee_item.dart';
import 'package_offer.dart';
import 'promotional_offer.dart';

/// An event's extended marketing block (club_server#410, #22): the
/// commercial detail behind the deployment-gated Event Marketing module.
///
/// This is the writable body and the read projection in one. The server's
/// responses add the event's identity beside these fields (`eventId` on
/// the authenticated read, `publicId` on the public one); the SDK does not
/// model that because every call already knows which event it asked for,
/// and the batch read keys its result by public id.
/// [EventMarketing.fromMap] ignores
/// either key, so a response parses as the block it carries.
///
/// A `PUT` replaces the whole row: a field left `null` here is cleared on
/// the server. Currency is not a field; the server stores INR and never
/// exposes it.
@immutable
class EventMarketing {
  const EventMarketing({
    this.durationText,
    this.scheduleText,
    this.eligibilityText,
    this.eligibilityNote,
    this.registrationDeadlineUtc,
    this.hasOpenSlots,
    this.urgencyText,
    this.contactNumber,
    this.fee,
    this.feeStructure,
    this.packageOffers,
    this.offers,
    this.clubMembership,
    this.facilities,
  });

  factory EventMarketing.fromMap(Map<String, dynamic> map) {
    return EventMarketing(
      durationText: map['durationText'] as String?,
      scheduleText: map['scheduleText'] as String?,
      eligibilityText: map['eligibilityText'] as String?,
      eligibilityNote: map['eligibilityNote'] as String?,
      registrationDeadlineUtc: map['registrationDeadlineUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['registrationDeadlineUtc'] as int,
              isUtc: true,
            )
          : null,
      hasOpenSlots: map['hasOpenSlots'] as bool?,
      urgencyText: map['urgencyText'] as String?,
      contactNumber: map['contactNumber'] as String?,
      fee: map['fee'] as int?,
      feeStructure: map['feeStructure'] != null
          ? (map['feeStructure'] as List)
                .map((e) => FeeItem.fromMap(e as Map<String, dynamic>))
                .toList()
          : null,
      packageOffers: map['packageOffers'] != null
          ? (map['packageOffers'] as List)
                .map((e) => PackageOffer.fromMap(e as Map<String, dynamic>))
                .toList()
          : null,
      offers: map['offers'] != null
          ? (map['offers'] as List)
                .map((e) => PromotionalOffer.fromMap(e as Map<String, dynamic>))
                .toList()
          : null,
      clubMembership: map['clubMembership'] != null
          ? ClubMembership.fromMap(
              map['clubMembership'] as Map<String, dynamic>,
            )
          : null,
      facilities: map['facilities'] != null
          ? (map['facilities'] as List)
                .map((e) => Facility.fromMap(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  factory EventMarketing.fromJson(String source) =>
      EventMarketing.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Free-text duration shown instead of one derived from the timetable.
  final String? durationText;

  /// Free-text schedule shown instead of one derived from the timetable.
  final String? scheduleText;

  /// Free-text eligibility shown instead of the gender / DOB windows.
  final String? eligibilityText;

  /// A line under the eligibility, e.g. `No experience needed`.
  final String? eligibilityNote;

  /// When registration closes; `null` when there is no deadline.
  final DateTime? registrationDeadlineUtc;

  /// Whether places remain; `null` when the club does not say.
  final bool? hasOpenSlots;

  /// A nudge such as `Limited seats!`.
  final String? urgencyText;

  /// A per-event contact number.
  final String? contactNumber;

  /// A single headline fee, whole units.
  final int? fee;

  /// An itemised fee structure. Shown in preference to [fee] when both
  /// are set; see [effectiveFees].
  final List<FeeItem>? feeStructure;

  /// Priced packages.
  final List<PackageOffer>? packageOffers;

  /// Time-boxed promotions.
  final List<PromotionalOffer>? offers;

  /// The club-membership pitch.
  final ClubMembership? clubMembership;

  /// Facilities on offer.
  final List<Facility>? facilities;

  /// The name [effectiveFees] gives the single [fee] when no structure
  /// is set.
  static const singleFeeName = 'Fee';

  /// The fees to show (marketing R9): [feeStructure] when it has any
  /// entries, else one [FeeItem] built from [fee] when that is set, else
  /// none. The server stores both as sent and leaves the precedence to
  /// the client.
  List<FeeItem> get effectiveFees {
    final structure = feeStructure;
    if (structure != null && structure.isNotEmpty) return structure;
    final single = fee;
    if (single != null) {
      return [FeeItem(name: singleFeeName, amount: single)];
    }
    return const [];
  }

  /// Whether [registrationDeadlineUtc] has passed at [now]. Without a
  /// deadline registration never closes on this account.
  bool isRegistrationClosed(DateTime now) {
    final deadline = registrationDeadlineUtc;
    return deadline != null && !now.isBefore(deadline);
  }

  EventMarketing copyWith({
    String? Function()? durationText,
    String? Function()? scheduleText,
    String? Function()? eligibilityText,
    String? Function()? eligibilityNote,
    DateTime? Function()? registrationDeadlineUtc,
    bool? Function()? hasOpenSlots,
    String? Function()? urgencyText,
    String? Function()? contactNumber,
    int? Function()? fee,
    List<FeeItem>? Function()? feeStructure,
    List<PackageOffer>? Function()? packageOffers,
    List<PromotionalOffer>? Function()? offers,
    ClubMembership? Function()? clubMembership,
    List<Facility>? Function()? facilities,
  }) {
    return EventMarketing(
      durationText: durationText != null ? durationText() : this.durationText,
      scheduleText: scheduleText != null ? scheduleText() : this.scheduleText,
      eligibilityText: eligibilityText != null
          ? eligibilityText()
          : this.eligibilityText,
      eligibilityNote: eligibilityNote != null
          ? eligibilityNote()
          : this.eligibilityNote,
      registrationDeadlineUtc: registrationDeadlineUtc != null
          ? registrationDeadlineUtc()
          : this.registrationDeadlineUtc,
      hasOpenSlots: hasOpenSlots != null ? hasOpenSlots() : this.hasOpenSlots,
      urgencyText: urgencyText != null ? urgencyText() : this.urgencyText,
      contactNumber: contactNumber != null
          ? contactNumber()
          : this.contactNumber,
      fee: fee != null ? fee() : this.fee,
      feeStructure: feeStructure != null ? feeStructure() : this.feeStructure,
      packageOffers: packageOffers != null
          ? packageOffers()
          : this.packageOffers,
      offers: offers != null ? offers() : this.offers,
      clubMembership: clubMembership != null
          ? clubMembership()
          : this.clubMembership,
      facilities: facilities != null ? facilities() : this.facilities,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'durationText': durationText,
      'scheduleText': scheduleText,
      'eligibilityText': eligibilityText,
      'eligibilityNote': eligibilityNote,
      'registrationDeadlineUtc':
          registrationDeadlineUtc?.millisecondsSinceEpoch,
      'hasOpenSlots': hasOpenSlots,
      'urgencyText': urgencyText,
      'contactNumber': contactNumber,
      'fee': fee,
      'feeStructure': feeStructure?.map((e) => e.toMap()).toList(),
      'packageOffers': packageOffers?.map((e) => e.toMap()).toList(),
      'offers': offers?.map((e) => e.toMap()).toList(),
      'clubMembership': clubMembership?.toMap(),
      'facilities': facilities?.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'EventMarketing(fee: $fee, feeStructure: $feeStructure, '
      'registrationDeadlineUtc: $registrationDeadlineUtc, '
      'hasOpenSlots: $hasOpenSlots)';

  static const _feeEquality = ListEquality<FeeItem>();
  static const _packageEquality = ListEquality<PackageOffer>();
  static const _offerEquality = ListEquality<PromotionalOffer>();
  static const _facilityEquality = ListEquality<Facility>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventMarketing &&
        other.durationText == durationText &&
        other.scheduleText == scheduleText &&
        other.eligibilityText == eligibilityText &&
        other.eligibilityNote == eligibilityNote &&
        other.registrationDeadlineUtc == registrationDeadlineUtc &&
        other.hasOpenSlots == hasOpenSlots &&
        other.urgencyText == urgencyText &&
        other.contactNumber == contactNumber &&
        other.fee == fee &&
        _feeEquality.equals(other.feeStructure, feeStructure) &&
        _packageEquality.equals(other.packageOffers, packageOffers) &&
        _offerEquality.equals(other.offers, offers) &&
        other.clubMembership == clubMembership &&
        _facilityEquality.equals(other.facilities, facilities);
  }

  @override
  int get hashCode =>
      durationText.hashCode ^
      scheduleText.hashCode ^
      eligibilityText.hashCode ^
      eligibilityNote.hashCode ^
      registrationDeadlineUtc.hashCode ^
      hasOpenSlots.hashCode ^
      urgencyText.hashCode ^
      contactNumber.hashCode ^
      fee.hashCode ^
      _feeEquality.hash(feeStructure) ^
      _packageEquality.hash(packageOffers) ^
      _offerEquality.hash(offers) ^
      clubMembership.hashCode ^
      _facilityEquality.hash(facilities);
}
