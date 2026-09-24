import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('Gender', () {
    test('has four values', () {
      expect(Gender.values.length, 4);
    });

    test('fromName parses camelCase names', () {
      expect(Gender.fromName('male'), Gender.male);
      expect(Gender.fromName('female'), Gender.female);
      expect(Gender.fromName('other'), Gender.other);
      expect(Gender.fromName('preferNotToSay'), Gender.preferNotToSay);
    });

    test('fromName parses snake_case server values', () {
      expect(Gender.fromName('prefer_not_to_say'), Gender.preferNotToSay);
    });

    test('fromName defaults to preferNotToSay for unknown value', () {
      expect(Gender.fromName('unknown'), Gender.preferNotToSay);
    });

    test('serverValue returns snake_case for server', () {
      expect(Gender.male.serverValue, 'male');
      expect(Gender.female.serverValue, 'female');
      expect(Gender.other.serverValue, 'other');
      expect(Gender.preferNotToSay.serverValue, 'prefer_not_to_say');
    });

    test('label returns human-readable display text', () {
      expect(Gender.male.label, 'Male');
      expect(Gender.female.label, 'Female');
      expect(Gender.other.label, 'Other');
      expect(Gender.preferNotToSay.label, 'Prefer not to say');
    });

    test('fromName roundtrips with serverValue', () {
      for (final gender in Gender.values) {
        expect(Gender.fromName(gender.serverValue), gender);
      }
    });
  });
}
