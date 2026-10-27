import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 66: the extended profile fields of the private profile
/// (club_server#92). Not on the public [UserInfo]. Issue 75: the preferred
/// positions and languages are lists (club_server#106).
void main() {
  final membership = DateTime.utc(2024, 4);
  final base = {
    'username': 'test_member',
    'publicId': 'p1',
    'status': 'active',
    'isSuperAdmin': false,
    'roles': <String>[],
    'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
  };
  final extended = {
    ...base,
    'clubDistrict': 'Pune District',
    'preferredPositions': ['Forward', 'Goalie'],
    'pastExperience': 'Two seasons of roller hockey.',
    'nationality': 'Indian',
    'preferredLanguages': ['Marathi', 'English'],
    'guardian': {'name': 'Asha Rao', 'relation': 'Mother', 'phone': '1'},
    'membershipDateUtc': membership.millisecondsSinceEpoch,
  };

  group('UserPrivate extended profile', () {
    test('Issue 66: fromMap reads every extended field', () {
      final u = UserPrivate.fromMap(extended);
      expect(u.clubDistrict, 'Pune District');
      expect(u.preferredPositions, ['Forward', 'Goalie']);
      expect(u.pastExperience, 'Two seasons of roller hockey.');
      expect(u.nationality, 'Indian');
      expect(u.preferredLanguages, ['Marathi', 'English']);
      expect(
        u.guardian,
        const Guardian(name: 'Asha Rao', relation: 'Mother', phone: '1'),
      );
      expect(u.membershipDateUtc, membership);
      expect(u.membershipDateUtc!.isUtc, isTrue);
    });

    test('Issue 66: fromMap reads absent and null extended fields as null, '
        'and the preferred lists as empty (Issue 75)', () {
      final absent = UserPrivate.fromMap(base);
      final nulls = UserPrivate.fromMap({
        ...base,
        'clubDistrict': null,
        'preferredPositions': null,
        'preferredLanguages': null,
        'guardian': null,
        'membershipDateUtc': null,
      });
      final empty = UserPrivate.fromMap({
        ...base,
        'preferredPositions': const <String>[],
        'preferredLanguages': const <String>[],
      });
      for (final u in [absent, nulls, empty]) {
        expect(u.clubDistrict, isNull);
        expect(u.preferredPositions, isEmpty);
        expect(u.pastExperience, isNull);
        expect(u.nationality, isNull);
        expect(u.preferredLanguages, isEmpty);
        expect(u.guardian, isNull);
        expect(u.membershipDateUtc, isNull);
      }
    });

    test('Issue 66: toMap writes the server keys, and round-trips', () {
      final u = UserPrivate.fromMap(extended);
      final map = u.toMap();
      expect(map['clubDistrict'], 'Pune District');
      expect(map['preferredPositions'], ['Forward', 'Goalie']);
      expect(map['pastExperience'], 'Two seasons of roller hockey.');
      expect(map['nationality'], 'Indian');
      expect(map['preferredLanguages'], ['Marathi', 'English']);
      expect(map['guardian'], {
        'name': 'Asha Rao',
        'relation': 'Mother',
        'phone': '1',
      });
      expect(map['membershipDateUtc'], membership.millisecondsSinceEpoch);
      expect(UserPrivate.fromMap(map), u);
      expect(UserPrivate.fromJson(u.toJson()), u);
    });

    test('Issue 66: copyWith sets and clears each extended field', () {
      final u = UserPrivate.fromMap(extended);
      final cleared = u.copyWith(
        clubDistrict: () => null,
        preferredPositions: const [],
        pastExperience: () => null,
        nationality: () => null,
        preferredLanguages: const [],
        guardian: () => null,
        membershipDateUtc: () => null,
      );
      expect(cleared, UserPrivate.fromMap(base));
      final changed = u.copyWith(
        preferredPositions: const ['Defence'],
        preferredLanguages: const ['Hindi', 'Marathi'],
        nationality: () => 'Nepali',
        guardian: () => const Guardian(name: 'B'),
        membershipDateUtc: () => DateTime.utc(2025),
      );
      expect(changed.preferredPositions, ['Defence']);
      expect(changed.preferredLanguages, ['Hindi', 'Marathi']);
      expect(changed.nationality, 'Nepali');
      expect(changed.guardian, const Guardian(name: 'B'));
      expect(changed.membershipDateUtc, DateTime.utc(2025));
      expect(changed.clubDistrict, 'Pune District');
      expect(u.copyWith(), u);
    });

    test('Issue 66: each extended field takes part in equality', () {
      final u = UserPrivate.fromMap(extended);
      expect(u.hashCode, UserPrivate.fromMap(extended).hashCode);
      expect(u.copyWith(clubDistrict: () => 'x'), isNot(u));
      expect(u.copyWith(preferredPositions: const ['x']), isNot(u));
      expect(
        u.copyWith(preferredPositions: const ['Goalie', 'Forward']),
        isNot(u),
      );
      expect(u.copyWith(pastExperience: () => 'x'), isNot(u));
      expect(u.copyWith(nationality: () => 'x'), isNot(u));
      expect(u.copyWith(preferredLanguages: const ['x']), isNot(u));
      final same = u.copyWith(
        preferredPositions: ['Forward', 'Goalie'],
        preferredLanguages: ['Marathi', 'English'],
      );
      expect(same, u);
      expect(same.hashCode, u.hashCode);
      expect(u.copyWith(guardian: () => const Guardian()), isNot(u));
      expect(
        u.copyWith(membershipDateUtc: () => DateTime.utc(2020)),
        isNot(u),
      );
    });

    test('Issue 66: create passes the extended fields through', () {
      final u = UserPrivate.create(
        publicId: 'p1',
        username: 'test_member',
        status: UserStatus.active,
        isSuperAdmin: false,
        roles: const UserRoles(),
        createdAtUtc: DateTime.utc(2026),
        clubDistrict: 'Pune District',
        preferredPositions: const ['Forward', 'Goalie'],
        pastExperience: 'Two seasons of roller hockey.',
        nationality: 'Indian',
        preferredLanguages: const ['Marathi', 'English'],
        guardian: const Guardian(
          name: 'Asha Rao',
          relation: 'Mother',
          phone: '1',
        ),
        membershipDateUtc: membership,
      );
      expect(u.toMap(), UserPrivate.fromMap(extended).toMap());
    });

    test('Issue 66: the public profile carries no extended field', () {
      final info = UserInfo.fromMap(extended);
      final keys = info.toMap().keys;
      for (final key in const [
        'clubDistrict',
        'preferredPositions',
        'pastExperience',
        'nationality',
        'preferredLanguages',
        'guardian',
        'membershipDateUtc',
      ]) {
        expect(keys, isNot(contains(key)));
      }
    });
  });
}
