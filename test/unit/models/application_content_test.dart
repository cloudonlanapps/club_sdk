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
      expect(c.subtitle?.texts['en'], '16–17 November 2026');
      expect(c.declaration?.texts.keys, ['en', 'mr']);
      expect(c.header, hasLength(3));
      expect(c.header[0].isLines, isFalse);
      expect(c.header[1].isLines, isTrue);
      expect(c.header[1].texts.map((t) => t.texts['en']), [
        'Training camp: 16–17 November 2026',
        'Matches: 19–21 November 2026',
      ]);
      expect(c.ageCategories[1].genders, [
        Gender.female,
        Gender.preferNotToSay,
      ]);
      expect(c.ageCategories[1].bornOnOrBeforeUtc, DateTime.utc(2013, 12, 31));
      expect(c.ageCategories[0].bornOnOrBeforeUtc, isNull);
      expect(c.ageCategories[0].genders, isNull);
      expect(c.terms[1].heading.texts['en'], 'Kit');
      expect(c.terms[1].body.texts['mr'], 'स्वतःचे हेल्मेट आणा.');
      expect(c.termsNotes[0].text.texts['en'], 'Follow the rules.');
      expect(c.termsNotes[0].attribution?.texts, {'en': '— Example Club'});
      expect(c.termsNotes[1].attribution, isNull);
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
        title: () => const ApplicationText({'en': 'Season 2027'}),
        subtitle: () => null,
      );
      expect(changed.title?.texts, {'en': 'Season 2027'});
      expect(changed.subtitle, isNull);
      expect(changed.facts, c.facts);
      expect(c.copyWith(), c);
    });
  });

  group('ApplicationText', () {
    test('Issue 76: a text is a language map and writes it back', () {
      expect(const ApplicationText({'en': 'A', 'mr': 'अ'}).toMap(), {
        'en': 'A',
        'mr': 'अ',
      });
      expect(ApplicationText.fromMap(const {'en': 'x'}).texts, {'en': 'x'});
      expect(ApplicationText.fromWire(null), isNull);
      expect(ApplicationText.fromWire('x'), isNull);
    });

    test('Issue 76: fromMap keeps only string entries', () {
      expect(
        ApplicationText.fromMap(const {
          'en': 'x',
          'args': {'a': 'b'},
        }).texts,
        {'en': 'x'},
      );
    });

    test('Issue 66: equality compares the maps', () {
      expect(
        const ApplicationText({'en': 'x'}),
        ApplicationText.fromMap(const {'en': 'x'}),
      );
      expect(
        const ApplicationText({'en': 'x'}).hashCode,
        ApplicationText.fromMap(const {'en': 'x'}).hashCode,
      );
      expect(
        const ApplicationText({'en': 'x'}),
        isNot(const ApplicationText({'en': 'y'})),
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
        {'en': 'City Rink'},
      ]);
      expect(item.isLines, isTrue);
      expect(item.toWire(), [
        {'en': 'City Rink'},
      ]);
      expect(
        ApplicationHeaderItem.fromWire(const {'en': 'City Rink'}).toWire(),
        {'en': 'City Rink'},
      );
      expect(
        item,
        isNot(
          const ApplicationHeaderItem.single(
            ApplicationText({'en': 'City Rink'}),
          ),
        ),
      );
    });

    test('Issue 76: a term is a heading and a body', () {
      const term = ApplicationTerm(
        heading: ApplicationText({'en': 'Kit'}),
        body: ApplicationText({'en': 'Bring a helmet.'}),
      );
      expect(term.toMap(), {
        'heading': {'en': 'Kit'},
        'body': {'en': 'Bring a helmet.'},
      });
      expect(ApplicationTerm.fromMap(term.toMap()), term);
      expect(
        ApplicationTerm.fromMap(term.toMap()).hashCode,
        term.hashCode,
      );
    });

    test('Issue 76: a note is a text with an optional attribution', () {
      const note = ApplicationTermsNote(
        text: ApplicationText({'en': 'Go'}),
        attribution: ApplicationText({'en': '— Coach'}),
      );
      expect(
        const ApplicationTermsNote(text: ApplicationText({'en': 'Go'})).toMap(),
        {
          'text': {'en': 'Go'},
        },
      );
      expect(note.toMap(), {
        'text': {'en': 'Go'},
        'attribution': {'en': '— Coach'},
      });
      expect(ApplicationTermsNote.fromMap(note.toMap()), note);
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
