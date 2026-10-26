import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 66: a member's parent or guardian (club_server#92), separate from
/// the emergency contact.
void main() {
  group('Guardian', () {
    test('Issue 66: fromMap reads name, relation and phone', () {
      final g = Guardian.fromMap(const {
        'name': 'Asha Rao',
        'relation': 'Mother',
        'phone': '+919800000000',
      });
      expect(g.name, 'Asha Rao');
      expect(g.relation, 'Mother');
      expect(g.phone, '+919800000000');
    });

    test('Issue 66: fromMap reads a partial guardian, the rest null', () {
      final g = Guardian.fromMap(const {'name': 'Asha Rao'});
      expect(g.name, 'Asha Rao');
      expect(g.relation, isNull);
      expect(g.phone, isNull);
    });

    test('Issue 66: toMap writes the three keys the server accepts', () {
      const g = Guardian(name: 'Asha Rao', phone: '+919800000000');
      expect(g.toMap(), {
        'name': 'Asha Rao',
        'relation': null,
        'phone': '+919800000000',
      });
    });

    test('Issue 66: toMap/fromMap and toJson/fromJson round-trip', () {
      const g = Guardian(name: 'A', relation: 'Father', phone: '1');
      expect(Guardian.fromMap(g.toMap()), g);
      expect(Guardian.fromJson(g.toJson()), g);
    });

    test('Issue 66: copyWith sets and clears through ValueGetter', () {
      const g = Guardian(name: 'A', relation: 'Father', phone: '1');
      expect(g.copyWith(name: () => 'B').name, 'B');
      expect(g.copyWith(phone: () => null).phone, isNull);
      expect(g.copyWith(), g);
      expect(g.copyWith(relation: () => null).name, 'A');
    });

    test('Issue 66: equality and hashCode follow the values', () {
      const a = Guardian(name: 'A', relation: 'Father', phone: '1');
      const b = Guardian(name: 'A', relation: 'Father', phone: '1');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const Guardian(name: 'A', relation: 'Uncle')));
    });

    test('Issue 66: isEmpty is true only when every part is blank', () {
      expect(const Guardian().isEmpty, isTrue);
      expect(const Guardian(name: '', phone: '').isEmpty, isTrue);
      expect(const Guardian(relation: 'Mother').isEmpty, isFalse);
    });
  });
}
