import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('BulkMembersResult', () {
    const result = BulkMembersResult(
      added: ['alice', 'bob'],
      alreadyMembers: ['charlie'],
      notFound: ['unknown'],
      notEligible: ['ineligible'],
    );

    test('two instances with same values are equal', () {
      const same = BulkMembersResult(
        added: ['alice', 'bob'],
        alreadyMembers: ['charlie'],
        notFound: ['unknown'],
        notEligible: ['ineligible'],
      );
      expect(result, same);
    });

    test('two instances with different values are not equal', () {
      const different = BulkMembersResult(
        added: ['alice'],
        alreadyMembers: ['charlie'],
        notFound: ['unknown'],
        notEligible: ['ineligible'],
      );
      expect(result, isNot(different));
    });

    test('instances differing only in notEligible are not equal', () {
      const different = BulkMembersResult(
        added: ['alice', 'bob'],
        alreadyMembers: ['charlie'],
        notFound: ['unknown'],
        notEligible: ['other'],
      );
      expect(result, isNot(different));
    });

    test('equal instances have same hashCode', () {
      const same = BulkMembersResult(
        added: ['alice', 'bob'],
        alreadyMembers: ['charlie'],
        notFound: ['unknown'],
        notEligible: ['ineligible'],
      );
      expect(result.hashCode, same.hashCode);
    });

    test('copyWith creates new instance with changed field', () {
      final updated = result.copyWith(added: ['dave']);
      expect(updated.added, ['dave']);
      expect(updated.alreadyMembers, result.alreadyMembers);
      expect(updated.notFound, result.notFound);
      expect(updated.notEligible, result.notEligible);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = result.copyWith(notFound: []);
      expect(updated.added, ['alice', 'bob']);
      expect(updated.alreadyMembers, ['charlie']);
      expect(updated.notFound, isEmpty);
      expect(updated.notEligible, ['ineligible']);
    });

    test('copyWith can change notEligible independently', () {
      final updated = result.copyWith(notEligible: ['evan', 'fay']);
      expect(updated.notEligible, ['evan', 'fay']);
      expect(updated.added, result.added);
      expect(updated.alreadyMembers, result.alreadyMembers);
      expect(updated.notFound, result.notFound);
    });

    test('toMap produces correct map with camelCase keys', () {
      final map = result.toMap();
      expect(map['added'], ['alice', 'bob']);
      expect(map['alreadyMembers'], ['charlie']);
      expect(map['notFound'], ['unknown']);
      expect(map['notEligible'], ['ineligible']);
    });

    test('fromMap restores equivalent instance', () {
      final map = result.toMap();
      final fromMap = BulkMembersResult.fromMap(map);
      expect(fromMap, result);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = BulkMembersResult.fromMap(result.toMap());
      expect(restored, result);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = result.toJson();
      final fromJson = BulkMembersResult.fromJson(json);
      expect(fromJson, result);
    });

    test('fromMap handles missing fields with empty lists', () {
      final fromEmpty = BulkMembersResult.fromMap(const {});
      expect(fromEmpty.added, isEmpty);
      expect(fromEmpty.alreadyMembers, isEmpty);
      expect(fromEmpty.notFound, isEmpty);
      expect(fromEmpty.notEligible, isEmpty);
    });

    test('fromMap handles all-empty response', () {
      final fromMap = BulkMembersResult.fromMap(const {
        'added': <String>[],
        'alreadyMembers': <String>[],
        'notFound': <String>[],
        'notEligible': <String>[],
      });
      expect(fromMap.added, isEmpty);
      expect(fromMap.alreadyMembers, isEmpty);
      expect(fromMap.notFound, isEmpty);
      expect(fromMap.notEligible, isEmpty);
    });

    test('fromMap reads notEligible from server payload', () {
      final fromMap = BulkMembersResult.fromMap(const {
        'added': ['alice'],
        'alreadyMembers': <String>[],
        'notFound': <String>[],
        'notEligible': ['too_young', 'wrong_gender'],
      });
      expect(fromMap.notEligible, ['too_young', 'wrong_gender']);
    });

    test('toString includes all fields', () {
      final str = result.toString();
      expect(str, contains('alice'));
      expect(str, contains('charlie'));
      expect(str, contains('unknown'));
      expect(str, contains('ineligible'));
    });
  });
}
