import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Model fixes from the SDK review: #42 (evaluation media links) and #50
/// (attendance previousStatus and leaveReason).
void main() {
  group('Issue 42: MediaLinkOwnerType.evaluation', () {
    test('fromWire reads evaluation', () {
      expect(
        MediaLinkOwnerType.fromWire('evaluation'),
        MediaLinkOwnerType.evaluation,
      );
      expect(MediaLinkOwnerType.evaluation.wire, 'evaluation');
    });

    test('a reverse entry owned by an evaluation parses', () {
      final entry = MediaLinkReverseEntry.fromMap(const {
        'ownerType': 'evaluation',
        'ownerId': 12,
        'tag': 'clip',
        'createdAtUtc': 0,
        'updatedAtUtc': 0,
      });
      expect(entry.ownerType, MediaLinkOwnerType.evaluation);
      expect(entry.ownerId, '12');
    });
  });

  group('Issue 50: AttendanceRecord previousStatus and leaveReason', () {
    final recorded = DateTime.utc(2026, 9, 1, 18);
    final map = <String, dynamic>{
      'id': 3,
      'occurrenceTimeUtc': recorded.millisecondsSinceEpoch,
      'membername': 'joe',
      'status': 'onLeaveRequested',
      'notes': null,
      'previousStatus': 'present',
      'leaveReason': 'exam',
      'recordedAtUtc': recorded.millisecondsSinceEpoch,
    };

    test('fromMap reads both', () {
      final r = AttendanceRecord.fromMap(map);
      expect(r.previousStatus, AttendanceStatus.present);
      expect(r.leaveReason, 'exam');
    });

    test('both are null when absent', () {
      final r = AttendanceRecord.fromMap(
        Map.of(map)
          ..remove('previousStatus')
          ..remove('leaveReason'),
      );
      expect(r.previousStatus, isNull);
      expect(r.leaveReason, isNull);
    });

    test('toMap / fromMap round-trip keeps both', () {
      final r = AttendanceRecord.fromMap(map);
      expect(AttendanceRecord.fromMap(r.toMap()), r);
      expect(r.toMap()['previousStatus'], 'present');
      expect(r.toMap()['leaveReason'], 'exam');
    });

    test('equality depends on both', () {
      final r = AttendanceRecord.fromMap(map);
      expect(r.copyWith(leaveReason: () => 'other'), isNot(r));
      expect(
        r.copyWith(previousStatus: () => AttendanceStatus.absent),
        isNot(r),
      );
    });

    test('copyWith can clear both', () {
      final r = AttendanceRecord.fromMap(map).copyWith(
        previousStatus: () => null,
        leaveReason: () => null,
      );
      expect(r.previousStatus, isNull);
      expect(r.leaveReason, isNull);
    });
  });
}
