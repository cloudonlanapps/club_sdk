import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 76: one library clause filled with facts (club_server#107).
void main() {
  group('ApplicationFilledClause', () {
    const rule = {
      'clause': 'rule.matches',
      'heading': {'en': 'Matches', 'mr': 'सामने'},
      'text': {'en': 'Matches at City Rink.', 'mr': 'सिटी रिंक येथे सामने.'},
    };

    test('Issue 76: a rule reads its heading and text as texts', () {
      final f = ApplicationFilledClause.fromMap(rule);
      expect(f.clause, 'rule.matches');
      expect(
        f.heading,
        const ApplicationText({'en': 'Matches', 'mr': 'सामने'}),
      );
      expect(f.text.texts['en'], 'Matches at City Rink.');
      expect(f.toMap(), rule);
    });

    test('Issue 76: another kind has no heading', () {
      final f = ApplicationFilledClause.fromMap(const {
        'clause': 'declaration.trial',
        'heading': null,
        'text': {'en': 'I agree.'},
      });
      expect(f.heading, isNull);
      expect(f.toMap()['heading'], isNull);
    });

    test('Issue 76: equality, hashCode and copy', () {
      final a = ApplicationFilledClause.fromMap(rule);
      final b = ApplicationFilledClause.fromMap(rule);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(heading: () => null).heading, isNull);
      expect(a.copyWith(), a);
      expect(a, isNot(a.copyWith(clause: 'rule.other')));
      expect(a.toString(), contains('rule.matches'));
    });
  });
}
