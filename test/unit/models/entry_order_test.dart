import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('EntryOrder', () {
    test('Issue 22: wire names are asc and desc', () {
      expect(EntryOrder.oldestFirst.wireName, 'asc');
      expect(EntryOrder.newestFirst.wireName, 'desc');
      expect(EntryOrder.values, hasLength(2));
    });
  });
}
