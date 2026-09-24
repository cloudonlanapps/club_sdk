import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Address', () {
    group('serialization', () {
      test('fromMap parses all fields', () {
        final map = {
          'addrLine1': '123 Main St',
          'addrLine2': 'Apt 4',
          'city': 'Pune',
          'state': 'Maharashtra',
          'pincode': '411001',
        };

        final address = Address.fromMap(map);

        expect(address.addrLine1, '123 Main St');
        expect(address.addrLine2, 'Apt 4');
        expect(address.city, 'Pune');
        expect(address.state, 'Maharashtra');
        expect(address.pincode, '411001');
      });

      test('fromMap handles null fields', () {
        final address = Address.fromMap(const <String, dynamic>{});

        expect(address.addrLine1, isNull);
        expect(address.addrLine2, isNull);
        expect(address.city, isNull);
        expect(address.state, isNull);
        expect(address.pincode, isNull);
      });

      test('toMap produces correct map', () {
        const address = Address(
          addrLine1: '123 Main St',
          city: 'Pune',
          pincode: '411001',
        );

        final map = address.toMap();

        expect(map['addrLine1'], '123 Main St');
        expect(map['addrLine2'], isNull);
        expect(map['city'], 'Pune');
        expect(map['state'], isNull);
        expect(map['pincode'], '411001');
      });

      test('toMap/fromMap roundtrip preserves all fields', () {
        const address = Address(
          addrLine1: '123 Main St',
          addrLine2: 'Apt 4',
          city: 'Pune',
          state: 'Maharashtra',
          pincode: '411001',
        );

        final restored = Address.fromMap(address.toMap());

        expect(restored, address);
      });

      test('toJson/fromJson roundtrip preserves all fields', () {
        const address = Address(
          addrLine1: '456 Oak Ave',
          city: 'Mumbai',
          state: 'Maharashtra',
          pincode: '400001',
        );

        final restored = Address.fromJson(address.toJson());

        expect(restored, address);
      });
    });

    group('isEmpty', () {
      test('returns true when all fields are null', () {
        const address = Address();
        expect(address.isEmpty, isTrue);
      });

      test('returns true when all fields are empty strings', () {
        const address = Address(
          addrLine1: '',
          addrLine2: '',
          city: '',
          state: '',
          pincode: '',
        );
        expect(address.isEmpty, isTrue);
      });

      test('returns false when any field has a value', () {
        const address = Address(city: 'Pune');
        expect(address.isEmpty, isFalse);
      });
    });

    group('copyWith', () {
      test('creates new instance with changed field', () {
        const address = Address(city: 'Pune', state: 'Maharashtra');

        final updated = address.copyWith(city: () => 'Mumbai');

        expect(updated.city, 'Mumbai');
        expect(updated.state, 'Maharashtra');
      });

      test('can set field to null via ValueGetter', () {
        const address = Address(city: 'Pune', state: 'Maharashtra');

        final updated = address.copyWith(state: () => null);

        expect(updated.city, 'Pune');
        expect(updated.state, isNull);
      });

      test('preserves unchanged fields', () {
        const address = Address(
          addrLine1: '123 Main St',
          city: 'Pune',
          pincode: '411001',
        );

        final updated = address.copyWith(pincode: () => '411002');

        expect(updated.addrLine1, '123 Main St');
        expect(updated.city, 'Pune');
        expect(updated.pincode, '411002');
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        const a1 = Address(city: 'Pune', pincode: '411001');
        const a2 = Address(city: 'Pune', pincode: '411001');

        expect(a1, a2);
      });

      test('two instances with different values are not equal', () {
        const a1 = Address(city: 'Pune');
        const a2 = Address(city: 'Mumbai');

        expect(a1, isNot(a2));
      });

      test('equal instances have same hashCode', () {
        const a1 = Address(city: 'Pune', pincode: '411001');
        const a2 = Address(city: 'Pune', pincode: '411001');

        expect(a1.hashCode, a2.hashCode);
      });
    });

    test('toString returns descriptive string', () {
      const address = Address(city: 'Pune');

      expect(address.toString(), contains('Pune'));
    });
  });
}
