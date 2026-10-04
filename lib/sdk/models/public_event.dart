import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'enums.dart';
import 'event_marketing_basic.dart';
import 'event_session.dart';
import 'gender.dart';
import 'media_ref.dart';
import 'public_profile.dart';
import 'public_venue.dart';

/// An event as the public catalogue projects it (club_server#299, #22).
///
/// Addressed by an opaque [publicId]; the projection carries no integer
/// id, no organizer and no coach usernames. [venueId] is the venue's
/// public id and [venue] its public projection; [coaches] are the
/// consenting coaches (guests included) as public profiles; the cover and
/// gallery are the publicly viewable media only. Only public, live events
/// are published, so there is no visibility or deleted-at here.
@immutable
class PublicEvent {
  const PublicEvent({
    required this.publicId,
    required this.title,
    required this.description,
    required this.type,
    required this.venueId,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.venue,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.rrule,
    this.untilTimeUtc,
    this.sessions,
    this.gender,
    this.dobOnOrAfterUtc,
    this.dobOnOrBeforeUtc,
    this.isFeatured = false,
    this.isPast = false,
    this.cover,
    this.gallery = const [],
    this.coaches = const [],
    this.marketing,
  });

  factory PublicEvent.fromMap(Map<String, dynamic> map) {
    DateTime? optionalTime(String key) => map[key] != null
        ? DateTime.fromMillisecondsSinceEpoch(map[key] as int, isUtc: true)
        : null;
    return PublicEvent(
      publicId: map['publicId'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      type: EventType.values.byName(map['type'] as String),
      venueId: map['venueId'] as String,
      rrule: map['rrule'] as String?,
      startTimeUtc: optionalTime('startTimeUtc')!,
      endTimeUtc: optionalTime('endTimeUtc')!,
      untilTimeUtc: optionalTime('untilTimeUtc'),
      sessions: map['sessions'] != null
          ? (map['sessions'] as List)
                .map((s) => EventSession.fromMap(s as Map<String, dynamic>))
                .toList()
          : null,
      gender: map['gender'] != null
          ? Gender.fromName(map['gender'] as String)
          : null,
      dobOnOrAfterUtc: optionalTime('dobOnOrAfterUtc'),
      dobOnOrBeforeUtc: optionalTime('dobOnOrBeforeUtc'),
      isFeatured: (map['isFeatured'] as bool?) ?? false,
      isPast: (map['isPast'] as bool?) ?? false,
      cover: map['cover'] != null
          ? MediaRef.fromMap(map['cover'] as Map<String, dynamic>)
          : null,
      gallery: map['gallery'] != null
          ? (map['gallery'] as List)
                .map((e) => MediaRef.fromMap(e as Map<String, dynamic>))
                .toList(growable: false)
          : const [],
      venue: PublicVenue.fromMap(map['venue'] as Map<String, dynamic>),
      coaches: map['coaches'] != null
          ? (map['coaches'] as List)
                .map((c) => PublicProfile.fromMap(c as Map<String, dynamic>))
                .toList()
          : const [],
      marketing: map['marketing'] != null
          ? EventMarketingBasic.fromMap(
              map['marketing'] as Map<String, dynamic>,
            )
          : null,
      createdAtUtc: optionalTime('createdAtUtc')!,
      updatedAtUtc: optionalTime('updatedAtUtc')!,
    );
  }

  factory PublicEvent.fromJson(String source) =>
      PublicEvent.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Opaque public identifier (an HMAC of the event id).
  final String publicId;
  final String title;
  final String description;
  final EventType type;

  /// The venue's public id, the same value as `venue.publicId`.
  final String venueId;
  final String? rrule;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;

  /// The current schedule's cutoff, exclusive; `null` while open-ended.
  final DateTime? untilTimeUtc;
  final List<EventSession>? sessions;

  // Eligibility is shown as the event's windows; the reader has no
  // identity to match against.
  final Gender? gender;
  final DateTime? dobOnOrAfterUtc;
  final DateTime? dobOnOrBeforeUtc;
  final bool isFeatured;

  /// Whether every occurrence has finished.
  final bool isPast;

  /// The newest publicly viewable `event_cover` media, or `null`.
  final MediaRef? cover;

  /// The publicly viewable `event_gallery` media in order of attachment.
  ///
  /// A gallery is routinely mixed — a camp's gallery can hold a dozen photos,
  /// a few videos and a PDF — so read each item's
  /// [MediaRef.mimeType] rather than assuming.
  final List<MediaRef> gallery;
  final PublicVenue venue;

  /// The consenting coaches, guests included; a coach who has not
  /// consented is omitted, not named.
  final List<PublicProfile> coaches;

  /// The basic marketing block, `null` when none of its fields is set.
  final EventMarketingBasic? marketing;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  PublicEvent copyWith({
    String? publicId,
    String? title,
    String? description,
    EventType? type,
    String? venueId,
    String? Function()? rrule,
    DateTime? startTimeUtc,
    DateTime? endTimeUtc,
    DateTime? Function()? untilTimeUtc,
    List<EventSession>? Function()? sessions,
    Gender? Function()? gender,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    bool? isFeatured,
    bool? isPast,
    MediaRef? Function()? cover,
    List<MediaRef>? gallery,
    PublicVenue? venue,
    List<PublicProfile>? coaches,
    EventMarketingBasic? Function()? marketing,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) {
    return PublicEvent(
      publicId: publicId ?? this.publicId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      venueId: venueId ?? this.venueId,
      rrule: rrule != null ? rrule() : this.rrule,
      startTimeUtc: startTimeUtc ?? this.startTimeUtc,
      endTimeUtc: endTimeUtc ?? this.endTimeUtc,
      untilTimeUtc: untilTimeUtc != null ? untilTimeUtc() : this.untilTimeUtc,
      sessions: sessions != null ? sessions() : this.sessions,
      gender: gender != null ? gender() : this.gender,
      dobOnOrAfterUtc: dobOnOrAfterUtc != null
          ? dobOnOrAfterUtc()
          : this.dobOnOrAfterUtc,
      dobOnOrBeforeUtc: dobOnOrBeforeUtc != null
          ? dobOnOrBeforeUtc()
          : this.dobOnOrBeforeUtc,
      isFeatured: isFeatured ?? this.isFeatured,
      isPast: isPast ?? this.isPast,
      cover: cover != null ? cover() : this.cover,
      gallery: gallery ?? this.gallery,
      venue: venue ?? this.venue,
      coaches: coaches ?? this.coaches,
      marketing: marketing != null ? marketing() : this.marketing,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'publicId': publicId,
      'title': title,
      'description': description,
      'type': type.name,
      'venueId': venueId,
      'rrule': rrule,
      'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
      'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
      'untilTimeUtc': untilTimeUtc?.millisecondsSinceEpoch,
      'sessions': sessions?.map((s) => s.toMap()).toList(),
      'gender': gender?.serverValue,
      'dobOnOrAfterUtc': dobOnOrAfterUtc?.millisecondsSinceEpoch,
      'dobOnOrBeforeUtc': dobOnOrBeforeUtc?.millisecondsSinceEpoch,
      'isFeatured': isFeatured,
      'isPast': isPast,
      'cover': cover?.toMap(),
      'gallery': gallery.map((m) => m.toMap()).toList(),
      'venue': venue.toMap(),
      'coaches': coaches.map((c) => c.toMap()).toList(),
      'marketing': marketing?.toMap(),
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'PublicEvent(publicId: $publicId, title: $title, type: $type, '
      'venueId: $venueId, isPast: $isPast)';

  static const _mediaListEquality = ListEquality<MediaRef>();
  static const _profileListEquality = ListEquality<PublicProfile>();
  static const _sessionListEquality = ListEquality<EventSession>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicEvent &&
        other.publicId == publicId &&
        other.title == title &&
        other.description == description &&
        other.type == type &&
        other.venueId == venueId &&
        other.rrule == rrule &&
        other.startTimeUtc == startTimeUtc &&
        other.endTimeUtc == endTimeUtc &&
        other.untilTimeUtc == untilTimeUtc &&
        _sessionListEquality.equals(other.sessions, sessions) &&
        other.gender == gender &&
        other.dobOnOrAfterUtc == dobOnOrAfterUtc &&
        other.dobOnOrBeforeUtc == dobOnOrBeforeUtc &&
        other.isFeatured == isFeatured &&
        other.isPast == isPast &&
        other.cover == cover &&
        _mediaListEquality.equals(other.gallery, gallery) &&
        other.venue == venue &&
        _profileListEquality.equals(other.coaches, coaches) &&
        other.marketing == marketing &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc;
  }

  @override
  int get hashCode =>
      publicId.hashCode ^
      title.hashCode ^
      description.hashCode ^
      type.hashCode ^
      venueId.hashCode ^
      rrule.hashCode ^
      startTimeUtc.hashCode ^
      endTimeUtc.hashCode ^
      untilTimeUtc.hashCode ^
      _sessionListEquality.hash(sessions) ^
      gender.hashCode ^
      dobOnOrAfterUtc.hashCode ^
      dobOnOrBeforeUtc.hashCode ^
      isFeatured.hashCode ^
      isPast.hashCode ^
      cover.hashCode ^
      _mediaListEquality.hash(gallery) ^
      venue.hashCode ^
      _profileListEquality.hash(coaches) ^
      marketing.hashCode ^
      createdAtUtc.hashCode ^
      updatedAtUtc.hashCode;
}
