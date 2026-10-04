import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'enums.dart';
import 'event.dart';
import 'event_session.dart';
import 'gender.dart';

/// Event data for create/update form submissions.
///
/// Same as [Event] but without DB-generated fields (id, createdAtUtc,
/// updatedAtUtc).
/// Use [eventId] to distinguish create vs edit operations:
/// - `eventId == null`: Create new event
/// - `eventId != null`: Edit existing event
///
/// ## RRULE Format
///
/// The [rrule] field stores a combined RRULE+EXDATE string in RFC 5545 format:
///
/// ```text
/// FREQ=DAILY;COUNT=7
/// EXDATE:20240115T090000Z,20240117T090000Z
/// ```
///
/// **Event Type Rules:**
/// - **OneOff**: `rrule = null` (no recurrence)
/// - **Camp**: `FREQ=DAILY;COUNT=N` with optional EXDATE
/// - **Programme**: `FREQ=WEEKLY;BYDAY=...` with optional UNTIL
@immutable
class EventInput {
  const EventInput({
    required this.title,
    required this.description,
    required this.type,
    required this.visibility,
    required this.venueId,
    required this.startTimeUtc,
    required this.endTimeUtc,
    this.eventId,
    this.organizerName,
    this.rrule,
    this.gender,
    this.dobOnOrAfterUtc,
    this.dobOnOrBeforeUtc,
    this.isFeatured = false,
    this.galleryUris,
    this.sessions,
  });

