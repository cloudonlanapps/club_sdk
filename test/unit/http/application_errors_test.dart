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
