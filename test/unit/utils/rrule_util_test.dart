import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// RRULE Utility Unit Tests.
///
/// These tests are NOT bound to a specific SDK requirement.
///
/// Reason: RruleUtil is an internal utility for parsing and expanding
/// iCalendar RRULE strings. It supports the event occurrence generation
/// functionality but is not exposed as a public API requirement.
///
/// The RRULE validation rules by EventType are implementation details:
/// - Programme: FREQ=WEEKLY with BYDAY required
/// - Camp: FREQ=DAILY with COUNT required
/// - OneOff: No RRULE allowed
void main() {
  group('RruleUtil', () {
    late RruleUtil util;

    setUp(() {
      util = RruleUtil();
    });

    group('validate', () {
      test('parses valid RRULE with RRULE: prefix', () {
        expect(
          () => util.validate('RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR'),
          returnsNormally,
        );
      });

      test('parses valid RRULE without RRULE: prefix', () {
        expect(
          () => util.validate('FREQ=WEEKLY;BYDAY=MO,WE,FR'),
          returnsNormally,
        );
      });

      test('parses FREQ=DAILY', () {
        final rule = util.validate('FREQ=DAILY');
        expect(rule.frequency.toString().toUpperCase(), 'DAILY');
      });

      test('parses FREQ=WEEKLY with BYDAY', () {
        final rule = util.validate('FREQ=WEEKLY;BYDAY=MO,WE,FR');
        expect(rule.frequency.toString().toUpperCase(), 'WEEKLY');
        expect(rule.byWeekDays, isNotEmpty);
      });

      test('parses FREQ=DAILY with COUNT', () {
        final rule = util.validate('FREQ=DAILY;COUNT=5');
        expect(rule.frequency.toString().toUpperCase(), 'DAILY');
        expect(rule.count, 5);
      });

      test('throws InvalidRruleException for empty string', () {
        expect(
          () => util.validate(''),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidRrule,
            ),
          ),
        );
      });

      test('throws InvalidRruleException for malformed string', () {
        expect(
          () => util.validate('INVALID_RRULE'),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidRrule,
            ),
          ),
        );
      });

      test('throws InvalidRruleException for missing FREQ', () {
        expect(
          () => util.validate('BYDAY=MO'),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.invalidRrule,
            ),
          ),
        );
      });
    });

    group('validateForEventType - Programme', () {
      test('accepts valid Programme RRULE with WEEKLY and BYDAY', () {
        expect(
          () => util.validateForEventType(
            'FREQ=WEEKLY;BYDAY=MO,WE,FR',
            EventType.programme,
          ),
          returnsNormally,
        );
      });

      test('accepts Programme RRULE with UNTIL', () {
        expect(
          () => util.validateForEventType(
            'FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231T235959Z',
            EventType.programme,
          ),
          returnsNormally,
        );
      });

      test('rejects Programme RRULE without BYDAY', () {
        expect(
          () => util.validateForEventType('FREQ=WEEKLY', EventType.programme),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.rruleConstraintViolation,
            ),
          ),
        );
      });

      test('rejects Programme RRULE with DAILY frequency', () {
        expect(
          () => util.validateForEventType(
            'FREQ=DAILY;BYDAY=MO',
            EventType.programme,
          ),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.rruleConstraintViolation,
            ),
          ),
        );
      });
    });

    group('validateForEventType - Camp', () {
      test('accepts valid Camp RRULE with DAILY and COUNT', () {
        expect(
          () => util.validateForEventType('FREQ=DAILY;COUNT=5', EventType.camp),
          returnsNormally,
        );
      });

      test('rejects Camp RRULE without COUNT', () {
        expect(
          () => util.validateForEventType('FREQ=DAILY', EventType.camp),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.rruleConstraintViolation,
            ),
          ),
        );
      });

      test('rejects Camp RRULE with WEEKLY frequency', () {
        expect(
          () =>
              util.validateForEventType('FREQ=WEEKLY;COUNT=5', EventType.camp),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.rruleConstraintViolation,
            ),
          ),
        );
      });
    });

    group('validateForEventType - OneOff', () {
      test('rejects any RRULE for OneOff events', () {
        expect(
          () => util.validateForEventType('FREQ=DAILY', EventType.oneOff),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.rruleNotAllowed,
            ),
          ),
        );
      });

      test('rejects valid RRULE for OneOff events', () {
        expect(
          () => util.validateForEventType(
            'FREQ=WEEKLY;BYDAY=MO',
            EventType.oneOff,
          ),
          throwsA(
            isA<SdkError>().having(
              (e) => e.code,
              'code',
              SdkErrorCode.rruleNotAllowed,
            ),
          ),
        );
      });
    });

    group('isValid', () {
      test('returns true for valid RRULE', () {
        expect(util.isValid('FREQ=DAILY'), isTrue);
      });

      test('returns true for complex RRULE', () {
        expect(util.isValid('FREQ=WEEKLY;BYDAY=MO,WE,FR;COUNT=10'), isTrue);
      });

      test('returns false for invalid RRULE', () {
        expect(util.isValid('NOT_VALID'), isFalse);
      });

      test('returns false for empty RRULE', () {
        expect(util.isValid(''), isFalse);
      });
    });

    group('isValidForEventType', () {
      test('returns true for valid Programme RRULE', () {
        expect(
          util.isValidForEventType('FREQ=WEEKLY;BYDAY=MO', EventType.programme),
          isTrue,
        );
      });

      test('returns false for invalid Programme RRULE (no BYDAY)', () {
        expect(
          util.isValidForEventType('FREQ=WEEKLY', EventType.programme),
          isFalse,
        );
      });

      test('returns true for valid Camp RRULE', () {
        expect(
          util.isValidForEventType('FREQ=DAILY;COUNT=5', EventType.camp),
          isTrue,
        );
      });

      test('returns false for any OneOff RRULE', () {
        expect(
          util.isValidForEventType('FREQ=DAILY', EventType.oneOff),
          isFalse,
        );
      });
    });

    group('expand', () {
      test('expands weekly RRULE correctly', () {
        final result = util.expand(
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
          dtStart: DateTime.utc(2026, 1, 5, 10), // Monday Jan 5
          fromUtc: DateTime.utc(2026),
          toUtc: DateTime.utc(2026, 2),
        );

        // January 2026: Mondays are 5, 12, 19, 26
        expect(result.occurrences.length, 4);
        expect(result.occurrences[0], DateTime.utc(2026, 1, 5, 10));
        expect(result.occurrences[1], DateTime.utc(2026, 1, 12, 10));
        expect(result.occurrences[2], DateTime.utc(2026, 1, 19, 10));
        expect(result.occurrences[3], DateTime.utc(2026, 1, 26, 10));
      });

      test('expands daily RRULE with COUNT', () {
        final result = util.expand(
          rrule: 'FREQ=DAILY;COUNT=5',
          dtStart: DateTime.utc(2026, 1, 1, 9),
          fromUtc: DateTime.utc(2026),
          toUtc: DateTime.utc(2026, 1, 31),
        );

        expect(result.occurrences.length, 5);
        expect(result.occurrences[0], DateTime.utc(2026, 1, 1, 9));
        expect(result.occurrences[4], DateTime.utc(2026, 1, 5, 9));
        expect(result.hasMore, isFalse);
      });

      test('respects untilUtc boundary', () {
        final result = util.expand(
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
          dtStart: DateTime.utc(2026, 1, 5, 10),
          fromUtc: DateTime.utc(2026),
          toUtc: DateTime.utc(2026, 2),
          untilUtc: DateTime.utc(2026, 1, 15),
        );

        // Should only include Jan 5, 12 (before until date)
        expect(result.occurrences.length, 2);
        expect(result.occurrences[0], DateTime.utc(2026, 1, 5, 10));
        expect(result.occurrences[1], DateTime.utc(2026, 1, 12, 10));
      });

      test('respects limit parameter', () {
        final result = util.expand(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026),
          fromUtc: DateTime.utc(2026),
          toUtc: DateTime.utc(2026, 12, 31),
          limit: 5,
        );

        expect(result.occurrences.length, 5);
        expect(result.hasMore, isTrue);
      });

      test('excludes dates in excludeDates list', () {
        final result = util.expand(
          rrule: 'FREQ=DAILY;COUNT=5',
          dtStart: DateTime.utc(2026, 1, 1, 9),
          fromUtc: DateTime.utc(2026),
          toUtc: DateTime.utc(2026, 1, 31),
          excludeDates: [
            DateTime.utc(2026, 1, 2, 9), // Exclude Jan 2
            DateTime.utc(2026, 1, 4, 9), // Exclude Jan 4
          ],
        );

        // COUNT=5 means 5 actual sessions needed (not including excluded dates)
        // With 2 exclusions, we extend to 7 calendar days to get 5 sessions
        // Jan 1, 3, 5, 6, 7 (skipping Jan 2 and 4)
        expect(result.occurrences.length, 5);
        expect(result.occurrences[0], DateTime.utc(2026, 1, 1, 9));
        expect(result.occurrences[1], DateTime.utc(2026, 1, 3, 9));
        expect(result.occurrences[2], DateTime.utc(2026, 1, 5, 9));
        expect(result.occurrences[3], DateTime.utc(2026, 1, 6, 9));
        expect(result.occurrences[4], DateTime.utc(2026, 1, 7, 9));
      });

      test('returns empty list for range with no occurrences', () {
        final result = util.expand(
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
          dtStart: DateTime.utc(2026, 2, 2, 10), // February start
          fromUtc: DateTime.utc(2026),
          toUtc: DateTime.utc(2026, 1, 31),
        );

        // Event starts in February, query is for January
        expect(result.occurrences, isEmpty);
      });

      test('expands multiple days per week', () {
        final result = util.expand(
          rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
          dtStart: DateTime.utc(2026, 1, 5, 10), // Monday Jan 5
          fromUtc: DateTime.utc(2026, 1, 5),
          toUtc: DateTime.utc(2026, 1, 12),
        );

        // Jan 5 (Mon), Jan 7 (Wed), Jan 9 (Fri)
        expect(result.occurrences.length, 3);
      });
    });

    group('getNextOccurrences', () {
      test('returns correct number of upcoming occurrences', () {
        final occurrences = util.getNextOccurrences(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026),
          count: 3,
          afterUtc: DateTime.utc(2026),
        );

        expect(occurrences.length, 3);
        expect(occurrences[0], DateTime.utc(2026));
        expect(occurrences[1], DateTime.utc(2026, 1, 2));
        expect(occurrences[2], DateTime.utc(2026, 1, 3));
      });

      test('respects afterUtc parameter', () {
        final occurrences = util.getNextOccurrences(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026),
          count: 3,
          afterUtc: DateTime.utc(2026, 1, 5),
        );

        expect(occurrences.length, 3);
        expect(occurrences[0], DateTime.utc(2026, 1, 5));
      });

      test('respects untilUtc parameter', () {
        final occurrences = util.getNextOccurrences(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026),
          count: 100,
          afterUtc: DateTime.utc(2026),
          untilUtc: DateTime.utc(2026, 1, 5),
        );

        expect(occurrences.length, 5);
      });

      test('excludes dates in excludeDates list', () {
        // FREQ=DAILY without COUNT - unlimited recurrence
        // The 'count' parameter here is how many results we want,
        // not RRULE COUNT
        final occurrences = util.getNextOccurrences(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026),
          count: 3,
          afterUtc: DateTime.utc(2026),
          excludeDates: [DateTime.utc(2026, 1, 2)],
        );

        expect(occurrences.length, 3);
        expect(occurrences[0], DateTime.utc(2026));
        expect(occurrences[1], DateTime.utc(2026, 1, 3)); // Jan 2 skipped
        expect(occurrences[2], DateTime.utc(2026, 1, 4));
      });

      test('COUNT with excludeDates extends to get actual sessions', () {
        // RRULE COUNT=5 means we want 5 actual sessions
        // With 1 exclusion, we extend to 6 calendar days
        final occurrences = util.getNextOccurrences(
          rrule: 'FREQ=DAILY;COUNT=5',
          dtStart: DateTime.utc(2026),
          count: 10, // Request more than RRULE COUNT
          afterUtc: DateTime.utc(2026),
          excludeDates: [DateTime.utc(2026, 1, 2)],
        );

        // Should get exactly 5 (RRULE COUNT), not 4 (COUNT minus exclusion)
        expect(occurrences.length, 5);
        expect(occurrences[0], DateTime.utc(2026));
        expect(occurrences[1], DateTime.utc(2026, 1, 3)); // Jan 2 skipped
        expect(occurrences[2], DateTime.utc(2026, 1, 4));
        expect(occurrences[3], DateTime.utc(2026, 1, 5));
        expect(occurrences[4], DateTime.utc(2026, 1, 6));
      });
    });

    group('isValidOccurrence', () {
      test('returns true for valid occurrence', () {
        final isValid = util.isValidOccurrence(
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
          dtStart: DateTime.utc(2026, 1, 5, 10), // Monday
          occurrenceTimeUtc: DateTime.utc(2026, 1, 12, 10), // Next Monday
        );
        expect(isValid, isTrue);
      });

      test('returns false for occurrence on wrong day', () {
        final isValid = util.isValidOccurrence(
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
          dtStart: DateTime.utc(2026, 1, 5, 10), // Monday
          occurrenceTimeUtc: DateTime.utc(2026, 1, 13, 10), // Tuesday
        );
        expect(isValid, isFalse);
      });

      test('returns false for occurrence before dtStart', () {
        final isValid = util.isValidOccurrence(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026, 1, 5),
          occurrenceTimeUtc: DateTime.utc(2026),
        );
        expect(isValid, isFalse);
      });

      test('returns false for occurrence after untilUtc', () {
        final isValid = util.isValidOccurrence(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026),
          occurrenceTimeUtc: DateTime.utc(2026, 1, 10),
          untilUtc: DateTime.utc(2026, 1, 5),
        );
        expect(isValid, isFalse);
      });

      test('returns false for excluded date', () {
        final isValid = util.isValidOccurrence(
          rrule: 'FREQ=DAILY',
          dtStart: DateTime.utc(2026),
          occurrenceTimeUtc: DateTime.utc(2026, 1, 3),
          excludeDates: [DateTime.utc(2026, 1, 3)],
        );
        expect(isValid, isFalse);
      });
    });

    group('toHumanReadable', () {
      test('converts RRULE to readable text', () {
        final text = util.toHumanReadable('FREQ=WEEKLY');
        expect(text, isNotEmpty);
        expect(text.toLowerCase(), contains('week'));
      });

      test('includes day information', () {
        final text = util.toHumanReadable('FREQ=DAILY');
        expect(text, isNotEmpty);
        expect(text.toLowerCase(), contains('dai')); // 'daily' contains 'dai'
      });
    });

    group('parseExDates', () {
      test('parses comma-separated dates with time', () {
        final dates = util.parseExDates('20260115T100000Z,20260126T100000Z');
        expect(dates.length, 2);
        expect(dates[0], DateTime.utc(2026, 1, 15, 10));
        expect(dates[1], DateTime.utc(2026, 1, 26, 10));
      });

      test('parses dates with EXDATE: prefix', () {
        final dates = util.parseExDates('EXDATE:20260115T100000Z');
        expect(dates.length, 1);
        expect(dates[0], DateTime.utc(2026, 1, 15, 10));
      });

      test('parses date-only format', () {
        final dates = util.parseExDates('20260115,20260126');
        expect(dates.length, 2);
        expect(dates[0], DateTime.utc(2026, 1, 15));
        expect(dates[1], DateTime.utc(2026, 1, 26));
      });

      test('returns empty list for empty string', () {
        final dates = util.parseExDates('');
        expect(dates, isEmpty);
      });
    });
  });

  group('RruleConfig', () {
    test('default configs exist for all event types', () {
      expect(RruleConfig.defaults.containsKey(EventType.programme), isTrue);
      expect(RruleConfig.defaults.containsKey(EventType.camp), isTrue);
      expect(RruleConfig.defaults.containsKey(EventType.oneOff), isTrue);
    });

    test('oneOff config disallows RRULE', () {
      final config = RruleConfig.forEventType(EventType.oneOff);
      expect(config.allowRrule, isFalse);
    });

    test('programme config requires WEEKLY frequency', () {
      final config = RruleConfig.forEventType(EventType.programme);
      expect(config.requiredFrequency, 'WEEKLY');
      expect(config.requireByDay, isTrue);
    });

    test('camp config requires DAILY frequency and COUNT', () {
      final config = RruleConfig.forEventType(EventType.camp);
      expect(config.requiredFrequency, 'DAILY');
      expect(config.requireCount, isTrue);
      expect(config.allowExDate, isTrue);
    });

    test('custom config can override defaults', () {
      final util = RruleUtil(
        customConfigs: {
          EventType.programme: const RruleConfig(
            eventType: EventType.programme,
            requiredFrequency: 'DAILY', // Override to DAILY
          ),
        },
      );

      final config = util.getConfig(EventType.programme);
      expect(config.requiredFrequency, 'DAILY');
      expect(config.requireByDay, isFalse);
    });

    test('two instances with same values are equal', () {
      const config1 = RruleConfig(
        eventType: EventType.programme,
        maxOccurrencesPerExpansion: 100,
      );
      const config2 = RruleConfig(
        eventType: EventType.programme,
        maxOccurrencesPerExpansion: 100,
      );
      expect(config1, config2);
    });

    test('equal instances have same hashCode', () {
      const config1 = RruleConfig(eventType: EventType.camp);
      const config2 = RruleConfig(eventType: EventType.camp);
      expect(config1.hashCode, config2.hashCode);
    });

    test('toString returns descriptive string', () {
      const config = RruleConfig(eventType: EventType.programme);
      final str = config.toString();
      expect(str, contains('programme'));
      expect(str, contains('RruleConfig'));
    });
  });
}