  factory EventInput.fromMap(Map<String, dynamic> map) {
    return EventInput(
      eventId: map['eventId'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      type: EventType.values.byName(map['type'] as String),
      visibility: Visibility.values.byName(map['visibility'] as String),
      venueId: map['venueId'] as int,
      organizerName: map['organizerName'] as String?,
      rrule: map['rrule'] as String?,
      startTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['startTimeUtc'] as int,
        isUtc: true,
      ),
      endTimeUtc: DateTime.fromMillisecondsSinceEpoch(
        map['endTimeUtc'] as int,
        isUtc: true,
      ),
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
      sessions: map['sessions'] != null
          ? (map['sessions'] as List)
                .map((s) => EventSession.fromMap(s as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  factory EventInput.fromJson(String source) =>
      EventInput.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Create from existing [Event] for edit mode.
  ///
  /// Preserves the event ID so that updates target the correct event.
  factory EventInput.fromEvent(Event event) {
    return EventInput(
      eventId: event.id,
      title: event.title,
      description: event.description,
      type: event.type,
      visibility: event.visibility,
      venueId: event.venueId,
      organizerName: event.organizerName,
      rrule: event.rrule,
      startTimeUtc: event.startTimeUtc,
      endTimeUtc: event.endTimeUtc,
      gender: event.gender,
      dobOnOrAfterUtc: event.dobOnOrAfterUtc,
      dobOnOrBeforeUtc: event.dobOnOrBeforeUtc,
      isFeatured: event.isFeatured,
      galleryUris: event.galleryUris,
      sessions: event.sessions,
    );
  }

  /// Event ID for edit operations. Null for create operations.
  final int? eventId;

  final String title;
  final String description;
  final EventType type;
  final Visibility visibility;
  final int venueId;
  final String? organizerName;

  /// Combined RRULE+EXDATE string (RFC 5545 format).
  ///
  /// Format examples:
  /// - Camp: `FREQ=DAILY;COUNT=7\nEXDATE:20240115T090000Z`
  /// - Programme: `FREQ=WEEKLY;BYDAY=MO,WE,FR;UNTIL=20251231T235959Z`
  /// - OneOff: `null`
  final String? rrule;

  final DateTime startTimeUtc;
  final DateTime endTimeUtc;

  // Structured eligibility — see [Event] for semantics.
  final Gender? gender;
  final DateTime? dobOnOrAfterUtc;
  final DateTime? dobOnOrBeforeUtc;

  final bool isFeatured;
  final List<String>? galleryUris;
  final List<EventSession>? sessions;

  /// True if this is a create operation (new event).
  bool get isCreate => eventId == null;

  /// True if this is an edit operation (existing event).
  bool get isEdit => eventId != null;

  /// Convert to [Event] for persistence or testing.
  ///
  /// Requires an [id] for create operations and [now] for timestamp fields.
  Event toEvent({required int id, required DateTime now}) {
    return Event(
      id: eventId ?? id,
      title: title,
      description: description,
      type: type,
      visibility: visibility,
      venueId: venueId,
      organizerName: organizerName,
      rrule: rrule,
      startTimeUtc: startTimeUtc,
      endTimeUtc: endTimeUtc,
      createdAtUtc: now,
      updatedAtUtc: now,
      gender: gender,
      dobOnOrAfterUtc: dobOnOrAfterUtc,
      dobOnOrBeforeUtc: dobOnOrBeforeUtc,
      isFeatured: isFeatured,
      galleryUris: galleryUris,
      sessions: sessions,
    );
  }

  EventInput copyWith({
    int? Function()? eventId,
    String? title,
    String? description,
    EventType? type,
    Visibility? visibility,
    int? venueId,
    String? Function()? organizerName,
    String? Function()? rrule,
    DateTime? startTimeUtc,
    DateTime? endTimeUtc,
    Gender? Function()? gender,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    bool? isFeatured,
    List<String>? Function()? galleryUris,
    List<EventSession>? Function()? sessions,
  }) {
    return EventInput(
      eventId: eventId != null ? eventId() : this.eventId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      visibility: visibility ?? this.visibility,
      venueId: venueId ?? this.venueId,
      organizerName: organizerName != null
          ? organizerName()
          : this.organizerName,
      rrule: rrule != null ? rrule() : this.rrule,
      startTimeUtc: startTimeUtc ?? this.startTimeUtc,
      endTimeUtc: endTimeUtc ?? this.endTimeUtc,
      gender: gender != null ? gender() : this.gender,
      dobOnOrAfterUtc: dobOnOrAfterUtc != null
          ? dobOnOrAfterUtc()
          : this.dobOnOrAfterUtc,
      dobOnOrBeforeUtc: dobOnOrBeforeUtc != null
          ? dobOnOrBeforeUtc()
          : this.dobOnOrBeforeUtc,
      isFeatured: isFeatured ?? this.isFeatured,
      galleryUris: galleryUris != null ? galleryUris() : this.galleryUris,
      sessions: sessions != null ? sessions() : this.sessions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'title': title,
      'description': description,
      'type': type.name,
      'visibility': visibility.name,
      'venueId': venueId,
      'organizerName': organizerName,
      'rrule': rrule,
      'startTimeUtc': startTimeUtc.millisecondsSinceEpoch,
      'endTimeUtc': endTimeUtc.millisecondsSinceEpoch,
      'gender': gender?.serverValue,
      'dobOnOrAfterUtc': dobOnOrAfterUtc?.millisecondsSinceEpoch,
      'dobOnOrBeforeUtc': dobOnOrBeforeUtc?.millisecondsSinceEpoch,
      'isFeatured': isFeatured,
      'galleryUris': galleryUris,
      'sessions': sessions?.map((s) => s.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'EventInput(eventId: $eventId, title: $title, type: $type, '
        'isCreate: $isCreate)';
  }

  static const _stringListEquality = ListEquality<String>();
  static const _sessionListEquality = ListEquality<EventSession>();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EventInput &&
        other.eventId == eventId &&
        other.title == title &&
        other.description == description &&
        other.type == type &&
        other.visibility == visibility &&
        other.venueId == venueId &&
        other.organizerName == organizerName &&
        other.rrule == rrule &&
        other.startTimeUtc == startTimeUtc &&
        other.endTimeUtc == endTimeUtc &&
        other.gender == gender &&
        other.dobOnOrAfterUtc == dobOnOrAfterUtc &&
        other.dobOnOrBeforeUtc == dobOnOrBeforeUtc &&
        other.isFeatured == isFeatured &&
        _stringListEquality.equals(other.galleryUris, galleryUris) &&
        _sessionListEquality.equals(other.sessions, sessions);
  }

  @override
  int get hashCode {
    return eventId.hashCode ^
        title.hashCode ^
        description.hashCode ^
        type.hashCode ^
        visibility.hashCode ^
        venueId.hashCode ^
        organizerName.hashCode ^
        rrule.hashCode ^
        startTimeUtc.hashCode ^
        endTimeUtc.hashCode ^
        gender.hashCode ^
        dobOnOrAfterUtc.hashCode ^
        dobOnOrBeforeUtc.hashCode ^
        isFeatured.hashCode ^
        _stringListEquality.hash(galleryUris) ^
        _sessionListEquality.hash(sessions);
  }
}
