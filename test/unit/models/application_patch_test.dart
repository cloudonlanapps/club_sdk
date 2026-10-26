import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

import '../../utils/application_fixtures.dart';

/// Issue 66: the PATCH body of a draft application (club_server#93, R3):
/// a field sent replaces the stored one, null clears it, a field left out
/// keeps its value.
void main() {
  group('ApplicationPatch', () {
    test('Issue 66: an empty patch sends nothing', () {
      expect(const ApplicationPatch().toMap(), <String, dynamic>{});
      expect(const ApplicationPatch().isEmpty, isTrue);
    });

    test('Issue 66: sends only the fields given, a null getter as null', () {
      final patch = ApplicationPatch(
        title: () => const ApplicationText.custom({'en': 'Season 2027'}),
        subtitle: () => null,
        facts: () => {'fee': const ApplicationFact.amount(500)},
        header: () => const [
          ApplicationHeaderItem.lines([
            ApplicationText.fact('venue'),
            ApplicationText.fact('phone'),
          ]),
        ],
        ageCategories: () => null,
        labelOverrides: () => const {
          'field.nationality': {'en': 'Citizenship'},
        },
      );
      expect(patch.isEmpty, isFalse);
      expect(patch.toMap(), {
        'title': {'en': 'Season 2027'},
        'subtitle': null,
        'facts': {
          'fee': {'type': 'amount', 'value': 500},
        },
        'header': [
          [
            {'fact': 'venue'},
            {'fact': 'phone'},
          ],
        ],
        'ageCategories': null,
        'labelOverrides': {
          'field.nationality': {'en': 'Citizenship'},
        },
      });
    });

    test('Issue 66: every field goes under its server key', () {
      final patch = ApplicationPatch(
        languages: () => null,
        facts: () => null,
        organisation: () => null,
        title: () => null,
        subtitle: () => null,
        header: () => null,
        ageCategories: () => null,
        selections: () => null,
        declaration: () => null,
        formFooter: () => null,
        terms: () => null,
        termsNotes: () => null,
        labelOverrides: () => null,
      );
      expect(patch.toMap().keys, [
        'languages',
        'facts',
        'organisation',
        'title',
        'subtitle',
        'header',
        'ageCategories',
        'selections',
        'declaration',
        'formFooter',
        'terms',
        'termsNotes',
        'labelOverrides',
      ]);
      expect(patch.toMap().values, everyElement(isNull));
    });

    test('Issue 66: ApplicationPatch.replaceAll sends the whole content', () {
      final content = ApplicationContent.fromMap(applicationContentJson());
      expect(
        ApplicationPatch.replaceAll(content).toMap(),
        applicationContentJson(),
      );
    });
  });
}
