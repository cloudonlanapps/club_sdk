import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  final payload = <String, dynamic>{
    'marked': [
      {'membername': 'alice', 'status': 'present'},
      {'membername': 'bob', 'status': 'absent'},
    ],
    'refused': [
      {
        'membername': 'carol',
        'code': 'INSUFFICIENT_CREDIT',
        'message': 'No usable credit',
      },
    ],
    'trialEnded': [
      {'membername': 'alice'},
    ],
  };

  group('AttendanceMarkReport', () {
    test('Issue 21: fromMap reads trialEnded as membernames', () {
      final report = AttendanceMarkReport.fromMap(payload);

      expect(report.marked.map((m) => m.membername), ['alice', 'bob']);
      expect(report.refused.single.code, SdkErrorCode.insufficientCredit);
      expect(report.trialEnded, ['alice']);
    });

    test('Issue 21: fromMap reads no ended trials from an older server', () {
      final report = AttendanceMarkReport.fromMap(
        Map.of(payload)..remove('trialEnded'),
      );

      expect(report.trialEnded, isEmpty);
    });

    test('Issue 21: toMap writes trialEnded in the wire shape', () {
      final report = AttendanceMarkReport.fromMap(payload);

      expect(report.toMap()['trialEnded'], [
        {'membername': 'alice'},
      ]);
      expect(AttendanceMarkReport.fromMap(report.toMap()), report);
      expect(AttendanceMarkReport.fromJson(report.toJson()), report);
    });

    test('Issue 21: copyWith replaces trialEnded and keeps the rest', () {
      final report = AttendanceMarkReport.fromMap(payload);

      final copy = report.copyWith(trialEnded: const []);

      expect(copy.trialEnded, isEmpty);
      expect(copy.marked, report.marked);
      expect(copy.refused, report.refused);
      expect(report.copyWith(), report);
    });

    test('Issue 21: trialEnded takes part in equality and hashCode', () {
      final a = AttendanceMarkReport.fromMap(payload);
      final b = a.copyWith(trialEnded: const ['bob']);

      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
      expect(a, AttendanceMarkReport.fromMap(payload));
      expect(a.hashCode, AttendanceMarkReport.fromMap(payload).hashCode);
      expect(a.toString(), contains('trialEnded: [alice]'));
    });

    test('allMarked ignores ended trials', () {
      final report = AttendanceMarkReport.fromMap(
        Map.of(payload)..['refused'] = <dynamic>[],
      );

      expect(report.allMarked, isTrue);
      expect(report.trialEnded, isNotEmpty);
    });
  });
}
