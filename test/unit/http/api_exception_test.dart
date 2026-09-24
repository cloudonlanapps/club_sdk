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
