import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'enums.dart';
import 'event_session.dart';
import 'gender.dart';
import 'public_profile.dart';

/// An event: a one-off, a programme or a camp.
///
/// An event keeps one id for life (club_server#384, #16). Its timetable is
/// a sequence of `EventSchedule`s; the fields here (`startTimeUtc`,
/// `endTimeUtc`, `rrule`, `venueId`, `organizerName`, `coachNames`,
/// `sessions`) describe the current schedule, and [untilTimeUtc] is that
/// schedule's cutoff: a terminated programme or a cancelled camp keeps
/// running until then. There is no whole-event "cancelled"; an occurrence
/// is cancelled when it carries a cancelled override (which is how a
/// one-off is dropped) or its slot is at or after the cutoff.
@immutable
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.visibility,
    required this.venueId,
    required this.startTimeUtc,
    required this.endTimeUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.organizerName,
    this.coachNames,
    this.coaches,
    this.rrule,
    this.untilTimeUtc,
    this.gender,
    this.dobOnOrAfterUtc,
    this.dobOnOrBeforeUtc,
    this.isFeatured = false,
    this.galleryUris,
    this.shortDescription,
    this.stamp,
    this.highlights,
    this.includes,
    this.sessions,
    this.deletedAtUtc,
    this.version = 1,
    this.updatedBy,
  });

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as int,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      type: EventType.values.byName(map['type'] as String),
      visibility: Visibility.values.byName(map['visibility'] as String),
      venueId: map['venueId'] as int,
      organizerName: map['organizerName'] as String?,
      coachNames: map['coachNames'] != null
          ? List<String>.from(map['coachNames'] as List)
          : null,
      coaches: map['coaches'] != null
          ? (map['coaches'] as List)
                .map((c) => PublicProfile.fromMap(c as Map<String, dynamic>))
                .toList()
          : null,
      rrule: map['rrule'] as String?,
      startTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['startTimeUtc'] as int,
        isUtc: true,
      ),
      endTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['endTimeUtc'] as int,
        isUtc: true,
      ),
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAtUtc'] as int,
        isUtc: true,
      ),
      untilTimeUtc: map['untilTimeUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['untilTimeUtc'] as int,
              isUtc: true,
            )
          : null,
      gender: map['gender'] != null
          ? Gender.fromName(map['gender'] as String)
          : null,
      dobOnOrAfterUtc: map['dobOnOrAfterUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['dobOnOrAfterUtc'] as int,
              isUtc: true,
            )
          : null,
      dobOnOrBeforeUtc: map['dobOnOrBeforeUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['dobOnOrBeforeUtc'] as int,
              isUtc: true,
            )
          : null,
      isFeatured: (map['isFeatured'] as bool?) ?? false,
      galleryUris: map['galleryUris'] != null
          ? List<String>.from(map['galleryUris'] as List)
          : null,
      shortDescription: map['shortDescription'] as String?,
      stamp: map['stamp'] as String?,
      highlights: map['highlights'] != null
          ? List<String>.from(map['highlights'] as List)
          : null,
      includes: map['includes'] != null
          ? List<String>.from(map['includes'] as List)
          : null,
      sessions: map['sessions'] != null
          ? (map['sessions'] as List)
                .map((s) => EventSession.fromMap(s as Map<String, dynamic>))
                .toList()
          : null,
      deletedAtUtc: map['deletedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['deletedAtUtc'] as int,
              isUtc: true,
            )
          : null,
      version: (map['version'] as int?) ?? 1,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  factory Event.fromJson(String source) =>
      Event.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String title;
  final String description;
  final EventType type;
  final Visibility visibility;
  final int venueId;
  final String? organizerName;

  /// @deprecated Use [coaches] instead. Will be removed in future version.
  final List<String>? coachNames;

  /// Full coach profiles with publicId, displayName, bio, etc.
  /// Populated by server - use this instead of coachNames for display.
  final List<PublicProfile>? coaches;
  final String? rrule;
  final DateTime startTimeUtc;
  final DateTime endTimeUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// The current schedule's cutoff, exclusive; `null` while open-ended.
  /// Set by terminate (programme) and cancel (camp), and cleared by
  /// extend-indefinitely and undo-cancel. A dropped one-off keeps no cutoff:
  /// its single occurrence carries a cancelled override instead.
  final DateTime? untilTimeUtc;

  // Structured eligibility — replaces the old free-text `eligibility`/
  // `eligibilityNote` fields. `null` means no constraint on that axis.
  final Gender? gender;
  final DateTime? dobOnOrAfterUtc;
  final DateTime? dobOnOrBeforeUtc;

  // Marketing — collapses the legacy `marketingInfo` aux-info bundle.
  final bool isFeatured;
  final List<String>? galleryUris;

  // The basic marketing block (club_server#409, #22), null when never set;
  // `updateEvent` / `correctionOnEvent` clear a field with null. The public
  // catalogue projects the same four as `PublicEvent.marketing`.
  /// The line under the title on a card (up to 300 characters).
  final String? shortDescription;

  /// Badge text such as `New` (up to 60 characters).
  final String? stamp;

  /// Selling points, up to 20 bullets.
  final List<String>? highlights;

  /// What is included, up to 20 bullets.
  final List<String>? includes;

  // Per-occurrence timetable. `null` means no timetable is recorded;
  // empty list is invalid on submit (server returns INVALID_SESSIONS_EMPTY).
  final List<EventSession>? sessions;

  final DateTime? deletedAtUtc;

  /// Optimistic-locking version (club_server#292, #25). Starts at 1 and is
  /// bumped by every write. The update, correction and split calls send
  /// the version the caller last loaded; a mismatch is a 409
  /// `STALE_VERSION`, surfaced as `StaleVersionException`.
  final int version;

  /// Username of the last writer, or null when unknown.
  final String? updatedBy;

  /// Returns true if the event is active (not soft-deleted).
  bool get isActive => deletedAtUtc == null;

  /// Whether a cutoff has been set on the current schedule.
  bool get isBounded => untilTimeUtc != null;

  /// Derived from [untilTimeUtc] alone (#16).
  ///
  /// - [EventStatus.active]: open-ended (`untilTimeUtc == null`)
  /// - [EventStatus.cancelled]: a cutoff is set. The event still runs and
  ///   accepts enrollment until then; see `isEventSeriesCancelled` for the
  ///   time-aware check.
  EventStatus get status =>
      untilTimeUtc == null ? EventStatus.active : EventStatus.cancelled;

  Event copyWith({
    int? id,
    String? title,
    String? description,
    EventType? type,
    Visibility? visibility,
    int? venueId,
    String? Function()? organizerName,
    List<String>? Function()? coachNames,
    List<PublicProfile>? Function()? coaches,
    String? Function()? rrule,
    DateTime? startTimeUtc,
    DateTime? endTimeUtc,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    DateTime? Function()? untilTimeUtc,
    Gender? Function()? gender,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    bool? isFeatured,
    List<String>? Function()? galleryUris,
    String? Function()? shortDescription,
    String? Function()? stamp,
    List<String>? Function()? highlights,
    List<String>? Function()? includes,
    List<EventSession>? Function()? sessions,
    DateTime? Function()? deletedAtUtc,
    int? version,
    String? Function()? updatedBy,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      visibility: visibility ?? this.visibility,
      venueId: venueId ?? this.venueId,
      organizerName: organizerName != null
          ? organizerName()
          : this.organizerName,
      coachNames: coachNames != null ? coachNames() : this.coachNames,
      coaches: coaches != null ? coaches() : this.coaches,
      rrule: rrule != null ? rrule() : this.rrule,
      startTimeUtc: startTimeUtc ?? this.startTimeUtc,
      endTimeUtc: endTimeUtc ?? this.endTimeUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      untilTimeUtc: untilTimeUtc != null ? untilTimeUtc() : this.untilTimeUtc,
      gender: gender != null ? gender() : this.gender,
      dobOnOrAfterUtc: dobOnOrAfterUtc != null
          ? dobOnOrAfterUtc()
          : this.dobOnOrAfterUtc,
      dobOnOrBeforeUtc: dobOnOrBeforeUtc != null
          ? dobOnOrBeforeUtc()
          : this.dobOnOrBeforeUtc,
      isFeatured: isFeatured ?? this.isFeatured,
      galleryUris: galleryUris != null ? galleryUris() : this.galleryUris,
      shortDescription: shortDescription != null
          ? shortDescription()
          : this.shortDescription,
      stamp: stamp != null ? stamp() : this.stamp,
      highlights: highlights != null ? highlights() : this.highlights,
      includes: includes != null ? includes() : this.includes,
      sessions: sessions != null ? sessions() : this.sessions,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
      version: version ?? this.version,
      updatedBy: updatedBy != null ? updatedBy() : this.updatedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'visibility': visibility.name,
      'venueId': venueId,
      'organizerName': organizerName,
      'coachNames': coachNames,
      'coaches': coaches?.map((c) => c.toMap()).toList(),
      'rrule': rrule,
      'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
      'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'updatedAtUtc': updatedAtUtc.millisecondsSinceEpoch,
      'untilTimeUtc': untilTimeUtc?.millisecondsSinceEpoch,
      'gender': gender?.serverValue,
      'dobOnOrAfterUtc': dobOnOrAfterUtc?.millisecondsSinceEpoch,
      'dobOnOrBeforeUtc': dobOnOrBeforeUtc?.millisecondsSinceEpoch,
      'isFeatured': isFeatured,
      'galleryUris': galleryUris,
      'shortDescription': shortDescription,
      'stamp': stamp,
      'highlights': highlights,
      'includes': includes,
      'sessions': sessions?.map((s) => s.toMap()).toList(),
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
      'version': version,
      'updatedBy': updatedBy,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'Event(id: $id, title: $title, type: $type, '
        'visibility: $visibility, status: $status)';
  }

  static const _stringListEquality = ListEquality<String>();
  static const _profileListEquality = ListEquality<PublicProfile>();
  static const _sessionListEquality = ListEquality<EventSession>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Event &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.type == type &&
        other.visibility == visibility &&
        other.venueId == venueId &&
        other.organizerName == organizerName &&
        _stringListEquality.equals(other.coachNames, coachNames) &&
        _profileListEquality.equals(other.coaches, coaches) &&
        other.rrule == rrule &&
        other.startTimeUtc == startTimeUtc &&
        other.endTimeUtc == endTimeUtc &&
        other.createdAtUtc == createdAtUtc &&
        other.updatedAtUtc == updatedAtUtc &&
        other.untilTimeUtc == untilTimeUtc &&
        other.gender == gender &&
        other.dobOnOrAfterUtc == dobOnOrAfterUtc &&
        other.dobOnOrBeforeUtc == dobOnOrBeforeUtc &&
        other.isFeatured == isFeatured &&
        _stringListEquality.equals(other.galleryUris, galleryUris) &&
        other.shortDescription == shortDescription &&
        other.stamp == stamp &&
        _stringListEquality.equals(other.highlights, highlights) &&
        _stringListEquality.equals(other.includes, includes) &&
        _sessionListEquality.equals(other.sessions, sessions) &&
        other.deletedAtUtc == deletedAtUtc &&
        other.version == version &&
        other.updatedBy == updatedBy;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        description.hashCode ^
        type.hashCode ^
        visibility.hashCode ^
        venueId.hashCode ^
        organizerName.hashCode ^
        _stringListEquality.hash(coachNames) ^
        _profileListEquality.hash(coaches) ^
        rrule.hashCode ^
        startTimeUtc.hashCode ^
        endTimeUtc.hashCode ^
        createdAtUtc.hashCode ^
        updatedAtUtc.hashCode ^
        untilTimeUtc.hashCode ^
        gender.hashCode ^
        dobOnOrAfterUtc.hashCode ^
        dobOnOrBeforeUtc.hashCode ^
        isFeatured.hashCode ^
        _stringListEquality.hash(galleryUris) ^
        shortDescription.hashCode ^
        stamp.hashCode ^
        _stringListEquality.hash(highlights) ^
        _stringListEquality.hash(includes) ^
        _sessionListEquality.hash(sessions) ^
        deletedAtUtc.hashCode ^
        version.hashCode ^
        updatedBy.hashCode;
  }
}
