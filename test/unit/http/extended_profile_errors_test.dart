import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

/// Issue 66: the error codes of the extended profile (club_server#92).
void main() {
  group('Extended profile errors', () {
    test('Issue 66: 422 INVALID_PROFILE_OPTION maps to '
        'InvalidProfileOptionException naming the field and value', () {
      final exc = mapHttpError(422, const {
        'detail': {
          'code': 'INVALID_PROFILE_OPTION',
          'message': "'Striker' is not one of the club's options",
          'field': 'preferredPosition',
          'value': 'Striker',
        },
      });
      expect(exc, isA<InvalidProfileOptionException>());
      exc as InvalidProfileOptionException;
      expect(exc.statusCode, 422);
      expect(exc.code, SdkErrorCode.invalidProfileOption);
      expect(exc.field, 'preferredPosition');
      expect(exc.value, 'Striker');
      expect(exc.details, {'field': 'preferredPosition', 'value': 'Striker'});
    });

    test('Issue 66: INVALID_PROFILE_OPTION without field or value still '
        'maps, with both null', () {
      final exc = mapHttpError(422, const {
        'detail': {'code': 'INVALID_PROFILE_OPTION', 'message': 'm'},
      });
      expect(
        exc,
        isA<InvalidProfileOptionException>()
            .having((e) => e.field, 'field', isNull)
            .having((e) => e.value, 'value', isNull),
      );
    });

    test('Issue 66: 503 EXTENDED_PROFILE_DISABLED maps to '
        'ModuleDisabledException', () {
      final exc = mapHttpError(503, const {
        'detail': {'code': 'EXTENDED_PROFILE_DISABLED', 'message': 'off'},
      });
      expect(exc, isA<ModuleDisabledException>());
      expect(exc.code, SdkErrorCode.extendedProfileDisabled);
      expect(
        SdkErrorCode.moduleDisabledCodes,
        contains(SdkErrorCode.extendedProfileDisabled),
      );
    });

    test(
      'Issue 66: 403 PROTECTED_FIELDS keeps the fields the server names',
      () {
        final exc = mapHttpError(403, const {
          'detail': {
            'code': 'PROTECTED_FIELDS',
            'message': 'These fields can only be edited by an admin',
            'fields': ['membershipDateUtc'],
          },
        });
        expect(exc.statusCode, 403);
        expect(exc.code, SdkErrorCode.protectedFields);
        expect(exc.details, {
          'fields': ['membershipDateUtc'],
        });
      },
    );

    test('Issue 66: the codes have their server spelling', () {
      expect(SdkErrorCode.invalidProfileOption, 'INVALID_PROFILE_OPTION');
      expect(SdkErrorCode.extendedProfileDisabled, 'EXTENDED_PROFILE_DISABLED');
      expect(SdkErrorCode.protectedFields, 'PROTECTED_FIELDS');
      expect(SdkErrorCode.accountNotActive, 'ACCOUNT_NOT_ACTIVE');
    });

    test('Issue 74: INVALID_PREFERENCE_VALUE has its server spelling', () {
      expect(SdkErrorCode.invalidPreferenceValue, 'INVALID_PREFERENCE_VALUE');
    });
  });
}
