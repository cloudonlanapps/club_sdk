import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 66: the label catalogue and the clause library the application
/// editor reads (club_server#93, R7, R8).
void main() {
  const labelsJson = <String, dynamic>{
    'languages': ['en', 'mr', 'hi'],
    'labels': {
      'field.full_name': {
        'en': 'Full name',
        'mr': 'पूर्ण नाव',
        'hi': 'पूरा नाम',
      },
      'gender.male': {'en': 'Male', 'mr': 'पुरुष', 'hi': 'पुरुष'},
    },
  };

  // The list shape of club_server#126: built-in clauses first, then the
  // club's texts, each marked with its source.
  const clausesJson = <String, dynamic>{
    'languages': ['en', 'mr', 'hi'],
    'choices': {
      'on_ice': {'en': 'on-ice', 'mr': 'बर्फावर', 'hi': 'बर्फ पर'},
    },
    'clauses': [
      {
        'source': 'builtin',
        'key': 'rule.matches',
        'id': null,
        'kind': 'rule',
        'name': null,
        'gaps': {'dates': 'date_range', 'venue': 'name'},
        'heading': {'en': 'Matches', 'mr': 'सामने', 'hi': 'मैच'},
        'text': {
          'en': 'Tournament matches will take place from {dates} at {venue}.',
          'mr': '{dates} दरम्यान {venue} येथे स्पर्धेचे सामने होतील.',
          'hi': '…',
        },
      },
      {
        'source': 'builtin',
        'key': 'declaration.trial',
        'id': null,
        'kind': 'declaration',
        'name': null,
        'gaps': <String, dynamic>{},
        'heading': null,
        'text': {'en': 'I declare …', 'mr': 'मी …', 'hi': 'मैं …'},
      },
      {
        'source': 'club',
        'key': null,
        'id': 7,
        'kind': 'selection',
        'name': 'Attend the matches',
        'gaps': null,
        'heading': null,
        'text': {
          'en': 'I will play the matches on {match_dates} at {venue}.',
          'mr': 'मी {match_dates} रोजी {venue} येथे सामने खेळेन.',
        },
      },
    ],
  };

  group('ApplicationLabels', () {
    test('Issue 66: reads the languages and every label', () {
      final labels = ApplicationLabels.fromMap(labelsJson);
      expect(labels.languages, ['en', 'mr', 'hi']);
      expect(labels.labels['field.full_name']?['mr'], 'पूर्ण नाव');
      expect(labels.label('gender.male', 'hi'), 'पुरुष');
      expect(labels.label('gender.male', 'ta'), isNull);
      expect(labels.label('field.none', 'en'), isNull);
    });

    test('Issue 66: round-trips and compares by value', () {
      final labels = ApplicationLabels.fromMap(labelsJson);
      expect(labels.toMap(), labelsJson);
      expect(ApplicationLabels.fromMap(labels.toMap()), labels);
      expect(
        ApplicationLabels.fromMap(labelsJson).hashCode,
        labels.hashCode,
      );
    });
  });

  group('ApplicationClauseLibrary', () {
    test('Issue 92: reads the clauses as a list, built-in first, each with '
        'its source', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      expect(library.languages, ['en', 'mr', 'hi']);
      expect(library.choices['on_ice']?['mr'], 'बर्फावर');
      expect(library.clauses.map((c) => c.source), [
        ApplicationClauseSource.builtin,
        ApplicationClauseSource.builtin,
        ApplicationClauseSource.club,
      ]);
    });

    test(
      'Issue 92: a built-in clause has its key and the fact type of each gap; '
      'texts keep their gaps',
      () {
        final library = ApplicationClauseLibrary.fromMap(clausesJson);
        final matches = library.clauses.first;
        expect(matches.key, 'rule.matches');
        expect(matches.id, isNull);
        expect(matches.name, isNull);
        expect(matches.kind, ApplicationClauseKind.rule);
        expect(matches.gaps, {
          'dates': ApplicationFactType.dateRange,
          'venue': ApplicationFactType.name,
        });
        expect(matches.heading?.texts['en'], 'Matches');
        expect(matches.text.texts['en'], contains('{venue}'));
        final declaration = library.builtinClause('declaration.trial')!;
        expect(declaration.heading, isNull);
        expect(declaration.gaps, isEmpty);
        expect(library.builtinClause('rule.nowhere'), isNull);
      },
    );

    test('Issue 92: a club text has its id and name, no key and no gap '
        'types', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      final club = library.clauses.last;
      expect(club.source, ApplicationClauseSource.club);
      expect(club.id, 7);
      expect(club.name, 'Attend the matches');
      expect(club.key, isNull);
      expect(club.gaps, isNull);
      expect(club.kind, ApplicationClauseKind.selection);
      expect(
        club.text,
        const ApplicationText({
          'en': 'I will play the matches on {match_dates} at {venue}.',
          'mr': 'मी {match_dates} रोजी {venue} येथे सामने खेळेन.',
        }),
      );
      expect(library.clubTexts, [club]);
      expect(library.builtinClause('Attend the matches'), isNull);
    });

    test('Issue 92: clausesOfKind lists one kind, in library order', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      expect(
        library.clausesOfKind(ApplicationClauseKind.rule).map((c) => c.key),
        ['rule.matches'],
      );
      expect(library.clausesOfKind(ApplicationClauseKind.note), isEmpty);
    });

    test('Issue 92: the kinds and sources have their server spelling', () {
      expect(ApplicationClauseKind.values.map((k) => k.wireName), [
        'header',
        'selection',
        'declaration',
        'rule',
        'note',
      ]);
      expect(ApplicationClauseSource.values.map((s) => s.wireName), [
        'builtin',
        'club',
      ]);
      expect(
        ApplicationClauseKind.fromWire('note'),
        ApplicationClauseKind.note,
      );
      expect(
        () => ApplicationClauseKind.fromWire('footer'),
        throwsFormatException,
      );
      expect(
        () => ApplicationClauseSource.fromWire('shared'),
        throwsFormatException,
      );
    });

    test('Issue 92: round-trips and compares by value', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      expect(library.toMap(), clausesJson);
      expect(ApplicationClauseLibrary.fromMap(library.toMap()), library);
      expect(
        ApplicationClauseLibrary.fromMap(clausesJson).hashCode,
        library.hashCode,
      );
    });
  });
}
