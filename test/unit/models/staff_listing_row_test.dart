import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 24: staff-listing curation row (club_server#332).
void main() {
  group('Issue 24: StaffListingRow', () {
    const wire = {
      'username': 'coach_1',
      'displayName': 'Coach One',
      'isPublicProfile': true,
      'position': 2,
      'isGuest': true,
      'isHidden': false,
    };

    test('Issue 24: fromMap reads every field', () {
      final row = StaffListingRow.fromMap(wire);
      expect(row.username, 'coach_1');
      expect(row.displayName, 'Coach One');
      expect(row.isPublicProfile, isTrue);
      expect(row.position, 2);
      expect(row.isGuest, isTrue);
      expect(row.isHidden, isFalse);
    });

    test('Issue 24: an uncurated coach has no position and no flags', () {
      final row = StaffListingRow.fromMap(const {
        'username': 'c',
        'displayName': 'C',
        'isPublicProfile': true,
        'position': null,
      });
      expect(row.position, isNull);
      expect(row.isGuest, isFalse);
      expect(row.isHidden, isFalse);
    });

    test('Issue 24: round-trip, copyWith and equality', () {
      final row = StaffListingRow.fromMap(wire);
      expect(StaffListingRow.fromMap(row.toMap()), row);
      expect(StaffListingRow.fromJson(row.toJson()), row);
      expect(row.toMap(), wire);
      final cleared = row.copyWith(position: () => null, isHidden: true);
      expect(cleared.position, isNull);
      expect(cleared.isHidden, isTrue);
      expect(cleared, isNot(row));
      expect(row.hashCode, StaffListingRow.fromMap(wire).hashCode);
    });
  });

  group('Issue 24: isGuest on profiles', () {
    test('Issue 24: PublicProfile reads and round-trips isGuest', () {
      final p = PublicProfile.fromMap(const {
        'publicId': 'p',
        'displayName': 'G',
        'isGuest': true,
      });
      expect(p.isGuest, isTrue);
      expect(PublicProfile.fromMap(p.toMap()), p);
      expect(p.copyWith(isGuest: false).isGuest, isFalse);
      expect(
        PublicProfile.fromMap(const {
          'publicId': 'p',
          'displayName': 'G',
        }).isGuest,
        isFalse,
      );
    });

    test('Issue 24: UserInfo and UserPrivate carry isGuest', () {
      final info = UserInfo.fromMap(const {
        'username': 'g',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': ['coach'],
        'isGuest': true,
      });
      expect(info.isGuest, isTrue);
      expect(UserInfo.fromMap(info.toMap()), info);
      expect(info.copyWith(isGuest: false), isNot(info));

      final wire = <String, dynamic>{
        'username': 'g',
        'status': 'active',
        'isSuperAdmin': false,
        'roles': ['coach'],
        'isGuest': true,
        'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
      };
      final private = UserPrivate.fromMap(wire);
      expect(private.isGuest, isTrue);
      expect(UserPrivate.fromMap(private.toMap()), private);
    });
  });
}
