import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Result of a bulk member operation on a group.
///
/// The server categorizes each username into one of four lists:
/// - [added]: successfully added to the group
/// - [alreadyMembers]: were already members (no-op)
/// - [notFound]: usernames that don't exist (or are super-admins, which the
///   membership API treats as invisible)
/// - [notEligible]: usernames rejected by a semi-auto group's criteria
@immutable
class BulkMembersResult {
  const BulkMembersResult({
    required this.added,
    required this.alreadyMembers,
    required this.notFound,
    required this.notEligible,
  });

  factory BulkMembersResult.fromMap(Map<String, dynamic> map) {
    return BulkMembersResult(
      added: List<String>.from(map['added'] as List? ?? []),
      alreadyMembers: List<String>.from(map['alreadyMembers'] as List? ?? []),
      notFound: List<String>.from(map['notFound'] as List? ?? []),
      notEligible: List<String>.from(map['notEligible'] as List? ?? []),
    );
  }

  factory BulkMembersResult.fromJson(String source) =>
      BulkMembersResult.fromMap(json.decode(source) as Map<String, dynamic>);

  final List<String> added;
  final List<String> alreadyMembers;
  final List<String> notFound;
  final List<String> notEligible;

  BulkMembersResult copyWith({
    List<String>? added,
    List<String>? alreadyMembers,
    List<String>? notFound,
    List<String>? notEligible,
  }) {
    return BulkMembersResult(
      added: added ?? this.added,
      alreadyMembers: alreadyMembers ?? this.alreadyMembers,
      notFound: notFound ?? this.notFound,
      notEligible: notEligible ?? this.notEligible,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'added': added,
      'alreadyMembers': alreadyMembers,
      'notFound': notFound,
      'notEligible': notEligible,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'BulkMembersResult(added: $added, alreadyMembers: $alreadyMembers, '
        'notFound: $notFound, notEligible: $notEligible)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is BulkMembersResult &&
        listEquals(other.added, added) &&
        listEquals(other.alreadyMembers, alreadyMembers) &&
        listEquals(other.notFound, notFound) &&
        listEquals(other.notEligible, notEligible);
  }

  @override
  int get hashCode =>
      const DeepCollectionEquality().hash(added) ^
      const DeepCollectionEquality().hash(alreadyMembers) ^
      const DeepCollectionEquality().hash(notFound) ^
      const DeepCollectionEquality().hash(notEligible);
}
