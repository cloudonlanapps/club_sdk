import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/application_fixtures.dart';

/// Issue 66: an application template's content and its nested values
/// (club_server#93). Every value reads back in the shape it was sent.
void main() {
  group('ApplicationContent', () {
    test('Issue 66: the prototype content round-trips exactly', () {
      final json = applicationContentJson();
      final content = ApplicationContent.fromMap(json);
      expect(content.toMap(), json);
      expect(ApplicationContent.fromMap(content.toMap()), content);
    });

    test('Issue 66: reads the typed values of the prototype', () {
      final c = ApplicationContent.fromMap(applicationContentJson());
      expect(c.languages, ['en', 'mr']);
      expect(c.organisation?.texts, {
        'en': 'EXAMPLE CLUB',
        'mr': 'उदाहरण क्लब',
      });
      expect(c.subtitle?.kind, ApplicationTextKind.fact);
      expect(c.subtitle?.factName, 'camp');
      expect(c.declaration?.kind, ApplicationTextKind.clause);
      expect(c.declaration?.clauseId, 'declaration.trial');
      expect(c.declaration?.args, isNull);
      expect(c.header, hasLength(3));
      expect(c.header[0].isLines, isFalse);
      expect(c.header[1].isLines, isTrue);
      expect(c.header[1].texts.map((t) => t.clauseId), [
        'header.training_camp',
        'header.matches',
      ]);
      expect(c.header[1].texts.first.args, {'dates': 'camp'});
      expect(c.ageCategories[1].genders, [
        Gender.female,
        Gender.preferNotToSay,
      ]);
      expect(c.ageCategories[1].bornOnOrBeforeUtc, DateTime.utc(2013, 12, 31));
      expect(c.ageCategories[0].bornOnOrBeforeUtc, isNull);
      expect(c.ageCategories[0].genders, isNull);
      expect(c.terms[1].clauseId, 'rule.matches');
      expect(c.terms[2].isClause, isFalse);
      expect(c.terms[2].heading?.texts?['en'], 'Kit');
      expect(c.termsNotes[1].text?.clauseId, 'note.keys_to_success');
      expect(c.termsNotes[1].attribution?.texts, {'en': '— Example Club'});
      expect(c.termsNotes[2].attribution, isNull);
      expect(c.labelOverrides['field.past_experience']?['mr'], 'पूर्व अनुभव');
    });

    test('Issue 66: an empty map is the server defaults', () {
      final c = ApplicationContent.fromMap(const {});
      expect(c, const ApplicationContent());
      expect(c.toMap(), {
        'languages': ['en'],
        'facts': <String, dynamic>{},
        'organisation': null,
        'title': null,
        'subtitle': null,
        'header': <dynamic>[],
        'ageCategories': <dynamic>[],
        'selections': <dynamic>[],
        'declaration': null,
        'formFooter': null,
        'terms': <dynamic>[],
        'termsNotes': <dynamic>[],
        'labelOverrides': <String, dynamic>{},
      });
    });

    test('Issue 66: copyWith replaces one field and clears a text', () {
      final c = ApplicationContent.fromMap(applicationContentJson());
      final changed = c.copyWith(
        title: () => const ApplicationText.custom({'en': 'Season 2027'}),
        subtitle: () => null,
      );
      expect(changed.title?.texts, {'en': 'Season 2027'});
      expect(changed.subtitle, isNull);
      expect(changed.facts, c.facts);
      expect(c.copyWith(), c);
    });
  });

  group('ApplicationText', () {
    test('Issue 66: each kind writes its own shape', () {
      expect(const ApplicationText.custom({'en': 'A', 'mr': 'अ'}).toMap(), {
        'en': 'A',
        'mr': 'अ',
      });
      expect(const ApplicationText.clause('rule.fee').toMap(), {
        'clause': 'rule.fee',
      });
      expect(
        const ApplicationText.clause(
          'rule.fee',
          args: {'amount': 'fee'},
        ).toMap(),
        {
          'clause': 'rule.fee',
          'args': {'amount': 'fee'},
        },
      );
      expect(const ApplicationText.fact('venue').toMap(), {'fact': 'venue'});
    });

    test('Issue 66: fromMap tells the kinds apart', () {
      expect(
        ApplicationText.fromMap(const {'en': 'x'}).kind,
        ApplicationTextKind.custom,
      );
      expect(
        ApplicationText.fromMap(const {'clause': 'c'}).kind,
        ApplicationTextKind.clause,
      );
      expect(
        ApplicationText.fromMap(const {'fact': 'f'}).kind,
        ApplicationTextKind.fact,
      );
    });

    test('Issue 66: equality compares the maps', () {
      expect(
        const ApplicationText.clause('c', args: {'a': 'b'}),
        ApplicationText.fromMap(const {
          'clause': 'c',
          'args': {'a': 'b'},
        }),
      );
      expect(
        const ApplicationText.custom({'en': 'x'}).hashCode,
        ApplicationText.fromMap(const {'en': 'x'}).hashCode,
      );
      expect(
        const ApplicationText.custom({'en': 'x'}),
        isNot(const ApplicationText.custom({'en': 'y'})),
      );
    });
  });

  group('ApplicationFact', () {
    test('Issue 66: each type writes its own shape', () {
      expect(ApplicationFact.date(DateTime.utc(2026, 11, 18)).toMap(), {
        'type': 'date',
        'value': day(2026, 11, 18),
      });
      expect(
        ApplicationFact.dateRange(
          DateTime.utc(2026, 11, 16),
          DateTime.utc(2026, 11, 17),
        ).toMap(),
        {
          'type': 'date_range',
          'from': day(2026, 11, 16),
          'to': day(2026, 11, 17),
        },
      );
      expect(const ApplicationFact.time('6:30').toMap(), {
        'type': 'time',
        'value': '6:30',
      });
      expect(const ApplicationFact.amount(150000).toMap(), {
        'type': 'amount',
        'value': 150000,
      });
      expect(const ApplicationFact.name('Pune').toMap(), {
        'type': 'name',
        'value': 'Pune',
      });
      expect(
        const ApplicationFact.localizedName({
          'en': 'Pune',
          'mr': 'पुणे',
        }).toMap(),
        {
          'type': 'name',
          'value': {'en': 'Pune', 'mr': 'पुणे'},
        },
      );
      expect(const ApplicationFact.choices(['on_ice']).toMap(), {
        'type': 'choices',
        'value': ['on_ice'],
      });
    });

    test('Issue 66: the typed accessors read the value', () {
      final facts = ApplicationContent.fromMap(applicationContentJson()).facts;
      expect(facts['trialDay']?.type, ApplicationFactType.date);
      expect(facts['trialDay']?.dateUtc, DateTime.utc(2026, 11, 18));
      expect(facts['camp']?.fromUtc, DateTime.utc(2026, 11, 16));
      expect(facts['camp']?.toUtc, DateTime.utc(2026, 11, 17));
      expect(facts['camp']?.value, isNull);
      expect(facts['reporting']?.time, '6:30');
      expect(facts['fee']?.amount, 150000);
      expect(facts['phone']?.plainName, '98765 43210');
      expect(facts['phone']?.localizedName, isNull);
      expect(facts['venue']?.localizedName, {
        'en': 'City Rink',
        'mr': 'सिटी रिंक',
      });
      expect(facts['venue']?.plainName, isNull);
      expect(facts['surface']?.choices, ['on_ice', 'inline']);
      expect(facts['fee']?.dateUtc, isNull);
    });

    test('Issue 66: fact type wire values in both directions', () {
      expect(ApplicationFactType.values.map((t) => t.wireName), [
        'date',
        'date_range',
        'time',
        'amount',
        'name',
        'choices',
      ]);
      for (final t in ApplicationFactType.values) {
        expect(ApplicationFactType.fromWire(t.wireName), t);
      }
      expect(
        () => ApplicationFactType.fromWire('colour'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Issue 66: equality compares list and map values', () {
      expect(
        const ApplicationFact.choices(['on_ice', 'inline']),
        ApplicationFact.fromMap(const {
          'type': 'choices',
          'value': ['on_ice', 'inline'],
        }),
      );
      expect(
        const ApplicationFact.localizedName({'en': 'A'}).hashCode,
        ApplicationFact.fromMap(const {
          'type': 'name',
          'value': {'en': 'A'},
        }).hashCode,
      );
      expect(
        const ApplicationFact.amount(1),
        isNot(const ApplicationFact.amount(2)),
      );
    });
  });

  group('ApplicationHeaderItem, ApplicationTerm, ApplicationTermsNote', () {
    test('Issue 66: a header line of one text stays a list', () {
      final item = ApplicationHeaderItem.fromWire(const [
        {'fact': 'venue'},
      ]);
      expect(item.isLines, isTrue);
      expect(item.toWire(), [
        {'fact': 'venue'},
      ]);
      expect(
        ApplicationHeaderItem.fromWire(const {'fact': 'venue'}).toWire(),
        {'fact': 'venue'},
      );
      expect(
        item,
        isNot(
          const ApplicationHeaderItem.single(ApplicationText.fact('venue')),
        ),
      );
    });

    test('Issue 66: a term is a clause or a heading and a body', () {
      expect(const ApplicationTerm.clause('rule.fee').toMap(), {
        'clause': 'rule.fee',
      });
      expect(
        const ApplicationTerm.custom(
          heading: ApplicationText.custom({'en': 'Kit'}),
          body: ApplicationText.clause('rule.fee', args: {'amount': 'fee'}),
        ).toMap(),
        {
          'heading': {'en': 'Kit'},
          'body': {
            'clause': 'rule.fee',
            'args': {'amount': 'fee'},
          },
        },
      );
    });

    test('Issue 66: a note is a clause or a text with an attribution', () {
      expect(const ApplicationTermsNote.clause('note.follow_rules').toMap(), {
        'clause': 'note.follow_rules',
      });
      expect(
        const ApplicationTermsNote.custom(
          text: ApplicationText.custom({'en': 'Go'}),
        ).toMap(),
        {
          'text': {'en': 'Go'},
        },
      );
    });

    test('Issue 66: an age category leaves out what it does not set', () {
      expect(
        const ApplicationAgeCategory(label: {'en': 'Open'}).toMap(),
        {
          'label': {'en': 'Open'},
        },
      );
      final c = ApplicationAgeCategory(
        label: const {'en': 'Under-12'},
        bornOnOrAfterUtc: DateTime.utc(2014),
        genders: const [Gender.male],
      );
      expect(c.toMap(), {
        'label': {'en': 'Under-12'},
        'bornOnOrAfterUtc': day(2014, 1, 1),
        'genders': ['male'],
      });
      expect(ApplicationAgeCategory.fromMap(c.toMap()), c);
    });
  });
}
