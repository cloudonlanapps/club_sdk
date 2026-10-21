import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

void main() {
  group('translateRRule', () {
    test('Issue 36: one weekday reads as a plural', () {
      expect(translateRRule('FREQ=WEEKLY;BYDAY=MO'), 'Weekly on Mondays');
    });

    test('Issue 36: two weekdays are joined with "and"', () {
      expect(
        translateRRule('FREQ=WEEKLY;BYDAY=MO,WE'),
        'Weekly on Monday and Wednesday',
      );
    });

    test('Issue 36: three weekdays are listed with commas and "and"', () {
      expect(
        translateRRule('FREQ=WEEKLY;BYDAY=MO,WE,FR'),
        'Weekly on Monday, Wednesday and Friday',
      );
    });

    test('Issue 36: an RRULE: prefix is accepted', () {
      expect(
        translateRRule('RRULE:FREQ=WEEKLY;BYDAY=TU,TH'),
        'Weekly on Tuesday and Thursday',
      );
    });

    test('Issue 36: without BYDAY the weekday comes from occurrenceDate', () {
      expect(
        // 7 January 2026 is a Wednesday; noon UTC is that day everywhere.
        translateRRule(
          'FREQ=WEEKLY',
          occurrenceDate: DateTime.utc(2026, 1, 7, 12),
        ),
        'Weekly on Wednesdays',
      );
    });

    test('Issue 36: null and empty rules give null', () {
      expect(translateRRule(null), isNull);
      expect(translateRRule(''), isNull);
    });

    test('Issue 36: a monthly rule gives null', () {
      expect(translateRRule('FREQ=MONTHLY'), isNull);
    });

    test('Issue 36: a yearly rule gives null', () {
      expect(translateRRule('FREQ=YEARLY'), isNull);
    });

    test('Issue 36: a camp rule gives null', () {
      expect(translateRRule('FREQ=DAILY;COUNT=7'), isNull);
    });

    test('Issue 36: a camp rule with an EXDATE line gives null', () {
      expect(
        translateRRule('FREQ=DAILY;COUNT=7\nEXDATE:20260103T090000Z'),
        isNull,
      );
    });

    test('Issue 36: a weekly rule with COUNT gives null', () {
      expect(translateRRule('FREQ=WEEKLY;BYDAY=MO;COUNT=8'), isNull);
    });

    test('Issue 36: a weekly rule with UNTIL gives null', () {
      expect(
        translateRRule('FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231T000000Z'),
        isNull,
      );
    });

    test('Issue 36: a weekly rule with INTERVAL gives null', () {
      expect(translateRRule('FREQ=WEEKLY;INTERVAL=2;BYDAY=MO'), isNull);
    });

    test('Issue 36: a weekly rule with an EXDATE line gives null', () {
      expect(
        translateRRule('FREQ=WEEKLY;BYDAY=MO\nEXDATE:20260105T100000Z'),
        isNull,
      );
    });

    test('Issue 36: a malformed rule gives null', () {
      expect(translateRRule('FREQ=WEEKLY;BYDAY=XX'), isNull);
    });
  });
}
