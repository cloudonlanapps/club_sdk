import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

/// Issue 66: the error codes of applications (club_server#93), in the
/// shapes `routers/application_errors.py` answers with.
void main() {
  group('Application errors', () {
    test(
      'Issue 78: 422 APPLICATION_INCOMPLETE maps to '
      'ApplicationIncompleteException with the languages each text lacks',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'APPLICATION_INCOMPLETE',
            'message': 'Missing print languages: title (en), declaration (mr)',
            'details': {
              'missing': [
                {
                  'field': 'title',
                  'languages': ['en'],
                },
                {
                  'field': 'declaration',
                  'languages': ['mr'],
                },
              ],
            },
          },
        });
        expect(exc, isA<ApplicationIncompleteException>());
        exc as ApplicationIncompleteException;
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.applicationIncomplete);
        expect(exc.missing, const [
          ApplicationMissingText(field: 'title', languages: ['en']),
          ApplicationMissingText(field: 'declaration', languages: ['mr']),
        ]);
        expect(exc.missing[1].field, 'declaration');
        expect(exc.missing[1].languages, ['mr']);
        expect(exc.fields, ['title', 'declaration']);
        expect(exc.toString(), contains('declaration'));
      },
    );

    test('Issue 78: a text missing in every print language lists them all, '
        'and an entry of the wrong shape is skipped', () {
      final exc = ApplicationIncompleteException.fromDetails('m', const {
        'details': {
          'missing': [
            {
              'field': 'terms[1].heading',
              'languages': ['en', 'mr'],
            },
            'formFooter',
            {'field': 'title'},
          ],
        },
      });
      expect(exc.missing, const [
        ApplicationMissingText(
          field: 'terms[1].heading',
          languages: ['en', 'mr'],
        ),
        ApplicationMissingText(field: 'title', languages: []),
      ]);
    });

    test('Issue 96: a club label lacking a print language is listed as '
        'labels.<key>, and labelKey names it', () {
      final exc = mapHttpError(422, const {
        'detail': {
          'code': 'APPLICATION_INCOMPLETE',
          'message': 'Texts missing a print language: labels.field.full_name',
          'details': {
            'missing': [
              {
                'field': 'labels.field.full_name',
                'languages': ['hi'],
              },
              {
                'field': 'labelOverrides.field.dob',
                'languages': ['hi'],
              },
              {
                'field': 'title',
                'languages': ['hi'],
              },
            ],
          },
        },
      });
      exc as ApplicationIncompleteException;
      expect(
        exc.missing.first,
        const ApplicationMissingText(
          field: 'labels.field.full_name',
          languages: ['hi'],
        ),
      );
      expect(exc.missing.map((m) => m.labelKey), [
        'field.full_name',
        null,
        null,
      ]);
    });

    test(
      'Issue 96: 422 APPLICATION_LANGUAGE_NOT_OFFERED maps to '
      'ApplicationLanguageNotOfferedException with the languages refused',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'APPLICATION_LANGUAGE_NOT_OFFERED',
            'message': 'The club has no such language: hi',
            'details': {
              'languages': ['hi', 7, 'gu'],
            },
          },
        });
        expect(exc, isA<ApplicationLanguageNotOfferedException>());
        exc as ApplicationLanguageNotOfferedException;
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.applicationLanguageNotOffered);
        expect(exc.languages, ['hi', 'gu']);
        expect(exc.message, 'The club has no such language: hi');
        expect(exc.toString(), contains('hi'));
      },
    );

    test('Issue 96: APPLICATION_LANGUAGE_NOT_OFFERED without details still '
        'maps, with no languages', () {
      final exc = mapHttpError(422, const {
        'detail': {'code': 'APPLICATION_LANGUAGE_NOT_OFFERED', 'message': 'm'},
      });
      expect(
        exc,
        isA<ApplicationLanguageNotOfferedException>().having(
          (e) => e.languages,
          'languages',
          isEmpty,
        ),
      );
    });

    test('Issue 96: an unknown label is a 404 ServerException '
        'APPLICATION_LABEL_NOT_FOUND', () {
      final exc = mapHttpError(404, const {
        'detail': {
          'code': 'APPLICATION_LABEL_NOT_FOUND',
          'message': "Label 'field.nowhere' not found",
        },
      });
      expect(exc, isA<ServerException>());
      expect(exc.statusCode, 404);
      expect(exc.code, SdkErrorCode.applicationLabelNotFound);
    });

    test('Issue 96: the codes have their server spelling', () {
      expect(
        SdkErrorCode.applicationLanguageNotOffered,
        'APPLICATION_LANGUAGE_NOT_OFFERED',
      );
      expect(
        SdkErrorCode.applicationLabelNotFound,
        'APPLICATION_LABEL_NOT_FOUND',
      );
    });

    test('Issue 66: APPLICATION_INCOMPLETE without details still maps', () {
      final exc = mapHttpError(422, const {
        'detail': {'code': 'APPLICATION_INCOMPLETE', 'message': 'm'},
      });
      expect(
        exc,
        isA<ApplicationIncompleteException>().having(
          (e) => e.missing,
          'missing',
          isEmpty,
        ),
      );
    });

    test('Issue 78: ApplicationMissingText equality and its map', () {
      const a = ApplicationMissingText(field: 'title', languages: ['en']);
      expect(
        a,
        ApplicationMissingText.fromMap(const {
          'field': 'title',
          'languages': ['en'],
        }),
      );
      expect(
        a.hashCode,
        const ApplicationMissingText(
          field: 'title',
          languages: ['en'],
        ).hashCode,
      );
      expect(
        a,
        isNot(const ApplicationMissingText(field: 'title', languages: ['mr'])),
      );
      expect(a.toMap(), {
        'field': 'title',
        'languages': ['en'],
      });
    });

    test('Issue 66: 422 APPLICATION_DOES_NOT_FIT maps to '
        'ApplicationDoesNotFitException with the overflow', () {
      final exc = mapHttpError(422, const {
        'detail': {
          'code': 'APPLICATION_DOES_NOT_FIT',
          'message': 'The details alone are 140 pt too long for page 1',
          'details': {'overflowPt': 140},
        },
      });
      expect(exc, isA<ApplicationDoesNotFitException>());
      exc as ApplicationDoesNotFitException;
      expect(exc.statusCode, 422);
      expect(exc.code, SdkErrorCode.applicationDoesNotFit);
      expect(exc.overflowPt, 140.0);
    });

    test(
      'Issue 77: 422 APPLICATION_CATEGORY_REQUIRED maps to '
      'ApplicationCategoryRequiredException with the categories that fit',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'APPLICATION_CATEGORY_REQUIRED',
            'message':
                'choose an age category: the member fits categories 0, 2',
            'details': {
              'categories': [0, 2],
            },
          },
        });
        expect(exc, isA<ApplicationCategoryRequiredException>());
        exc as ApplicationCategoryRequiredException;
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.applicationCategoryRequired);
        expect(exc.categories, [0, 2]);
        expect(exc.toString(), contains('[0, 2]'));
      },
    );

    test(
      'Issue 77: 422 APPLICATION_CATEGORY_NOT_FITTING maps to '
      'ApplicationCategoryNotFittingException with the categories that fit',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'APPLICATION_CATEGORY_NOT_FITTING',
            'message': 'the member does not fit age category 1',
            'details': {
              'categories': [0],
            },
          },
        });
        expect(exc, isA<ApplicationCategoryNotFittingException>());
        exc as ApplicationCategoryNotFittingException;
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.applicationCategoryNotFitting);
        expect(exc.categories, [0]);
      },
    );

    test('Issue 77: the category errors without details still map', () {
      for (final code in const [
        'APPLICATION_CATEGORY_REQUIRED',
        'APPLICATION_CATEGORY_NOT_FITTING',
      ]) {
        final exc = mapHttpError(422, {
          'detail': {'code': code, 'message': 'm'},
        });
        expect(
          exc,
          isA<ServerException>().having((e) => e.code, 'code', code),
        );
        expect(
          exc is ApplicationCategoryRequiredException
              ? exc.categories
              : (exc as ApplicationCategoryNotFittingException).categories,
          isEmpty,
        );
      }
    });

    test('Issue 66: 503 APPLICATIONS_DISABLED maps to '
        'ModuleDisabledException', () {
      final exc = mapHttpError(503, const {
        'detail': {'code': 'APPLICATIONS_DISABLED', 'message': 'off'},
      });
      expect(exc, isA<ModuleDisabledException>());
      expect(exc.code, SdkErrorCode.applicationsDisabled);
      expect(
        SdkErrorCode.moduleDisabledCodes,
        contains(SdkErrorCode.applicationsDisabled),
      );
    });

    for (final (status, code) in const [
      (404, 'APPLICATION_NOT_FOUND'),
      (422, 'APPLICATION_NOT_PUBLISHED'),
      (422, 'APPLICATION_NOT_SAVED'),
      (422, 'APPLICATION_NOT_ELIGIBLE'),
      (422, 'APPLICATION_INVALID_REFERENCE'),
      (422, 'INVALID_TRANSITION'),
      (422, 'INVALID_STATE'),
      (422, 'IDENTITY_DOCUMENT_REQUIRED'),
    ]) {
      test('Issue 66: $status $code is a ServerException with its code', () {
        final exc = mapHttpError(status, {
          'detail': {'code': code, 'message': 'm'},
        });
        expect(exc.runtimeType, ServerException);
        expect(exc.statusCode, status);
        expect(exc.code, code);
      });
    }

    test(
      'Issue 92: 422 APPLICATION_UNKNOWN_FACT maps to '
      'ApplicationUnknownFactException with each gap naming no fact',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'APPLICATION_UNKNOWN_FACT',
            'message':
                'Gaps naming no fact of the template: header[1][0] (en): '
                'camp, selections[0] (mr): camp_dates',
            'details': {
              'gaps': [
                {'place': 'header[1][0]', 'language': 'en', 'gap': 'camp'},
                {
                  'place': 'selections[0]',
                  'language': 'mr',
                  'gap': 'camp_dates',
                },
              ],
            },
          },
        });
        expect(exc, isA<ApplicationUnknownFactException>());
        exc as ApplicationUnknownFactException;
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.applicationUnknownFact);
        expect(exc.gaps, const [
          ApplicationUnknownGap(
            place: 'header[1][0]',
            language: 'en',
            gap: 'camp',
          ),
          ApplicationUnknownGap(
            place: 'selections[0]',
            language: 'mr',
            gap: 'camp_dates',
          ),
        ]);
        expect(exc.gaps[1].language, 'mr');
        expect(exc.toString(), contains('camp_dates'));
      },
    );

    test('Issue 92: an unknown-fact gap of the wrong shape is skipped, and '
        'no details read as no gaps', () {
      final exc = ApplicationUnknownFactException.fromDetails('m', const {
        'details': {
          'gaps': [
            {'place': 'title', 'language': 'en', 'gap': 'venue'},
            'title',
            {'place': 'title', 'language': 'en'},
            {'place': 'title', 'gap': 'venue'},
          ],
        },
      });
      expect(exc.gaps, const [
        ApplicationUnknownGap(place: 'title', language: 'en', gap: 'venue'),
      ]);
      final bare = mapHttpError(422, const {
        'detail': {'code': 'APPLICATION_UNKNOWN_FACT', 'message': 'm'},
      });
      expect(
        bare,
        isA<ApplicationUnknownFactException>().having(
          (e) => e.gaps,
          'gaps',
          isEmpty,
        ),
      );
    });

    test('Issue 92: an unknown gap round-trips and compares by value', () {
      const gap = ApplicationUnknownGap(
        place: 'terms[0].body',
        language: 'hi',
        gap: 'fee',
      );
      expect(gap.toMap(), {
        'place': 'terms[0].body',
        'language': 'hi',
        'gap': 'fee',
      });
      expect(ApplicationUnknownGap.fromMap(gap.toMap()), gap);
      expect(ApplicationUnknownGap.fromMap(gap.toMap()).hashCode, gap.hashCode);
      expect(gap.toString(), 'terms[0].body (hi): fee');
    });

    test('Issue 92: 404 APPLICATION_LIBRARY_TEXT_NOT_FOUND is a plain '
        'ServerException', () {
      final exc = mapHttpError(404, const {
        'detail': {
          'code': 'APPLICATION_LIBRARY_TEXT_NOT_FOUND',
          'message': 'Library text 9 not found',
        },
      });
      expect(exc.runtimeType, ServerException);
      expect(exc.statusCode, 404);
      expect(exc.code, SdkErrorCode.applicationLibraryTextNotFound);
    });

    test('Issue 94: APPLICATION_NOT_SAVED has its server spelling', () {
      expect(SdkErrorCode.applicationNotSaved, 'APPLICATION_NOT_SAVED');
    });

    test('Issue 92: the codes have their server spelling', () {
      expect(SdkErrorCode.applicationUnknownFact, 'APPLICATION_UNKNOWN_FACT');
      expect(
        SdkErrorCode.applicationLibraryTextNotFound,
        'APPLICATION_LIBRARY_TEXT_NOT_FOUND',
      );
    });

    test('Issue 66: the codes have their server spelling', () {
      expect(SdkErrorCode.applicationNotFound, 'APPLICATION_NOT_FOUND');
      expect(SdkErrorCode.applicationNotPublished, 'APPLICATION_NOT_PUBLISHED');
      expect(SdkErrorCode.applicationNotEligible, 'APPLICATION_NOT_ELIGIBLE');
      expect(SdkErrorCode.applicationIncomplete, 'APPLICATION_INCOMPLETE');
      expect(
        SdkErrorCode.applicationInvalidReference,
        'APPLICATION_INVALID_REFERENCE',
      );
      expect(SdkErrorCode.applicationDoesNotFit, 'APPLICATION_DOES_NOT_FIT');
      expect(SdkErrorCode.applicationsDisabled, 'APPLICATIONS_DISABLED');
      expect(
        SdkErrorCode.applicationCategoryRequired,
        'APPLICATION_CATEGORY_REQUIRED',
      );
      expect(
        SdkErrorCode.applicationCategoryNotFitting,
        'APPLICATION_CATEGORY_NOT_FITTING',
      );
    });
  });
}
