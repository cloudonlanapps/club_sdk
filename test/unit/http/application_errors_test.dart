import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

/// Issue 66: the error codes of applications (club_server#93), in the
/// shapes `routers/application_errors.py` answers with.
void main() {
  group('Application errors', () {
    test('Issue 66: 422 APPLICATION_INCOMPLETE maps to '
        'ApplicationIncompleteException with what is missing', () {
      final exc = mapHttpError(422, const {
        'detail': {
          'code': 'APPLICATION_INCOMPLETE',
          'message': "No 'mr' text for title, formFooter",
          'details': {
            'missing': ['title', 'formFooter'],
            'language': 'mr',
          },
        },
      });
      expect(exc, isA<ApplicationIncompleteException>());
      exc as ApplicationIncompleteException;
      expect(exc.statusCode, 422);
      expect(exc.code, SdkErrorCode.applicationIncomplete);
      expect(exc.missing, ['title', 'formFooter']);
      expect(exc.language, 'mr');
      expect(exc.toString(), contains('formFooter'));
    });

    test('Issue 66: APPLICATION_INCOMPLETE without details still maps', () {
      final exc = mapHttpError(422, const {
        'detail': {'code': 'APPLICATION_INCOMPLETE', 'message': 'm'},
      });
      expect(
        exc,
        isA<ApplicationIncompleteException>()
            .having((e) => e.missing, 'missing', isEmpty)
            .having((e) => e.language, 'language', isNull),
      );
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
    });
  });
}
