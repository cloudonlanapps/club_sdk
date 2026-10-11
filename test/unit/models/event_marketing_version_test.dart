import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 1: the staff read of an event's marketing block carries the
/// block's own `version`, `updatedAt` and `updatedBy` (club_server#13).
void main() {
  group('Issue 1: EventMarketing version', () {
    final writtenAt = DateTime.utc(2027, 2, 1, 9);
    final map = <String, dynamic>{
      'eventId': 42,
      'fee': 500,
      'version': 4,
      'updatedAt': writtenAt.millisecondsSinceEpoch,
      'updatedBy': 'admin_1',
    };

    test('Issue 1: fromMap reads version, updatedAt and updatedBy', () {
      final block = EventMarketing.fromMap(map);
      expect(block.version, 4);
      expect(block.updatedAtUtc, writtenAt);
      expect(block.updatedAtUtc!.isUtc, isTrue);
      expect(block.updatedBy, 'admin_1');
    });

    test('Issue 1: a map without them, as the public read sends, is at the '
        'unwritten version with no time and no writer', () {
      final block = EventMarketing.fromMap(const {'publicId': 'p', 'fee': 500});
      expect(block.version, EventMarketing.unwrittenVersion);
      expect(block.updatedAtUtc, isNull);
      expect(block.updatedBy, isNull);
    });

    test('Issue 1: a block built by the caller is at the unwritten '
        'version', () {
      const block = EventMarketing(fee: 500);
      expect(block.version, EventMarketing.unwrittenVersion);
      expect(block.version, 1);
    });

    test('Issue 1: a null updatedBy is read as no writer', () {
      final block = EventMarketing.fromMap({...map, 'updatedBy': null});
      expect(block.updatedBy, isNull);
      expect(block.version, 4);
    });

    test('Issue 1: toMap and fromMap round-trip the three fields', () {
      final block = EventMarketing.fromMap(map);
      final again = EventMarketing.fromMap(block.toMap());
      expect(again.version, 4);
      expect(again.updatedAtUtc, writtenAt);
      expect(again.updatedBy, 'admin_1');
      expect(again, block);
    });

    test('Issue 1: toJson and fromJson round-trip the three fields', () {
      final block = EventMarketing.fromMap(map);
      expect(EventMarketing.fromJson(block.toJson()), block);
    });

    test('Issue 1: copyWith sets the version', () {
      final block = EventMarketing.fromMap(map).copyWith(version: 5);
      expect(block.version, 5);
      expect(block.updatedBy, 'admin_1');
      expect(block.fee, 500);
    });

    test('Issue 1: copyWith clears updatedAtUtc and updatedBy through a '
        'getter', () {
      final block = EventMarketing.fromMap(
        map,
      ).copyWith(updatedAtUtc: () => null, updatedBy: () => null);
      expect(block.updatedAtUtc, isNull);
      expect(block.updatedBy, isNull);
      expect(block.version, 4);
    });

    test('Issue 1: copyWith of another field keeps the three fields', () {
      final block = EventMarketing.fromMap(map).copyWith(fee: () => 600);
      expect(block.fee, 600);
      expect(block.version, 4);
      expect(block.updatedAtUtc, writtenAt);
      expect(block.updatedBy, 'admin_1');
    });

    test('Issue 1: blocks at different versions are not equal', () {
      final a = EventMarketing.fromMap(map);
      final b = EventMarketing.fromMap({...map, 'version': 5});
      expect(a == b, isFalse);
    });

    test('Issue 1: blocks last written by different users are not '
        'equal', () {
      final a = EventMarketing.fromMap(map);
      final b = EventMarketing.fromMap({...map, 'updatedBy': 'admin_2'});
      expect(a == b, isFalse);
    });

    test('Issue 1: blocks with the same three fields are equal and hash '
        'alike', () {
      final a = EventMarketing.fromMap(map);
      final b = EventMarketing.fromMap(Map<String, dynamic>.of(map));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
