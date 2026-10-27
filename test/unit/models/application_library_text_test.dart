import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 92: the club's library of application texts (club_server#126,
/// R7a): a text as the server returns it, a new one, and a change to one.
void main() {
  const created = 1798761600000; // 2027-01-01 UTC, in ms
  const updated = 1798848000000; // 2027-01-02 UTC, in ms

  Map<String, dynamic> ruleJson() => <String, dynamic>{
    'id': 7,
    'kind': 'rule',
    'name': 'Match days',
    'heading': {'en': 'Matches', 'mr': 'सामने'},
    'text': {
      'en': 'Matches are played on {match_dates} at {venue}.',
      'mr': '{match_dates} रोजी {venue} येथे सामने.',
    },
    'createdBy': 'test_i92_admin',
    'createdAtUtc': created,
    'updatedAtUtc': updated,
  };

  group('ApplicationLibraryText', () {
    test('Issue 92: reads a club text with its kind, name, heading and '
        'texts, gaps as written', () {
      final text = ApplicationLibraryText.fromMap(ruleJson());
      expect(text.id, 7);
      expect(text.kind, ApplicationClauseKind.rule);
      expect(text.name, 'Match days');
      expect(
        text.heading,
        const ApplicationText({
          'en': 'Matches',
          'mr': 'सामने',
        }),
      );
      expect(text.text.texts['en'], contains('{match_dates}'));
      expect(text.createdBy, 'test_i92_admin');
      expect(
        text.createdAtUtc,
        DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
      );
      expect(
        text.updatedAtUtc,
        DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true),
      );
    });

    test('Issue 92: a text that is not a rule reads a null heading', () {
      final text = ApplicationLibraryText.fromMap({
        ...ruleJson(),
        'kind': 'note',
        'heading': null,
        'createdBy': null,
      });
      expect(text.kind, ApplicationClauseKind.note);
      expect(text.heading, isNull);
      expect(text.createdBy, isNull);
    });

    test('Issue 92: round-trips, compares by value, and copyWith clears '
        'the heading with a getter', () {
      final text = ApplicationLibraryText.fromMap(ruleJson());
      expect(text.toMap(), ruleJson());
      expect(ApplicationLibraryText.fromMap(text.toMap()), text);
      expect(
        ApplicationLibraryText.fromMap(ruleJson()).hashCode,
        text.hashCode,
      );
      final renamed = text.copyWith(name: 'Matches');
      expect(renamed.name, 'Matches');
      expect(renamed.heading, text.heading);
      expect(renamed, isNot(text));
      expect(text.copyWith(heading: () => null).heading, isNull);
      expect(text.toString(), contains('Match days'));
    });
  });

  group('ApplicationLibraryTextInput', () {
    test('Issue 92: a rule sends its kind, name, heading and text', () {
      const input = ApplicationLibraryTextInput(
        kind: ApplicationClauseKind.rule,
        name: 'Match days',
        heading: ApplicationText({'en': 'Matches'}),
        text: ApplicationText({'en': 'On {match_dates}.'}),
      );
      expect(input.toMap(), {
        'kind': 'rule',
        'name': 'Match days',
        'heading': {'en': 'Matches'},
        'text': {'en': 'On {match_dates}.'},
      });
    });

    test('Issue 92: a text without a heading sends none', () {
      const input = ApplicationLibraryTextInput(
        kind: ApplicationClauseKind.declaration,
        name: 'Parent consent',
        text: ApplicationText({'en': 'I agree.', 'hi': 'मैं सहमत हूँ।'}),
      );
      expect(input.toMap(), {
        'kind': 'declaration',
        'name': 'Parent consent',
        'text': {'en': 'I agree.', 'hi': 'मैं सहमत हूँ।'},
      });
    });
  });

  group('ApplicationLibraryTextPatch', () {
    test('Issue 92: an empty patch sends nothing', () {
      const patch = ApplicationLibraryTextPatch();
      expect(patch.toMap(), isEmpty);
      expect(patch.isEmpty, isTrue);
    });

    test('Issue 92: sends only the fields given', () {
      const patch = ApplicationLibraryTextPatch(
        name: 'Renamed',
        text: ApplicationText({'mr': 'नवीन'}),
      );
      expect(patch.toMap(), {
        'name': 'Renamed',
        'text': {'mr': 'नवीन'},
      });
      expect(patch.isEmpty, isFalse);
    });

    test('Issue 92: a heading getter returning null clears it, one '
        'returning a text replaces it', () {
      expect(ApplicationLibraryTextPatch(heading: () => null).toMap(), {
        'heading': null,
      });
      expect(
        ApplicationLibraryTextPatch(
          kind: ApplicationClauseKind.rule,
          heading: () => const ApplicationText({'en': 'Fee'}),
        ).toMap(),
        {
          'kind': 'rule',
          'heading': {'en': 'Fee'},
        },
      );
    });
  });
}
