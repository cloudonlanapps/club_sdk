import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('LocalizedText', () {
    test('Issue 90: fromWire reads a plain string as the default', () {
      final text = LocalizedText.fromWire('Hello');
      expect(text, const LocalizedText('Hello'));
      expect(text!.byLanguage, isEmpty);
    });

    test('Issue 90: fromWire reads the map form with translations', () {
      final text = LocalizedText.fromWire({
        'default': 'Hello',
        'mr': 'नमस्कार',
      });
      expect(text!.defaultValue, 'Hello');
      expect(text.byLanguage, {'mr': 'नमस्कार'});
    });

    test('Issue 90: fromWire skips translations that are not strings', () {
      final text = LocalizedText.fromWire({'default': 'Hello', 'mr': 3});
      expect(text, const LocalizedText('Hello'));
    });

    test('Issue 90: fromWire returns null for a value it cannot read', () {
      expect(LocalizedText.fromWire(null), isNull);
      expect(LocalizedText.fromWire(42), isNull);
      expect(LocalizedText.fromWire({'mr': 'नमस्कार'}), isNull);
      expect(LocalizedText.fromWire({'default': 7}), isNull);
    });

    test('Issue 90: fromMap throws when default is not a string', () {
      expect(
        () => LocalizedText.fromMap(const {'default': null}),
        throwsA(isA<FormatException>()),
      );
    });

    test('Issue 90: toWire writes a plain string with no translations', () {
      expect(const LocalizedText('Hello').toWire(), 'Hello');
    });

    test('Issue 90: toWire writes the map form with translations', () {
      expect(const LocalizedText('Hello', {'mr': 'नमस्कार'}).toWire(), {
        'default': 'Hello',
        'mr': 'नमस्कार',
      });
    });

    test('Issue 90: toWire and fromWire round-trip both forms', () {
      const plain = LocalizedText('Hello');
      const translated = LocalizedText('Hello', {
        'mr': 'नमस्कार',
        'hi': 'नमस्ते',
      });
      expect(LocalizedText.fromWire(plain.toWire()), plain);
      expect(LocalizedText.fromWire(translated.toWire()), translated);
    });

    test('Issue 90: toJson and fromJson round-trip', () {
      const text = LocalizedText('Hello', {'mr': 'नमस्कार'});
      expect(LocalizedText.fromJson(text.toJson()), text);
    });

    test('Issue 90: resolve picks the language, else the default', () {
      const text = LocalizedText('Hello', {'mr': 'नमस्कार'});
      expect(text.resolve('mr'), 'नमस्कार');
      expect(text.resolve('hi'), 'Hello');
    });

    test('Issue 90: copyWith replaces the given fields only', () {
      const text = LocalizedText('Hello', {'mr': 'नमस्कार'});
      expect(
        text.copyWith(defaultValue: 'Hi'),
        const LocalizedText('Hi', {'mr': 'नमस्कार'}),
      );
      expect(text.copyWith(byLanguage: {}), const LocalizedText('Hello'));
    });

    test('Issue 90: equality and hashCode compare translations deeply', () {
      // Two distinct maps, so equality cannot fall back on identity.
      final a = LocalizedText('Hello', Map.of({'mr': 'नमस्कार'}));
      final b = LocalizedText('Hello', Map.of({'mr': 'नमस्कार'}));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const LocalizedText('Hello', {'mr': 'other'})));
    });
  });
}
