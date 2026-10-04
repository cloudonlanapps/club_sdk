import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

void main() {
  group('mapHttpError', () {
    test('extracts code and message from detail object', () {
      final exc = mapHttpError(422, const {
        'detail': {
          'code': 'MEMBERS_EXIST',
          'message': 'Group has members',
        },
      });
      expect(exc, isA<ServerException>());
      expect(exc.statusCode, 422);
      expect(exc.code, SdkErrorCode.membersExist);
      expect(exc.message, 'Group has members');
      expect(exc.details, isNull);
    });

    test(
      'preserves membernames alongside code/message for MEMBERS_INELIGIBLE',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'MEMBERS_INELIGIBLE',
            'message': 'Some members do not meet new criteria',
            'membernames': ['alice', 'bob'],
          },
        });
        expect(exc.code, SdkErrorCode.membersIneligible);
        expect(exc.details, isNotNull);
        expect(exc.details!['membernames'], ['alice', 'bob']);
      },
    );

    test('details is null when server returns only code+message', () {
      final exc = mapHttpError(422, const {
        'detail': {
          'code': 'NOT_ELIGIBLE',
          'message': 'User does not meet criteria',
        },
      });
      expect(exc.code, SdkErrorCode.notEligible);
      expect(exc.details, isNull);
    });

    test(
      'club_server#526: a hard delete of a live item maps to '
      'HARD_DELETE_NEEDS_SOFT_DELETE',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'HARD_DELETE_NEEDS_SOFT_DELETE',
            'message': 'Soft-delete it first',
          },
        });
        expect(exc, isA<ServerException>());
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.hardDeleteNeedsSoftDelete);
      },
    );

    test(
      'club_server#526: a restore of a live item maps to NOTHING_TO_RESTORE',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'NOTHING_TO_RESTORE',
            'message': 'Not deleted',
          },
        });
        expect(exc, isA<ServerException>());
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.nothingToRestore);
      },
    );

    test(
      'club_server#517: a link change on a deleted owner maps to OWNER_DELETED',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'OWNER_DELETED',
            'message': 'Owner is deleted',
          },
        });
        expect(exc, isA<ServerException>());
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.ownerDeleted);
      },
    );

    test('club_server#510: a revoked access token maps to INVALID_TOKEN', () {
      final exc = mapHttpError(401, const {
        'detail': {'code': 'INVALID_TOKEN', 'message': 'Session revoked'},
      });
      expect(exc, isA<ServerException>());
      expect(exc.statusCode, 401);
      expect(exc.code, SdkErrorCode.invalidToken);
    });

    test(
      'a date of birth that is not a UTC midnight maps to '
      'INVALID_DOB_NOT_UTC_MIDNIGHT',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'INVALID_DOB_NOT_UTC_MIDNIGHT',
            'message': 'dateOfBirthUtc must be at 00:00:00 UTC',
          },
        });
        expect(exc, isA<ServerException>());
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.invalidDobNotUtcMidnight);
      },
    );

    test(
      'club_server#519: a credit account for the super admin maps to '
      'SUPER_ADMIN_CANNOT_HOLD_CREDIT',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'SUPER_ADMIN_CANNOT_HOLD_CREDIT',
            'message': 'The super admin cannot hold credit',
          },
        });
        expect(exc, isA<ServerException>());
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.superAdminCannotHoldCredit);
      },
    );

    test(
      'club_server#511: a direct notice to a user who may not receive it '
      'maps to RECIPIENT_NOT_DELIVERABLE',
      () {
        final exc = mapHttpError(422, const {
          'detail': {
            'code': 'RECIPIENT_NOT_DELIVERABLE',
            'message': 'The recipient may not receive this notification',
          },
        });
        expect(exc, isA<ServerException>());
        expect(exc.statusCode, 422);
        expect(exc.code, SdkErrorCode.recipientNotDeliverable);
      },
    );

    test('accepts top-level error wrapper', () {
      final exc = mapHttpError(422, const {
        'error': {
          'code': 'AUTO_GROUP_NOT_JOINABLE',
          'message': 'Auto group cannot be joined',
          'group_id': 7,
        },
      });
      expect(exc.code, SdkErrorCode.autoGroupNotJoinable);
      expect(exc.details!['group_id'], 7);
    });
  });
}
