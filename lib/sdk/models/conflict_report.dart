import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// A pair of overlapping occurrence windows in milliseconds-since-epoch
/// (UTC), as returned by `POST /events/check-conflict`.
@immutable
class OccurrencePair {
  const OccurrencePair({
    required this.targetStartUtc,
    required this.targetEndUtc,
    required this.otherStartUtc,
    required this.otherEndUtc,
  });

  factory OccurrencePair.fromMap(Map<String, dynamic> map) {
    return OccurrencePair(
      targetStartUtc: toDateTime(map['targetStartUtc']),
      targetEndUtc: toDateTime(map['targetEndUtc']),
      otherStartUtc: toDateTime(map['otherStartUtc']),
      otherEndUtc: toDateTime(map['otherEndUtc']),
    );
  }

  final DateTime targetStartUtc;
  final DateTime targetEndUtc;
  final DateTime otherStartUtc;
  final DateTime otherEndUtc;

  Map<String, dynamic> toMap() {
    return {
      'targetStartUtc': targetStartUtc.millisecondsSinceEpoch,
      'targetEndUtc': targetEndUtc.millisecondsSinceEpoch,
      'otherStartUtc': otherStartUtc.millisecondsSinceEpoch,
      'otherEndUtc': otherEndUtc.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'OccurrencePair(target: $targetStartUtc–$targetEndUtc, '
      'other: $otherStartUtc–$otherEndUtc)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OccurrencePair &&
        other.targetStartUtc == targetStartUtc &&
        other.targetEndUtc == targetEndUtc &&
        other.otherStartUtc == otherStartUtc &&
        other.otherEndUtc == otherEndUtc;
  }

  @override
  int get hashCode =>
      targetStartUtc.hashCode ^
      targetEndUtc.hashCode ^
      otherStartUtc.hashCode ^
      otherEndUtc.hashCode;
}

/// One conflicting event, with all of its occurrences that overlap the target.
@immutable
class EventConflictItem {
  const EventConflictItem({
    required this.eventId,
    required this.eventTitle,
    required this.eventType,
    this.occurrences = const [],
  });

  factory EventConflictItem.fromMap(Map<String, dynamic> map) {
    final occurrences = (map['occurrences'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(OccurrencePair.fromMap)
        .toList(growable: false);
    return EventConflictItem(
      eventId: map['eventId'] as int,
      eventTitle: (map['eventTitle'] as String?) ?? '',
      eventType: (map['eventType'] as String?) ?? '',
      occurrences: occurrences,
    );
  }

  final int eventId;
  final String eventTitle;
  final String eventType;
  final List<OccurrencePair> occurrences;

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventType': eventType,
      'occurrences': occurrences.map((p) => p.toMap()).toList(),
    };
  }

  @override
  String toString() =>
      'EventConflictItem(eventId: $eventId, eventTitle: $eventTitle, '
      'eventType: $eventType, occurrences: ${occurrences.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    return other is EventConflictItem &&
        other.eventId == eventId &&
        other.eventTitle == eventTitle &&
        other.eventType == eventType &&
        listEquals(other.occurrences, occurrences);
  }

  @override
  int get hashCode =>
      eventId.hashCode ^
      eventTitle.hashCode ^
      eventType.hashCode ^
      const DeepCollectionEquality().hash(occurrences);
}

/// Conflict-check report returned by `POST /events/check-conflict` for any
/// event type (renamed from `CampConflictReport`, #16). Only a
/// programme-against-programme clash blocks creation with 409; everything
/// else is reported here for the caller to weigh.
///
/// Each list groups conflicts by the actor whose schedule was probed:
/// the target venue, the target organizer, and each target coach.
/// User-level conflicts for enrolled members are tracked separately via
/// `POST /events/by_id/{id}/check-user-conflicts`.
@immutable
class ConflictReport {
  const ConflictReport({
    this.venueConflicts = const [],
    this.organizerConflicts = const [],
    this.coachConflicts = const [],
  });

  factory ConflictReport.fromMap(Map<String, dynamic> map) {
    List<EventConflictItem> parse(String key) {
      return (map[key] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(EventConflictItem.fromMap)
          .toList(growable: false);
    }

    return ConflictReport(
      venueConflicts: parse('venueConflicts'),
      organizerConflicts: parse('organizerConflicts'),
      coachConflicts: parse('coachConflicts'),
    );
  }

  factory ConflictReport.fromJson(String source) =>
      ConflictReport.fromMap(json.decode(source) as Map<String, dynamic>);

  final List<EventConflictItem> venueConflicts;
  final List<EventConflictItem> organizerConflicts;
  final List<EventConflictItem> coachConflicts;

  bool get hasConflict =>
      venueConflicts.isNotEmpty ||
      organizerConflicts.isNotEmpty ||
      coachConflicts.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'venueConflicts': venueConflicts.map((e) => e.toMap()).toList(),
      'organizerConflicts': organizerConflicts.map((e) => e.toMap()).toList(),
      'coachConflicts': coachConflicts.map((e) => e.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'ConflictReport(venueConflicts: ${venueConflicts.length}, '
      'organizerConflicts: ${organizerConflicts.length}, '
      'coachConflicts: ${coachConflicts.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    return other is ConflictReport &&
        listEquals(other.venueConflicts, venueConflicts) &&
        listEquals(other.organizerConflicts, organizerConflicts) &&
        listEquals(other.coachConflicts, coachConflicts);
  }

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(venueConflicts) ^
      const DeepCollectionEquality().hash(organizerConflicts) ^
      const DeepCollectionEquality().hash(coachConflicts);
}

DateTime toDateTime(Object? raw) {
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }
  if (raw is String) {
    return DateTime.parse(raw).toUtc();
  }
  throw FormatException('Expected int (ms epoch) or ISO-8601 string, got $raw');
}
