import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'gender.dart';
import 'group_kind.dart';
import 'group_member.dart';

@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAtUtc,
    this.description,
    this.dobOnOrAfterUtc,
    this.dobOnOrBeforeUtc,
    this.gender,
    this.deletedAtUtc,
    this.requested = false,
    this.memberCount = 0,
    this.members,
  });

  factory Group.fromMap(Map<String, dynamic> map) {
    final members = (map['members'] as List<dynamic>?)
        ?.map((m) => GroupMember.fromMap(m as Map<String, dynamic>))
        .toList();
    return Group(
      id: map['id'] as int,
      name: map['name'] as String,
      kind: GroupKind.fromServer(map['kind'] as String? ?? 'manual'),
      description: map['description'] as String?,
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
      createdAtUtc: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtUtc'] as int,
        isUtc: true,
      ),
      gender: map['gender'] != null
          ? Gender.fromName(map['gender'] as String)
          : null,
      deletedAtUtc: map['deletedAtUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['deletedAtUtc'] as int,
              isUtc: true,
            )
          : null,
      requested: map['requested'] as bool? ?? false,
      memberCount: (map['memberCount'] as int?) ?? members?.length ?? 0,
      members: members,
    );
  }

  factory Group.fromJson(String source) =>
      Group.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String name;
  final GroupKind kind;
  final String? description;

  /// Inclusive lower bound on member DOB. Server floors to UTC midnight on
  /// write.
  final DateTime? dobOnOrAfterUtc;

  /// Inclusive upper bound on member DOB. Server floors to UTC midnight on
  /// write.
  final DateTime? dobOnOrBeforeUtc;
  final DateTime createdAtUtc;
  final Gender? gender;
  final DateTime? deletedAtUtc;

  /// True when the current viewer has a pending join request for this
  /// group. Server sets this on entries returned by
  /// `GET /mygroups/by_id/{username}/eligible`; defaults to false
  /// elsewhere (admin/coach group reads do not populate it).
  final bool requested;

  /// True when members can be added/removed by hand
  /// (i.e. manual or semi-auto groups).
  /// How many members the group has (#6). Every read sends it except
  /// `GroupSource.getGroup`, which sends the [members] instead; there it is
  /// their count.
  final int memberCount;

  /// The members, inline. Only `GroupSource.getGroup` sends them (#6); null
  /// from every other read — use `GroupSource.getMembers` for a sorted
  /// list.
  final List<GroupMember>? members;

  bool get allowsManualMembership => kind != GroupKind.auto;
  bool get isActive => deletedAtUtc == null;

  Group copyWith({
    int? id,
    String? name,
    GroupKind? kind,
    String? Function()? description,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    DateTime? createdAtUtc,
    Gender? Function()? gender,
    DateTime? Function()? deletedAtUtc,
    bool? requested,
    int? memberCount,
    List<GroupMember>? Function()? members,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      description: description != null ? description() : this.description,
      dobOnOrAfterUtc: dobOnOrAfterUtc != null
          ? dobOnOrAfterUtc()
          : this.dobOnOrAfterUtc,
      dobOnOrBeforeUtc: dobOnOrBeforeUtc != null
          ? dobOnOrBeforeUtc()
          : this.dobOnOrBeforeUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      gender: gender != null ? gender() : this.gender,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
      requested: requested ?? this.requested,
      memberCount: memberCount ?? this.memberCount,
      members: members != null ? members() : this.members,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'kind': kind.serverValue,
      'description': description,
      'dobOnOrAfterUtc': dobOnOrAfterUtc?.millisecondsSinceEpoch,
      'dobOnOrBeforeUtc': dobOnOrBeforeUtc?.millisecondsSinceEpoch,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'gender': gender?.serverValue,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
      'requested': requested,
      'memberCount': memberCount,
      'members': members?.map((m) => m.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'Group(id: $id, name: $name, kind: $kind, '
        'description: $description, '
        'dobOnOrAfterUtc: $dobOnOrAfterUtc, '
        'dobOnOrBeforeUtc: $dobOnOrBeforeUtc, '
        'gender: $gender, '
        'deletedAtUtc: $deletedAtUtc, '
        'requested: $requested, memberCount: $memberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Group &&
        other.id == id &&
        other.name == name &&
        other.kind == kind &&
        other.description == description &&
        other.dobOnOrAfterUtc == dobOnOrAfterUtc &&
        other.dobOnOrBeforeUtc == dobOnOrBeforeUtc &&
        other.createdAtUtc == createdAtUtc &&
        other.gender == gender &&
        other.deletedAtUtc == deletedAtUtc &&
        other.requested == requested &&
        other.memberCount == memberCount &&
        const ListEquality<GroupMember>().equals(other.members, members);
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      kind.hashCode ^
      description.hashCode ^
      dobOnOrAfterUtc.hashCode ^
      dobOnOrBeforeUtc.hashCode ^
      createdAtUtc.hashCode ^
      gender.hashCode ^
      deletedAtUtc.hashCode ^
      requested.hashCode ^
      memberCount.hashCode ^
      const ListEquality<GroupMember>().hash(members);
}
