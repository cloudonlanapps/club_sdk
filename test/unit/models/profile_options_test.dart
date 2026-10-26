import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 66: the club's profile options, the `profile_options` system
/// preference (club_server#92): positions with a name per language, and
/// languages by name.
void main() {
  const payload = {
    'positions': [
      {
        'value': 'Forward',
        'label': {'en': 'Forward', 'mr': 'फॉरवर्ड'},
      },
      {
        'value': 'Goalie',
        'label': {'en': 'Goalie'},
      },
    ],
    'languages': ['English', 'Marathi'],
  };

  group('ProfilePosition', () {
    test('Issue 66: fromMap reads the value and its label per language', () {
      final p = ProfilePosition.fromMap(const {
        'value': 'Forward',
        'label': {'en': 'Forward', 'mr': 'फॉरवर्ड'},
      });
      expect(p.value, 'Forward');
      expect(p.label, {'en': 'Forward', 'mr': 'फॉरवर्ड'});
    });

    test('Issue 66: labelFor gives the language name, else the value', () {
      const p = ProfilePosition(value: 'Forward', label: {'mr': 'फॉरवर्ड'});
      expect(p.labelFor('mr'), 'फॉरवर्ड');
      expect(p.labelFor('hi'), 'Forward');
    });

    test('Issue 66: round-trip, copyWith, equality', () {
      const p = ProfilePosition(value: 'Forward', label: {'en': 'Forward'});
      expect(ProfilePosition.fromMap(p.toMap()), p);
      expect(ProfilePosition.fromJson(p.toJson()), p);
      expect(p.copyWith(value: 'Defense').value, 'Defense');
      expect(p.copyWith(label: const {'en': 'F'}), isNot(p));
      expect(
        p.hashCode,
        const ProfilePosition(
          value: 'Forward',
          label: {'en': 'Forward'},
        ).hashCode,
      );
    });
  });

  group('ProfileOptions', () {
    test('Issue 66: fromMap reads a realistic server payload', () {
      final o = ProfileOptions.fromMap(payload);
      expect(o.positions.map((p) => p.value), ['Forward', 'Goalie']);
      expect(o.positions.first.label['mr'], 'फॉरवर्ड');
      expect(o.languages, ['English', 'Marathi']);
    });

    test('Issue 66: fromMap reads missing or null lists as empty', () {
      expect(ProfileOptions.fromMap(const {}), const ProfileOptions());
      expect(
        ProfileOptions.fromMap(const {'positions': null, 'languages': null}),
        const ProfileOptions(),
      );
      expect(const ProfileOptions().isEmpty, isTrue);
      expect(ProfileOptions.fromMap(payload).isEmpty, isFalse);
    });

    test('Issue 66: toMap writes the shape the server accepts', () {
      expect(ProfileOptions.fromMap(payload).toMap(), payload);
    });

    test('Issue 66: round-trip, copyWith, equality', () {
      final o = ProfileOptions.fromMap(payload);
      expect(ProfileOptions.fromJson(o.toJson()), o);
      expect(o, ProfileOptions.fromMap(payload));
      expect(o.hashCode, ProfileOptions.fromMap(payload).hashCode);
      expect(o.copyWith(languages: const ['Hindi']).languages, ['Hindi']);
      expect(o.copyWith(languages: const ['Hindi']), isNot(o));
      expect(o.copyWith(positions: const []).positions, isEmpty);
    });

    test('Issue 66: position looks a value up', () {
      final o = ProfileOptions.fromMap(payload);
      expect(o.position('Goalie')?.label['en'], 'Goalie');
      expect(o.position('Defense'), isNull);
    });
  });
}
