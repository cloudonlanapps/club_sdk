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

  // The list shape of club_server#133: the club's library texts, the
  // built-in clauses among them (seeded, each with its key).
  const clausesJson = <String, dynamic>{
    'languages': ['en', 'mr'],
    'choices': {
      'on_ice': {'en': 'on-ice', 'mr': 'बर्फावर'},
    },
    'clauses': [
      {
        'id': 1,
        'key': 'rule.matches',
        'kind': 'rule',
        'name': 'Matches',
        'heading': {'en': 'Matches', 'mr': 'सामने'},
        'text': {
          'en': 'Tournament matches will take place from {dates} at {venue}.',
          'mr': '{dates} दरम्यान {venue} येथे स्पर्धेचे सामने होतील.',
        },
        'createdBy': null,
        'createdAtUtc': 1798761600000,
        'updatedAtUtc': 1798761600000,
      },
      {
        'id': 2,
        'key': 'declaration.trial',
        'kind': 'declaration',
        'name': 'Declaration: trial',
        'heading': null,
        'text': {'en': 'I declare …', 'mr': 'मी …'},
        'createdBy': null,
        'createdAtUtc': 1798761600000,
        'updatedAtUtc': 1798848000000,
      },
      {
        'id': 7,
        'key': null,
        'kind': 'selection',
        'name': 'Attend the matches',
        'heading': null,
        'text': {
          'en': 'I will play the matches on {match_dates} at {venue}.',
          'mr': 'मी {match_dates} रोजी {venue} येथे सामने खेळेन.',
        },
        'createdBy': 'test_admin',
        'createdAtUtc': 1798848000000,
        'updatedAtUtc': 1798848000000,
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

  group('ApplicationLabel', () {
    test('Issue 96: reads one label as the PATCH answers it', () {
      final label = ApplicationLabel.fromMap(const {
        'key': 'field.full_name',
        'text': {'en': 'Name', 'mr': 'नाव'},
      });
      expect(label.key, 'field.full_name');
      expect(label.text, const ApplicationText({'en': 'Name', 'mr': 'नाव'}));
      expect(label.toMap(), {
        'key': 'field.full_name',
        'text': {'en': 'Name', 'mr': 'नाव'},
      });
      expect(ApplicationLabel.fromMap(label.toMap()), label);
      expect(
        label.hashCode,
        const ApplicationLabel(
          key: 'field.full_name',
          text: ApplicationText({'en': 'Name', 'mr': 'नाव'}),
        ).hashCode,
      );
    });
  });

  group('ApplicationClauseLibrary', () {
    test("Issue 96: reads the clauses as the club's library texts, in the "
        "club's languages", () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      expect(library.languages, ['en', 'mr']);
      expect(library.choices['on_ice']?['mr'], 'बर्फावर');
      expect(library.clauses, [
        for (final c in clausesJson['clauses'] as List)
          ApplicationLibraryText.fromMap(c as Map<String, dynamic>),
      ]);
      expect(library.clauses.map((c) => c.id), [1, 2, 7]);
    });

    test('Issue 96: a seeded clause has its key, id, name and dates; texts '
        'keep their gaps', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      final matches = library.clauses.first;
      expect(matches.key, 'rule.matches');
      expect(matches.id, 1);
      expect(matches.name, 'Matches');
      expect(matches.kind, ApplicationClauseKind.rule);
      expect(matches.createdBy, isNull);
      expect(matches.createdAtUtc, DateTime.utc(2027));
      expect(matches.heading?.texts['en'], 'Matches');
      expect(matches.text.texts['en'], contains('{venue}'));
    });

    test('Issue 96: clauseWithKey finds a seeded clause by its key', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      final declaration = library.clauseWithKey('declaration.trial')!;
      expect(declaration.id, 2);
      expect(declaration.heading, isNull);
      expect(declaration.updatedAtUtc, DateTime.utc(2027, 1, 2));
      expect(library.clauseWithKey('rule.nowhere'), isNull);
    });

    test('Issue 96: a text the club wrote has no key', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      final club = library.clauses.last;
      expect(club.key, isNull);
      expect(club.id, 7);
      expect(club.name, 'Attend the matches');
      expect(club.createdBy, 'test_admin');
      expect(club.kind, ApplicationClauseKind.selection);
      expect(
        club.text,
        const ApplicationText({
          'en': 'I will play the matches on {match_dates} at {venue}.',
          'mr': 'मी {match_dates} रोजी {venue} येथे सामने खेळेन.',
        }),
      );
    });

    test('Issue 92: clausesOfKind lists one kind, in library order', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      expect(
        library.clausesOfKind(ApplicationClauseKind.rule).map((c) => c.key),
        ['rule.matches'],
      );
      expect(library.clausesOfKind(ApplicationClauseKind.note), isEmpty);
    });

    test('Issue 92: the kinds have their server spelling', () {
      expect(ApplicationClauseKind.values.map((k) => k.wireName), [
        'header',
        'selection',
        'declaration',
        'rule',
        'note',
      ]);
      expect(
        ApplicationClauseKind.fromWire('note'),
        ApplicationClauseKind.note,
      );
      expect(
        () => ApplicationClauseKind.fromWire('footer'),
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
