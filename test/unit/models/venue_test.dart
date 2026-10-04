import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Venue Model Unit Tests.
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('Venue', () {
    final now = DateTime.utc(2024, 6, 15, 10);
    final venue = Venue(
      id: 1,
      name: 'Main Ground',
      address: '123 Sports Ave',
      description: 'Primary sports facility',
      mapUri: 'https://maps.google.com/venue1',
      isDefault: true,
      isFeatured: true,
      createdAtUtc: now,
      updatedAtUtc: now,
    );

    test('two instances with same values are equal', () {
      final sameVenue = Venue(
        id: 1,
        name: 'Main Ground',
        address: '123 Sports Ave',
        description: 'Primary sports facility',
        mapUri: 'https://maps.google.com/venue1',
        isDefault: true,
        isFeatured: true,
        createdAtUtc: now,
        updatedAtUtc: now,
      );

      expect(venue, sameVenue);
    });

    test('two instances with different values are not equal', () {
      final differentVenue = Venue(
        id: 2,
        name: 'Indoor Court',
        createdAtUtc: now,
        updatedAtUtc: now,
      );

      expect(venue, isNot(differentVenue));
    });

    test('equal instances have same hashCode', () {
      final sameVenue = Venue(
        id: 1,
        name: 'Main Ground',
        address: '123 Sports Ave',
        description: 'Primary sports facility',
        mapUri: 'https://maps.google.com/venue1',
        isDefault: true,
        isFeatured: true,
        createdAtUtc: now,
        updatedAtUtc: now,
      );

      expect(venue.hashCode, sameVenue.hashCode);
    });

    test('copyWith creates new instance with changed non-nullable field', () {
      final updated = venue.copyWith(name: 'New Ground');
      expect(updated.id, venue.id);
      expect(updated.name, 'New Ground');
      expect(updated.address, venue.address);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = venue.copyWith(name: 'Updated Name');
      expect(updated.id, 1);
      expect(updated.isDefault, true);
      expect(updated.isFeatured, true);
    });

    test('copyWith can set nullable field to new value via ValueGetter', () {
      final basic = Venue(
        id: 1,
        name: 'Basic Venue',
        createdAtUtc: now,
        updatedAtUtc: now,
      );

      final updated = basic.copyWith(
        address: () => '456 New Street',
        description: () => 'New description',
      );
      expect(updated.address, '456 New Street');
      expect(updated.description, 'New description');
    });

    test('copyWith can reset nullable field to null via ValueGetter', () {
      final cleared = venue.copyWith(
        address: () => null,
        description: () => null,
        deletedAtUtc: () => null,
      );
      expect(cleared.address, isNull);
      expect(cleared.description, isNull);
      expect(cleared.deletedAtUtc, isNull);
    });

    test('toMap produces correct map structure', () {
      final map = venue.toMap();
      expect(map['id'], 1);
      expect(map['name'], 'Main Ground');
      expect(map['address'], '123 Sports Ave');
      expect(map['isDefault'], true);
      expect(map['isFeatured'], true);
      expect(map['createdAtUtc'], isA<int>());
    });

    test('fromMap restores equivalent instance', () {
      final map = venue.toMap();
      final fromMap = Venue.fromMap(map);
      expect(fromMap, venue);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final venueWithDeleted = venue.copyWith(
        deletedAtUtc: () => now.add(const Duration(days: 30)),
      );
      final restored = Venue.fromMap(venueWithDeleted.toMap());
      expect(restored, venueWithDeleted);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = venue.toJson();
      final fromJson = Venue.fromJson(json);
      expect(fromJson, venue);
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 1,
        'name': 'Basic',
        'createdAtUtc': now.millisecondsSinceEpoch,
        'updatedAtUtc': now.millisecondsSinceEpoch,
      };
      final v = Venue.fromMap(map);
      expect(v.address, isNull);
      expect(v.description, isNull);
      expect(v.isDefault, false);
      expect(v.isFeatured, false);
    });

    test('isActive returns true when not deleted', () {
      expect(venue.isActive, isTrue);
    });

    test('isActive returns false when deletedAtUtc is set', () {
      final deletedVenue = venue.copyWith(
        deletedAtUtc: () => now.add(const Duration(days: 1)),
      );
      expect(deletedVenue.isActive, isFalse);
    });

    test('isDefault defaults to false when not provided', () {
      final map = {
        'id': 1,
        'name': 'Basic',
        'createdAtUtc': now.millisecondsSinceEpoch,
        'updatedAtUtc': now.millisecondsSinceEpoch,
      };
      final v = Venue.fromMap(map);
      expect(v.isDefault, false);
    });

    test('isFeatured defaults to false when not provided', () {
      final map = {
        'id': 1,
        'name': 'Basic',
        'createdAtUtc': now.millisecondsSinceEpoch,
        'updatedAtUtc': now.millisecondsSinceEpoch,
      };
      final v = Venue.fromMap(map);
      expect(v.isFeatured, false);
    });
  });
}
