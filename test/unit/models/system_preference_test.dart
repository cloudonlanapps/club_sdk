import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('SystemPreference', () {
    final written = SystemPreference(
      key: 'notification_info_retention_days',
      value: 30,
      updatedAtUtc: DateTime.utc(2026, 9, 28, 10),
      updatedBy: 'sudo',
    );

    test('fromMap parses a written preference', () {
      final p = SystemPreference.fromMap({
        'key': 'notification_info_retention_days',
        'value': 30,
        'updatedAtUtc': DateTime.utc(2026, 9, 28, 10).millisecondsSinceEpoch,
        'updatedBy': 'sudo',
      });
      expect(p, written);
      expect(p.updatedAtUtc!.isUtc, isTrue);
    });

    test('Issue 518: fromMap parses a never-written default with no '
        'updated-at', () {
      final p = SystemPreference.fromMap(const {
        'key': 'notification_info_retention_days',
        'value': 90,
        'updatedAtUtc': null,
        'updatedBy': null,
      });
      expect(p.value, 90);
      expect(p.updatedAtUtc, isNull);
      expect(p.updatedBy, isNull);
    });

    test('Issue 518: fromMap parses a payload that omits updated-at', () {
      final p = SystemPreference.fromMap(const {
        'key': 'notification_info_retention_days',
        'value': 90,
      });
      expect(p.updatedAtUtc, isNull);
    });

    test('toMap round-trips a written preference', () {
      expect(SystemPreference.fromMap(written.toMap()), written);
    });

    test('Issue 518: toMap round-trips a missing updated-at as null', () {
      const unwritten = SystemPreference(key: 'k', value: 90);
      expect(unwritten.toMap()['updatedAtUtc'], isNull);
      expect(SystemPreference.fromMap(unwritten.toMap()), unwritten);
    });

    test('copyWith clears updated-at through a ValueGetter', () {
      final cleared = written.copyWith(updatedAtUtc: () => null);
      expect(cleared.updatedAtUtc, isNull);
      expect(cleared.value, 30);
    });

    test('copyWith keeps updated-at when not given', () {
      expect(
        written.copyWith(value: () => 31).updatedAtUtc,
        written.updatedAtUtc,
      );
    });

    test('equality and hashCode include updated-at', () {
      final other = written.copyWith(updatedAtUtc: () => null);
      expect(other, isNot(written));
      expect(
        written.copyWith(),
        written,
      );
      expect(written.copyWith().hashCode, written.hashCode);
    });
  });
}
