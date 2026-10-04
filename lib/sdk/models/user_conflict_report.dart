import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'conflict_report.dart';

/// One user with the events whose occurrences overlap a target camp.
///
/// Mirrors the server's `UserConflictItemResponse`. Each event in
/// [events] uses the same shape as the camp-side report
/// (`EventConflictItem` + nested `OccurrencePair`s).
@immutable
class UserConflictItem {
  const UserConflictItem({
    required this.username,
    this.events = const [],
  });

  factory UserConflictItem.fromMap(Map<String, dynamic> map) {
    final events = (map['events'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(EventConflictItem.fromMap)
        .toList(growable: false);
    return UserConflictItem(
      username: map['username'] as String,
      events: events,
    );
  }

  final String username;
  final List<EventConflictItem> events;

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'events': events.map((e) => e.toMap()).toList(),
    };
  }

  @override
  String toString() =>
      'UserConflictItem(username: $username, events: ${events.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    return other is UserConflictItem &&
        other.username == username &&
        listEquals(other.events, events);
  }

  @override
  int get hashCode =>
      username.hashCode ^ const DeepCollectionEquality().hash(events);
}

/// Response body for `POST /events/by_id/{id}/check-user-conflicts`.
///
/// Sister report to [ConflictReport]: where the event-side report
/// covers venue / organizer / coach overlaps for the target schedule,
/// this one covers per-enrolled-user occurrence overlaps for a fixed
/// camp. The two endpoints are designed to be called together when the
/// host wants a complete pre-flight picture.
@immutable
class UserConflictReport {
  const UserConflictReport({this.userConflicts = const []});

  factory UserConflictReport.fromMap(Map<String, dynamic> map) {
    final items = (map['userConflicts'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(UserConflictItem.fromMap)
        .toList(growable: false);
    return UserConflictReport(userConflicts: items);
  }

  factory UserConflictReport.fromJson(String source) =>
      UserConflictReport.fromMap(json.decode(source) as Map<String, dynamic>);

  final List<UserConflictItem> userConflicts;

  bool get hasConflict => userConflicts.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'userConflicts': userConflicts.map((u) => u.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() =>
      'UserConflictReport(userConflicts: ${userConflicts.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;
    return other is UserConflictReport &&
        listEquals(other.userConflicts, userConflicts);
  }

  @override
  int get hashCode => const DeepCollectionEquality().hash(userConflicts);
}
