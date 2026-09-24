import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Issue 25: every EventResponse carries `version` and `updatedBy`
/// (club_server#292).
void main() {
  group('Issue 25: Event version', () {
    final wire = <String, dynamic>{
      'id': 7,
      'title': 'T',
      'description': 'D',
      'type': 'oneOff',
      'visibility': 'public',
      'venueId': 1,
      'startTimeUtc': DateTime.utc(2027, 1, 1, 10).millisecondsSinceEpoch,
      'endTimeUtc': DateTime.utc(2027, 1, 1, 11).millisecondsSinceEpoch,
      'createdAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
      'updatedAtUtc': DateTime.utc(2026).millisecondsSinceEpoch,
      'version': 3,
      'updatedBy': 'admin_1',
    };

    test('Issue 25: fromMap reads version and updatedBy', () {
      final e = Event.fromMap(wire);
      expect(e.version, 3);
      expect(e.updatedBy, 'admin_1');
    });

    test('Issue 25: version defaults to 1 and updatedBy to null', () {
      final e = Event.fromMap(
        {...wire}
          ..remove('version')
          ..remove('updatedBy'),
      );
      expect(e.version, 1);
      expect(e.updatedBy, isNull);
    });

    test('Issue 25: round-trip keeps version and updatedBy', () {
      final e = Event.fromMap(wire);
      expect(Event.fromMap(e.toMap()), e);
      expect(Event.fromJson(e.toJson()), e);
      expect(e.toMap()['version'], 3);
      expect(e.toMap()['updatedBy'], 'admin_1');
    });

    test('Issue 25: copyWith and equality see the version', () {
      final e = Event.fromMap(wire);
      final bumped = e.copyWith(version: 4, updatedBy: () => null);
      expect(bumped.version, 4);
      expect(bumped.updatedBy, isNull);
      expect(bumped, isNot(e));
      expect(e.copyWith(), e);
    });
  });
}
