import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Group Model Unit Tests.
void main() {
  group('Group', () {
    final now = DateTime.utc(2024, 6, 15, 10);
    final dobAfter = DateTime.utc(2010);
    final dobBefore = DateTime.utc(2016, 12, 31);
    final testGroup = Group(
      id: 1,
      name: 'Juniors',
      kind: GroupKind.auto,
      description: 'Players under 15',
      dobOnOrAfterUtc: dobAfter,
      dobOnOrBeforeUtc: dobBefore,
      createdAtUtc: now,
    );

    test('two instances with same values are equal', () {
      final sameGroup = Group(
        id: 1,
        name: 'Juniors',
        kind: GroupKind.auto,
        description: 'Players under 15',
        dobOnOrAfterUtc: dobAfter,
        dobOnOrBeforeUtc: dobBefore,
        createdAtUtc: now,
      );

      expect(testGroup, sameGroup);
    });

    test('two instances with different values are not equal', () {
      final differentGroup = Group(
        id: 2,
        name: 'Seniors',
        kind: GroupKind.manual,
        createdAtUtc: now,
      );

      expect(testGroup, isNot(differentGroup));
    });

    test('different kind makes groups unequal', () {
      final manualVariant = testGroup.copyWith(kind: GroupKind.manual);
      expect(testGroup, isNot(manualVariant));
    });

    test('equal instances have same hashCode', () {
      final sameGroup = Group(
        id: 1,
        name: 'Juniors',
        kind: GroupKind.auto,
        description: 'Players under 15',
        dobOnOrAfterUtc: dobAfter,
        dobOnOrBeforeUtc: dobBefore,
        createdAtUtc: now,
      );

      expect(testGroup.hashCode, sameGroup.hashCode);
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final updated = testGroup.copyWith(name: 'Advanced Juniors');
      expect(updated.id, testGroup.id);
      expect(updated.name, 'Advanced Juniors');
      expect(updated.description, testGroup.description);
      expect(updated.kind, GroupKind.auto);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = testGroup.copyWith(name: 'Updated Name');
      expect(updated.id, 1);
      expect(updated.dobOnOrAfterUtc, dobAfter);
      expect(updated.dobOnOrBeforeUtc, dobBefore);
      expect(updated.kind, GroupKind.auto);
    });

    test('copyWith can change kind', () {
      final semi = testGroup.copyWith(kind: GroupKind.semiAuto);
      expect(semi.kind, GroupKind.semiAuto);
      expect(semi.name, testGroup.name);
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final basic = Group(
        id: 1,
        name: 'Basic Group',
        kind: GroupKind.manual,
        createdAtUtc: now,
      );

      final newAfter = DateTime.utc(2008);
      final newBefore = DateTime.utc(2014, 12, 31);
      final updated = basic.copyWith(
        description: () => 'New description',
        dobOnOrAfterUtc: () => newAfter,
        dobOnOrBeforeUtc: () => newBefore,
      );
      expect(updated.description, 'New description');
      expect(updated.dobOnOrAfterUtc, newAfter);
      expect(updated.dobOnOrBeforeUtc, newBefore);
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final cleared = testGroup.copyWith(
        description: () => null,
        dobOnOrAfterUtc: () => null,
        dobOnOrBeforeUtc: () => null,
      );
      expect(cleared.description, isNull);
      expect(cleared.dobOnOrAfterUtc, isNull);
      expect(cleared.dobOnOrBeforeUtc, isNull);
    });

    test('toMap produces correct map structure', () {
      final map = testGroup.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Juniors');
      expect(map['kind'], 'auto');
      expect(map['description'], 'Players under 15');
      expect(map['dobOnOrAfterUtc'], dobAfter.millisecondsSinceEpoch);
      expect(map['dobOnOrBeforeUtc'], dobBefore.millisecondsSinceEpoch);
      expect(map['createdAtUtc'], isA<int>());
    });

    test('fromMap restores equivalent instance', () {
      final map = testGroup.toMap();
      final fromMap = Group.fromMap(map);
      expect(fromMap, testGroup);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = Group.fromMap(testGroup.toMap());
      expect(restored, testGroup);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = testGroup.toJson();
      final fromJson = Group.fromJson(json);
      expect(fromJson, testGroup);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 1,
        'name': 'Basic',
        'kind': 'manual',
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final g = Group.fromMap(map);
      expect(g.description, isNull);
      expect(g.dobOnOrAfterUtc, isNull);
      expect(g.dobOnOrBeforeUtc, isNull);
      expect(g.kind, GroupKind.manual);
    });

    test('fromMap defaults to manual when kind is missing', () {
      final map = {
        'id': 1,
        'name': 'Basic',
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final g = Group.fromMap(map);
      expect(g.kind, GroupKind.manual);
    });

    group('GroupKind serialization', () {
      test('manual round-trips through toMap/fromMap', () {
        final g = Group(
          id: 1,
          name: 'M',
          kind: GroupKind.manual,
          createdAtUtc: now,
        );
        expect(g.toMap()['kind'], 'manual');
        expect(Group.fromMap(g.toMap()).kind, GroupKind.manual);
      });

      test('semi_auto round-trips through toMap/fromMap', () {
        final g = Group(
          id: 1,
          name: 'S',
          kind: GroupKind.semiAuto,
          createdAtUtc: now,
        );
        expect(g.toMap()['kind'], 'semi_auto');
        expect(Group.fromMap(g.toMap()).kind, GroupKind.semiAuto);
      });

      test('auto round-trips through toMap/fromMap', () {
        final g = Group(
          id: 1,
          name: 'A',
          kind: GroupKind.auto,
          createdAtUtc: now,
        );
        expect(g.toMap()['kind'], 'auto');
        expect(Group.fromMap(g.toMap()).kind, GroupKind.auto);
      });

      test('GroupKind.fromServer parses each wire value', () {
        expect(GroupKind.fromServer('manual'), GroupKind.manual);
        expect(GroupKind.fromServer('semi_auto'), GroupKind.semiAuto);
        expect(GroupKind.fromServer('auto'), GroupKind.auto);
      });

      test('GroupKind labels are human-readable', () {
        expect(GroupKind.manual.label, 'Manual');
        expect(GroupKind.semiAuto.label, 'Semi-auto');
        expect(GroupKind.auto.label, 'Auto');
      });
    });

    group('allowsManualMembership', () {
      test('is true for manual groups', () {
        final g = Group(
          id: 1,
          name: 'M',
          kind: GroupKind.manual,
          createdAtUtc: now,
        );
        expect(g.allowsManualMembership, true);
      });

      test('is true for semi-auto groups', () {
        final g = Group(
          id: 1,
          name: 'S',
          kind: GroupKind.semiAuto,
          createdAtUtc: now,
        );
        expect(g.allowsManualMembership, true);
      });

      test('is false for auto groups', () {
        final g = Group(
          id: 1,
          name: 'A',
          kind: GroupKind.auto,
          createdAtUtc: now,
        );
        expect(g.allowsManualMembership, false);
      });
    });

    group('Optional fields', () {
      final deletedAt = DateTime.utc(2024, 7);
      final fullGroup = Group(
        id: 1,
        name: 'Boys U14',
        kind: GroupKind.auto,
        description: 'Boys under 14',
        dobOnOrAfterUtc: dobAfter,
        dobOnOrBeforeUtc: dobBefore,
        createdAtUtc: now,
        gender: Gender.male,
        deletedAtUtc: deletedAt,
      );

      test('construction with gender and deletedAtUtc', () {
        expect(fullGroup.gender, Gender.male);
        expect(fullGroup.deletedAtUtc, deletedAt);
      });

      test('isActive is false when deletedAtUtc is set', () {
        expect(fullGroup.isActive, false);
      });

      test('isActive is true when deletedAtUtc is null', () {
        expect(testGroup.isActive, true);
      });

      test('toMap/fromMap roundtrip preserves all fields', () {
        final restored = Group.fromMap(fullGroup.toMap());
        expect(restored, fullGroup);
        expect(restored.gender, Gender.male);
        expect(restored.dobOnOrAfterUtc, dobAfter);
        expect(restored.dobOnOrBeforeUtc, dobBefore);
        expect(restored.deletedAtUtc, deletedAt);
      });

      test('toJson/fromJson roundtrip preserves all fields', () {
        final restored = Group.fromJson(fullGroup.toJson());
        expect(restored, fullGroup);
      });

      test('fromMap handles null new fields', () {
        final map = {
          'id': 1,
          'name': 'Basic',
          'kind': 'manual',
          'createdAtUtc': now.millisecondsSinceEpoch,
        };
        final g = Group.fromMap(map);
        expect(g.gender, isNull);
        expect(g.dobOnOrAfterUtc, isNull);
        expect(g.dobOnOrBeforeUtc, isNull);
        expect(g.deletedAtUtc, isNull);
      });

      test('equality includes all fields', () {
        final sameGroup = Group(
          id: 1,
          name: 'Boys U14',
          kind: GroupKind.auto,
          description: 'Boys under 14',
          dobOnOrAfterUtc: dobAfter,
          dobOnOrBeforeUtc: dobBefore,
          createdAtUtc: now,
          gender: Gender.male,
          deletedAtUtc: deletedAt,
        );
        expect(fullGroup, sameGroup);
        expect(fullGroup.hashCode, sameGroup.hashCode);
      });

      test('different gender makes groups unequal', () {
        final differentGender = fullGroup.copyWith(
          gender: () => Gender.female,
        );
        expect(fullGroup, isNot(differentGender));
      });

      test('different dobOnOrAfterUtc makes groups unequal', () {
        final differentAfter = fullGroup.copyWith(
          dobOnOrAfterUtc: () => DateTime.utc(2009),
        );
        expect(fullGroup, isNot(differentAfter));
      });

      test('different dobOnOrBeforeUtc makes groups unequal', () {
        final differentBefore = fullGroup.copyWith(
          dobOnOrBeforeUtc: () => DateTime.utc(2017, 12, 31),
        );
        expect(fullGroup, isNot(differentBefore));
      });

      test('copyWith can set new nullable fields', () {
        final updated = testGroup.copyWith(
          gender: () => Gender.female,
          deletedAtUtc: () => deletedAt,
        );
        expect(updated.gender, Gender.female);
        expect(updated.deletedAtUtc, deletedAt);
      });

      test('copyWith can clear new nullable fields to null', () {
        final cleared = fullGroup.copyWith(
          gender: () => null,
          deletedAtUtc: () => null,
        );
        expect(cleared.gender, isNull);
        expect(cleared.deletedAtUtc, isNull);
      });
    });
  });

  group('Issue 6: memberCount and members', () {
    final created = DateTime.utc(2026, 3, 1);
    // GroupResponse: every read except getGroup.
    Map<String, dynamic> listPayload({int memberCount = 3}) => {
      'id': 5,
      'name': 'test_U16',
      'description': null,
      'kind': 'manual',
      'memberCount': memberCount,
      'createdAtUtc': created.millisecondsSinceEpoch,
      'requested': false,
    };
    // GroupDetailResponse: getGroup, with the members inline and no count.
    Map<String, dynamic> detailPayload() => {
      'id': 5,
      'name': 'test_U16',
      'description': null,
      'kind': 'manual',
      'createdAtUtc': created.millisecondsSinceEpoch,
      'members': [
        {'membername': 'amy', 'firstName': 'Amy', 'lastName': null},
        {'membername': 'bo', 'nickname': 'Bo'},
      ],
    };

    test('fromMap reads memberCount from a listing, with no members', () {
      final g = Group.fromMap(listPayload(memberCount: 7));
      expect(g.memberCount, 7);
      expect(g.members, isNull);
    });

    test('fromMap reads the inline members of a detail read, and counts '
        'them', () {
      final g = Group.fromMap(detailPayload());
      expect(g.members, hasLength(2));
      expect(g.members!.first.membername, 'amy');
      expect(g.members!.first.firstName, 'Amy');
      expect(g.members!.last.nickname, 'Bo');
      expect(g.memberCount, 2);
    });

    test('toMap/fromMap round-trip preserves memberCount and members', () {
      final detail = Group.fromMap(detailPayload());
      expect(Group.fromMap(detail.toMap()), detail);
      final listed = Group.fromMap(listPayload());
      final back = Group.fromMap(listed.toMap());
      expect(back, listed);
      expect(back.members, isNull);
    });

    test('memberCount and members take part in equality', () {
      final a = Group.fromMap(listPayload(memberCount: 3));
      expect(a, isNot(Group.fromMap(listPayload(memberCount: 4))));
      final withMembers = a.copyWith(
        members: () => const [GroupMember(membername: 'amy')],
      );
      expect(a, isNot(withMembers));
      expect(
        withMembers.hashCode,
        a
            .copyWith(members: () => const [GroupMember(membername: 'amy')])
            .hashCode,
      );
    });

    test('copyWith sets memberCount and clears members via ValueGetter', () {
      final g = Group.fromMap(detailPayload());
      final copy = g.copyWith(memberCount: 9, members: () => null);
      expect(copy.memberCount, 9);
      expect(copy.members, isNull);
      expect(g.copyWith().members, hasLength(2));
    });
  });
}
