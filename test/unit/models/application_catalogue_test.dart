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

  const clausesJson = <String, dynamic>{
    'languages': ['en', 'mr', 'hi'],
    'choices': {
      'on_ice': {'en': 'on-ice', 'mr': 'बर्फावर', 'hi': 'बर्फ पर'},
    },
    'clauses': {
      'rule.matches': {
        'kind': 'rule',
        'gaps': {'dates': 'date_range', 'venue': 'name'},
        'heading': {'en': 'Matches', 'mr': 'सामने', 'hi': 'मैच'},
        'text': {
          'en': 'Tournament matches will take place from {dates} at {venue}.',
          'mr': '{dates} दरम्यान {venue} येथे स्पर्धेचे सामने होतील.',
          'hi': '…',
        },
      },
      'declaration.trial': {
        'kind': 'declaration',
        'gaps': <String, dynamic>{},
        'heading': null,
        'text': {'en': 'I declare …', 'mr': 'मी …', 'hi': 'मैं …'},
      },
    },
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
    test('Issue 66: reads each clause with its kind, gaps and texts', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      expect(library.languages, ['en', 'mr', 'hi']);
      expect(library.choices['on_ice']?['mr'], 'बर्फावर');
      final matches = library.clauses['rule.matches']!;
      expect(matches.kind, 'rule');
      expect(matches.gaps, {
        'dates': ApplicationFactType.dateRange,
        'venue': ApplicationFactType.name,
      });
      expect(matches.heading?['en'], 'Matches');
      expect(matches.text['en'], contains('{venue}'));
      final declaration = library.clauses['declaration.trial']!;
      expect(declaration.heading, isNull);
      expect(declaration.gaps, isEmpty);
    });

    test('Issue 66: clausesOfKind lists one kind, in library order', () {
      final library = ApplicationClauseLibrary.fromMap(clausesJson);
      expect(library.clausesOfKind('rule').keys, ['rule.matches']);
      expect(library.clausesOfKind('note'), isEmpty);
    });

    test('Issue 66: round-trips and compares by value', () {
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
