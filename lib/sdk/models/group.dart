import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'age.dart';
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
    this.minAge,
    this.maxAge,
    this.strictAge = false,
    this.dobOnOrAfterUtc,
    this.dobOnOrBeforeUtc,
    this.eligibilityReferenceDayUtc,
    this.gender,
    this.deletedAtUtc,
    this.requested = false,
    this.memberCount = 0,
    this.ineligibleMemberCount = 0,
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
      minAge: map['minAge'] != null
          ? Age.fromMap(map['minAge'] as Map<String, dynamic>)
          : null,
      maxAge: map['maxAge'] != null
          ? Age.fromMap(map['maxAge'] as Map<String, dynamic>)
          : null,
      strictAge: (map['strictAge'] as bool?) ?? false,
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
      eligibilityReferenceDayUtc: map['eligibilityReferenceDayUtc'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['eligibilityReferenceDayUtc'] as int,
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
      ineligibleMemberCount: (map['ineligibleMemberCount'] as int?) ?? 0,
      members: members,
    );
  }

  factory Group.fromJson(String source) =>
      Group.fromMap(json.decode(source) as Map<String, dynamic>);

  final int id;
  final String name;
  final GroupKind kind;
  final String? description;

  /// The age band (club_server#16, #7): the youngest and oldest age
  /// admitted, each optional, and whether the check is strict. Strict
  /// admits ages exactly [minAge] to [maxAge] on the reference day; relaxed,
  /// the default, widens each end by a year less a day.
  final Age? minAge;
  final Age? maxAge;
  final bool strictAge;

  /// The window of birth dates the band comes to on
  /// [eligibilityReferenceDayUtc], both ends inclusive; `null` places no
  /// limit on that side. Worked out by the server and read-only: writes take
  /// the ages.
  final DateTime? dobOnOrAfterUtc;
  final DateTime? dobOnOrBeforeUtc;

  /// The calendar day ages are counted on: today, for a group, so the window
  /// moves forward each day. Null from a server that predates the age band.
  final DateTime? eligibilityReferenceDayUtc;
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

  /// How many stored members no longer meet the group's criteria
  /// (club_server#17, #7): semi-auto members whose `GroupMember.eligible` is
  /// false. Nobody is removed automatically.
  final int ineligibleMemberCount;

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
    Age? Function()? minAge,
    Age? Function()? maxAge,
    bool? strictAge,
    DateTime? Function()? dobOnOrAfterUtc,
    DateTime? Function()? dobOnOrBeforeUtc,
    DateTime? Function()? eligibilityReferenceDayUtc,
    DateTime? createdAtUtc,
    Gender? Function()? gender,
    DateTime? Function()? deletedAtUtc,
    bool? requested,
    int? memberCount,
    int? ineligibleMemberCount,
    List<GroupMember>? Function()? members,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      description: description != null ? description() : this.description,
      minAge: minAge != null ? minAge() : this.minAge,
      maxAge: maxAge != null ? maxAge() : this.maxAge,
      strictAge: strictAge ?? this.strictAge,
      dobOnOrAfterUtc: dobOnOrAfterUtc != null
          ? dobOnOrAfterUtc()
          : this.dobOnOrAfterUtc,
      dobOnOrBeforeUtc: dobOnOrBeforeUtc != null
          ? dobOnOrBeforeUtc()
          : this.dobOnOrBeforeUtc,
      eligibilityReferenceDayUtc: eligibilityReferenceDayUtc != null
          ? eligibilityReferenceDayUtc()
          : this.eligibilityReferenceDayUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      gender: gender != null ? gender() : this.gender,
      deletedAtUtc: deletedAtUtc != null ? deletedAtUtc() : this.deletedAtUtc,
      requested: requested ?? this.requested,
      memberCount: memberCount ?? this.memberCount,
      ineligibleMemberCount:
          ineligibleMemberCount ?? this.ineligibleMemberCount,
      members: members != null ? members() : this.members,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'kind': kind.serverValue,
      'description': description,
      'minAge': minAge?.toMap(),
      'maxAge': maxAge?.toMap(),
      'strictAge': strictAge,
      'dobOnOrAfterUtc': dobOnOrAfterUtc?.millisecondsSinceEpoch,
      'dobOnOrBeforeUtc': dobOnOrBeforeUtc?.millisecondsSinceEpoch,
      'eligibilityReferenceDayUtc':
          eligibilityReferenceDayUtc?.millisecondsSinceEpoch,
      'createdAtUtc': createdAtUtc.millisecondsSinceEpoch,
      'gender': gender?.serverValue,
      'deletedAtUtc': deletedAtUtc?.millisecondsSinceEpoch,
      'requested': requested,
      'memberCount': memberCount,
      'ineligibleMemberCount': ineligibleMemberCount,
      'members': members?.map((m) => m.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'Group(id: $id, name: $name, kind: $kind, '
        'description: $description, '
        'minAge: $minAge, maxAge: $maxAge, strictAge: $strictAge, '
        'dobOnOrAfterUtc: $dobOnOrAfterUtc, '
        'dobOnOrBeforeUtc: $dobOnOrBeforeUtc, '
        'gender: $gender, '
        'deletedAtUtc: $deletedAtUtc, '
        'requested: $requested, memberCount: $memberCount, '
        'ineligibleMemberCount: $ineligibleMemberCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Group &&
        other.id == id &&
        other.name == name &&
        other.kind == kind &&
        other.description == description &&
        other.minAge == minAge &&
        other.maxAge == maxAge &&
        other.strictAge == strictAge &&
        other.dobOnOrAfterUtc == dobOnOrAfterUtc &&
        other.dobOnOrBeforeUtc == dobOnOrBeforeUtc &&
        other.eligibilityReferenceDayUtc == eligibilityReferenceDayUtc &&
        other.createdAtUtc == createdAtUtc &&
        other.gender == gender &&
        other.deletedAtUtc == deletedAtUtc &&
        other.requested == requested &&
        other.memberCount == memberCount &&
        other.ineligibleMemberCount == ineligibleMemberCount &&
        const ListEquality<GroupMember>().equals(other.members, members);
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      kind.hashCode ^
      description.hashCode ^
      minAge.hashCode ^
      maxAge.hashCode ^
      strictAge.hashCode ^
      dobOnOrAfterUtc.hashCode ^
      dobOnOrBeforeUtc.hashCode ^
      eligibilityReferenceDayUtc.hashCode ^
      createdAtUtc.hashCode ^
      gender.hashCode ^
      deletedAtUtc.hashCode ^
      requested.hashCode ^
      memberCount.hashCode ^
      ineligibleMemberCount.hashCode ^
      const ListEquality<GroupMember>().hash(members);
}
