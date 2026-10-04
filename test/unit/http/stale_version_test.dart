import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:club_sdk_2/remote_store.dart';
import 'package:test/test.dart';

/// Issue 25: a 409 STALE_VERSION maps to a dedicated exception exposing
/// the current version, when it changed and who changed it.
void main() {
  group('Issue 25: STALE_VERSION mapping', () {
    test('Issue 25: maps to StaleVersionException with its fields', () {
      final at = DateTime.utc(2026, 9, 5, 10, 30);
      final exc = mapHttpError(409, {
        'detail': {
          'code': 'STALE_VERSION',
          'message': 'Event changed since you loaded it',
          'version': 5,
          'updatedAt': at.millisecondsSinceEpoch,
          'updatedBy': 'coach_1',
        },
      });
      expect(exc, isA<StaleVersionException>());
      final stale = exc as StaleVersionException;
      expect(stale.statusCode, 409);
      expect(stale.code, SdkErrorCode.staleVersion);
      expect(stale.version, 5);
      expect(stale.updatedAtUtc, at);
      expect(stale.updatedBy, 'coach_1');
      expect(stale.message, 'Event changed since you loaded it');
    });

    test('Issue 25: tolerates a missing writer and timestamp', () {
      final exc = mapHttpError(409, const {
        'detail': {'code': 'STALE_VERSION', 'message': 'm', 'version': 2},
      });
      final stale = exc as StaleVersionException;
      expect(stale.version, 2);
      expect(stale.updatedAtUtc, isNull);
      expect(stale.updatedBy, isNull);
    });

    test('Issue 16: a 409 conflict report is typed TIME_CONFLICT', () {
      final exc = mapHttpError(409, const {
        'detail': {
          'hasConflict': true,
          'venueConflicts': <Object>[],
          'userConflicts': [
            {'eventId': 3, 'eventTitle': 't'},
          ],
        },
      });
      expect(exc.code, SdkErrorCode.timeConflict);
      expect(exc.details?['hasConflict'], isTrue);
      expect(exc.details?['userConflicts'], hasLength(1));
      expect(exc, isNot(isA<StaleVersionException>()));
    });

    test('Issue 25: other 409 codes stay plain ServerException', () {
      final exc = mapHttpError(409, const {
        'detail': {'code': 'TIME_CONFLICT', 'message': 'm'},
      });
      expect(exc, isNot(isA<StaleVersionException>()));
    });
  });
}
