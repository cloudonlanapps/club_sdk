import 'package:rrule/rrule.dart';

import '../exceptions/error_codes.dart';
import '../exceptions/exceptions.dart';
import '../models/enums.dart';
import '../models/rrule_config.dart';

/// Result of an RRULE expansion containing occurrence start times.
class RruleExpansionResult {
  const RruleExpansionResult({
    required this.occurrences,
    required this.hasMore,
    this.nextCursor,
  });

  /// List of occurrence start times (all in UTC).
  final List<DateTime> occurrences;

  /// Whether there are more occurrences beyond the requested range/limit.
  final bool hasMore;

  /// Cursor for pagination (the last occurrence time if hasMore is true).
  final DateTime? nextCursor;
}

/// Utility class for RRULE validation and expansion.
///
/// Provides RFC 5545 compliant recurrence rule parsing, validation, and
/// expansion using type-specific rules defined in [RruleConfig].
///
/// ## Default Rules by Event Type
///
/// - **Programme**: `FREQ=WEEKLY` with `BYDAY` required
///   (e.g., `FREQ=WEEKLY;BYDAY=MO,WE,FR`)
/// - **Camp**: `FREQ=DAILY` with `COUNT` required, `EXDATE` allowed for
///   holidays
/// - **OneOff**: No RRULE allowed
///
/// ## Example Usage
///
/// ```dart
/// final util = RruleUtil();
///
/// // Validate an RRULE string
/// util.validate('FREQ=WEEKLY;BYDAY=MO,WE,FR');
///
/// // Validate with type-specific rules
/// util.validateForEventType(
///   'FREQ=WEEKLY;BYDAY=MO',
///   EventType.programme,
/// );
///
/// // Expand RRULE to get occurrences
/// final result = util.expand(
///   rrule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
///   dtStart: DateTime.utc(2026, 1, 5, 10, 0),
///   fromUtc: DateTime.utc(2026, 1, 1),
///   toUtc: DateTime.utc(2026, 3, 31),
/// );
/// ```
class RruleUtil {
  /// Creates an RRULE utility with optional custom configurations.
  ///
  /// [customConfigs] allows overriding default configurations for specific
  /// event types. If not provided, [RruleConfig.defaults] are used.
  RruleUtil({Map<EventType, RruleConfig>? customConfigs})
    : _configs = {...RruleConfig.defaults, ...?customConfigs};

  final Map<EventType, RruleConfig> _configs;

  /// Get the configuration for an event type.
  RruleConfig getConfig(EventType eventType) {
    return _configs[eventType] ?? RruleConfig.forEventType(eventType);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates an RRULE string against RFC 5545.
  ///
  /// Returns the parsed [RecurrenceRule] if valid.
  /// Throws [SdkError] with [SdkErrorCode.invalidRrule] if malformed.
  RecurrenceRule validate(String rrule) {
    if (rrule.isEmpty) {
      throw const SdkError(
        'RRULE cannot be empty',
        code: SdkErrorCode.invalidRrule,
      );
    }

    try {
      // Handle both 'RRULE:FREQ=...' and 'FREQ=...' formats
      final normalized = rrule.startsWith('RRULE:') ? rrule : 'RRULE:$rrule';
      return RecurrenceRule.fromString(normalized);
    } on FormatException catch (e) {
      throw SdkError(e.message, code: SdkErrorCode.invalidRrule);
    } catch (e) {
      throw SdkError(e.toString(), code: SdkErrorCode.invalidRrule);
    }
  }

  /// Validates an RRULE string with type-specific constraints.
  ///
  /// Returns the parsed [RecurrenceRule] if valid.
  ///
  /// Throws [SdkError] with appropriate code if validation fails.
  RecurrenceRule validateForEventType(String rrule, EventType eventType) {
    final config = getConfig(eventType);

    if (!config.allowRrule) {
      throw SdkError(
        'RRULE is not allowed for $eventType events',
        code: SdkErrorCode.rruleNotAllowed,
      );
    }

    final rule = validate(rrule);

    if (config.requiredFrequency != null) {
      final frequency = rule.frequency.toString().toUpperCase();
      if (frequency != config.requiredFrequency) {
        throw SdkError(
          'Frequency must be ${config.requiredFrequency}, got $frequency',
          code: SdkErrorCode.rruleConstraintViolation,
        );
      }
    }

    if (config.requireByDay && rule.byWeekDays.isEmpty) {
      throw const SdkError(
        'BYDAY is required but not specified',
        code: SdkErrorCode.rruleConstraintViolation,
      );
    }

    if (config.requireCount && rule.count == null) {
      throw const SdkError(
        'COUNT is required but not specified',
        code: SdkErrorCode.rruleConstraintViolation,
      );
    }

    return rule;
  }

  /// Checks if an RRULE string is valid without throwing.
  ///
  /// Returns true if valid, false otherwise.
  bool isValid(String rrule) {
    try {
      validate(rrule);
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  /// Checks if an RRULE string is valid for a specific event type.
  ///
  /// Returns true if valid, false otherwise.
  bool isValidForEventType(String rrule, EventType eventType) {
    try {
      validateForEventType(rrule, eventType);
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPANSION
  // ══════════════════════════════════════════════════════════════════════════

  /// Expands an RRULE to generate occurrence start times within a date range.
  ///
  /// Parameters:
  /// - [rrule]: The RRULE string (with or without 'RRULE:' prefix)
  /// - [dtStart]: The event's start time (DTSTART in RFC 5545)
  /// - [fromUtc]: Start of the range to query (inclusive)
  /// - [toUtc]: End of the range to query (exclusive)
  /// - [eventType]: Optional event type for applying expansion limits
  /// - [limit]: Optional maximum number of occurrences to return
  /// - [untilUtc]: Optional end date for the recurrence
  ///   (e.g., event.untilTimeUtc)
  /// - [excludeDates]: Optional list of dates to exclude (EXDATE support)
  ///
  /// Returns [RruleExpansionResult] containing:
  /// - `occurrences`: List of DateTime values in UTC
  /// - `hasMore`: Whether there are more occurrences beyond the range/limit
  ///
  /// **Note on COUNT and EXDATE behavior:**
  /// When both COUNT and excludeDates are present, COUNT represents the number
  /// of actual sessions needed (not including excluded dates). The expansion
  /// will extend beyond the calendar days implied by COUNT to deliver the
  /// requested number of sessions.
  ///
  /// Example: COUNT=6 with 2 excluded dates will generate 6 actual sessions
  /// spread over 8 calendar days.
  ///
  /// Throws `InvalidRruleException` if the RRULE is malformed.
  RruleExpansionResult expand({
    required String rrule,
    required DateTime dtStart,
    required DateTime fromUtc,
    required DateTime toUtc,
    EventType? eventType,
    int? limit,
    DateTime? untilUtc,
    List<DateTime>? excludeDates,
  }) {
    // Validate the RRULE
    final rule = validate(rrule);

    // Determine effective limits
    final config = eventType != null ? getConfig(eventType) : null;
    final maxOccurrences = limit ?? config?.maxOccurrencesPerExpansion ?? 365;

    // Ensure dtStart is UTC
    final startUtc = dtStart.isUtc ? dtStart : dtStart.toUtc();

    // Normalize exclude dates for comparison
    final excludeSet = excludeDates
        ?.map((d) => d.isUtc ? d : d.toUtc())
        .toSet();

    // Handle COUNT + EXDATE: COUNT means actual sessions needed
    // We need to extend beyond COUNT to compensate for excluded dates
    final originalCount = rule.count;
    final hasExclusions = excludeSet != null && excludeSet.isNotEmpty;
    var effectiveRule = rule;

    if (originalCount != null && hasExclusions) {
      // Remove COUNT from RRULE to generate unlimited instances
      // We'll manually enforce COUNT after filtering exclusions
      effectiveRule = _removeCountFromRule(rule);
    }

    // Determine effective end date (earliest of toUtc, untilUtc, maxLookAhead)
    var effectiveEnd = toUtc;
    if (untilUtc != null && untilUtc.isBefore(effectiveEnd)) {
      effectiveEnd = untilUtc;
    }
    if (config != null) {
      final maxEnd = startUtc.add(Duration(days: config.maxLookAheadDays));
      if (maxEnd.isBefore(effectiveEnd)) {
        effectiveEnd = maxEnd;
      }
    }

    // Get instances from the RRULE
    final instances = effectiveRule.getInstances(start: startUtc);

    // Collect occurrences within the range
    final occurrences = <DateTime>[];
    var hasMore = false;
    DateTime? lastOccurrence;
    var totalGenerated = 0; // Track total for COUNT enforcement

    for (final instance in instances) {
      // Stop if we've exceeded the effective end date
      if (instance.isAfter(effectiveEnd)) {
        hasMore = true;
        break;
      }

      // Skip excluded dates
      if (excludeSet != null && excludeSet.contains(instance)) {
        continue;
      }

      // Count this as a valid occurrence
      totalGenerated++;

      // Include if within the query range
      if (!instance.isBefore(fromUtc) && instance.isBefore(toUtc)) {
        occurrences.add(instance);
        lastOccurrence = instance;

        // Check limit
        if (occurrences.length >= maxOccurrences) {
          hasMore = true;
          break;
        }
      }

      // Enforce original COUNT (actual sessions, not calendar days)
      if (originalCount != null && totalGenerated >= originalCount) {
        // We've generated enough actual sessions
        break;
      }

      // Track if there are more occurrences after this range
      if (!instance.isBefore(toUtc) && !instance.isAfter(effectiveEnd)) {
        hasMore = true;
        break;
      }
    }

    return RruleExpansionResult(
      occurrences: occurrences,
      hasMore: hasMore,
      nextCursor: hasMore ? lastOccurrence : null,
    );
  }

  /// Creates a copy of the rule without COUNT to allow extended generation.
  RecurrenceRule _removeCountFromRule(RecurrenceRule rule) {
    // Rebuild the rule without COUNT
    return RecurrenceRule(
      frequency: rule.frequency,
      interval: rule.interval,
      until: rule.until,
      bySeconds: rule.bySeconds,
      byMinutes: rule.byMinutes,
      byHours: rule.byHours,
      byWeekDays: rule.byWeekDays,
      byMonthDays: rule.byMonthDays,
      byYearDays: rule.byYearDays,
      byWeeks: rule.byWeeks,
      byMonths: rule.byMonths,
      bySetPositions: rule.bySetPositions,
      weekStart: rule.weekStart,
      // count is intentionally omitted
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Gets the next N occurrences from a given start date.
  ///
  /// Useful for previewing upcoming occurrences without specifying an end date.
  ///
  /// **Note on COUNT and EXDATE behavior:**
  /// When the RRULE has COUNT and excludeDates are provided, the RRULE's COUNT
  /// represents actual sessions needed (not including excluded dates).
  List<DateTime> getNextOccurrences({
    required String rrule,
    required DateTime dtStart,
    required int count,
    DateTime? afterUtc,
    DateTime? untilUtc,
    List<DateTime>? excludeDates,
  }) {
    final rule = validate(rrule);
    final startUtc = dtStart.isUtc ? dtStart : dtStart.toUtc();
    final after = afterUtc ?? DateTime.now().toUtc();
    final excludeSet = excludeDates
        ?.map((d) => d.isUtc ? d : d.toUtc())
        .toSet();

    // Handle RRULE COUNT + EXDATE: extend generation if needed
    final originalCount = rule.count;
    final hasExclusions = excludeSet != null && excludeSet.isNotEmpty;
    var effectiveRule = rule;

    if (originalCount != null && hasExclusions) {
      effectiveRule = _removeCountFromRule(rule);
    }

    final instances = effectiveRule.getInstances(start: startUtc);
    final occurrences = <DateTime>[];
    var totalGenerated = 0;

    for (final instance in instances) {
      if (untilUtc != null && instance.isAfter(untilUtc)) {
        break;
      }

      // Skip excluded dates
      if (excludeSet != null && excludeSet.contains(instance)) {
        continue;
      }

      // Count towards RRULE's COUNT (if applicable)
      totalGenerated++;

      if (!instance.isBefore(after)) {
        occurrences.add(instance);
        if (occurrences.length >= count) {
          break;
        }
      }

      // Enforce RRULE's original COUNT (actual sessions)
      if (originalCount != null && totalGenerated >= originalCount) {
        break;
      }
    }

    return occurrences;
  }

  /// Checks if a specific DateTime is a valid occurrence of the RRULE.
  ///
  /// Useful for validating that an occurrence time is legitimate.
  bool isValidOccurrence({
    required String rrule,
    required DateTime dtStart,
    required DateTime occurrenceTimeUtc,
    DateTime? untilUtc,
    List<DateTime>? excludeDates,
  }) {
    final rule = validate(rrule);
    final startUtc = dtStart.isUtc ? dtStart : dtStart.toUtc();
    final targetUtc = occurrenceTimeUtc.isUtc
        ? occurrenceTimeUtc
        : occurrenceTimeUtc.toUtc();

    // Quick bounds check
    if (targetUtc.isBefore(startUtc)) {
      return false;
    }
    if (untilUtc != null && targetUtc.isAfter(untilUtc)) {
      return false;
    }

    // Check excluded dates
    if (excludeDates != null) {
      final excludeSet = excludeDates
          .map((d) => d.isUtc ? d : d.toUtc())
          .toSet();
      if (excludeSet.contains(targetUtc)) {
        return false;
      }
    }

    // Check if the occurrence is in the sequence
    // We search from the start until we pass the target time
    final instances = rule.getInstances(start: startUtc);

    for (final instance in instances) {
      if (instance.isAfter(targetUtc)) {
        // Passed the target without finding it
        return false;
      }
      if (instance.isAtSameMomentAs(targetUtc)) {
        return true;
      }
    }

    return false;
  }

  /// Converts an RRULE to a human-readable description.
  ///
  /// Returns a string like "Every week on Monday, Wednesday, Friday"
  String toHumanReadable(String rrule) {
    final rule = validate(rrule);

    // Build a simple human-readable description
    final parts = <String>[];

    // Frequency
    final freq = rule.frequency.toString().toLowerCase();
    final interval = rule.interval ?? 1;
    if (interval > 1) {
      parts.add('Every $interval ${freq}s');
    } else {
      parts.add(_frequencyToText(freq));
    }

    // Days of week
    if (rule.byWeekDays.isNotEmpty) {
      final days = rule.byWeekDays.map((e) => _dayName(e.day)).join(', ');
      parts.add('on $days');
    }

    // Count
    if (rule.count != null) {
      parts.add('${rule.count} times');
    }

    // Until
    if (rule.until != null) {
      final until = rule.until!;
      final mm = until.month.toString().padLeft(2, '0');
      final dd = until.day.toString().padLeft(2, '0');
      parts.add('until ${until.year}-$mm-$dd');
    }

    return parts.join(' ');
  }

  String _frequencyToText(String freq) {
    return switch (freq) {
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'monthly' => 'Monthly',
      'yearly' => 'Yearly',
      _ => 'Every $freq',
    };
  }

  String _dayName(int day) {
    return switch (day) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Day $day',
    };
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RRULE + EXDATE COMBINED FORMAT HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Parses a combined RRULE+EXDATE string into separate components.
  ///
  /// Input format (RFC 5545 multi-line):
  /// ```text
  /// FREQ=DAILY;COUNT=7
  /// EXDATE:20240115T090000Z,20240117T090000Z
  /// ```
  ///
  /// Or with RRULE prefix:
  /// ```text
  /// RRULE:FREQ=DAILY;COUNT=7
  /// EXDATE:20240115T090000Z,20240117T090000Z
  /// ```
  ///
  /// Returns a record of (rrule string without prefix, list of excluded dates).
  ///
  /// Example:
  /// ```dart
  /// final (rrule, exdates) = util.parseRruleWithExdates(
  ///   'FREQ=DAILY;COUNT=7\nEXDATE:20240115T090000Z',
  /// );
  /// // rrule = 'FREQ=DAILY;COUNT=7'
  /// // exdates = [DateTime.utc(2024, 1, 15, 9, 0, 0)]
  /// ```
  (String, List<DateTime>) parseRruleWithExdates(String combined) {
    if (combined.isEmpty) {
      return ('', <DateTime>[]);
    }

    final lines = combined.split('\n');
    var rrule = '';
    var exdates = <DateTime>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('RRULE:')) {
        rrule = trimmed.substring(6);
      } else if (trimmed.startsWith('FREQ=')) {
        rrule = trimmed;
      } else if (trimmed.startsWith('EXDATE:')) {
        exdates = parseExDates(trimmed);
      }
    }

    return (rrule, exdates);
  }

  /// Builds a combined RRULE+EXDATE string from components.
  ///
  /// Output format (RFC 5545 multi-line):
  /// ```text
  /// FREQ=DAILY;COUNT=7
  /// EXDATE:20240115T090000Z,20240117T090000Z
  /// ```
  ///
  /// If [exdates] is empty, returns the RRULE string unchanged.
  ///
  /// Example:
  /// ```dart
  /// final combined = util.buildRruleWithExdates(
  ///   'FREQ=DAILY;COUNT=7',
  ///   [DateTime.utc(2024, 1, 15, 9, 0, 0)],
  /// );
  /// // combined = 'FREQ=DAILY;COUNT=7\nEXDATE:20240115T090000Z'
  /// ```
  String buildRruleWithExdates(String rrule, List<DateTime> exdates) {
    if (exdates.isEmpty) return rrule;

    final sortedExdates = exdates.toList()..sort();
    final exdateStr = sortedExdates.map(_formatExdateUtc).join(',');
    return '$rrule\nEXDATE:$exdateStr';
  }

  /// Formats a DateTime to EXDATE format (yyyyMMddTHHmmssZ).
  String _formatExdateUtc(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}Z';
  }

  /// Parses EXDATE string from RRULE and returns list of excluded dates.
  ///
  /// EXDATE format: `EXDATE:20260115T000000Z,20260126T000000Z`
  /// or comma-separated dates in the RRULE.
  List<DateTime> parseExDates(String exdateString) {
    if (exdateString.isEmpty) {
      return [];
    }

    // Remove EXDATE: prefix if present
    final datesPart = exdateString.startsWith('EXDATE:')
        ? exdateString.substring(7)
        : exdateString;

    final dates = <DateTime>[];
    for (final dateStr in datesPart.split(',')) {
      final trimmed = dateStr.trim();
      if (trimmed.isEmpty) continue;

      try {
        // Parse ISO 8601 format (e.g., 20260115T000000Z)
        if (trimmed.contains('T')) {
          final year = int.parse(trimmed.substring(0, 4));
          final month = int.parse(trimmed.substring(4, 6));
          final day = int.parse(trimmed.substring(6, 8));
          final hour = int.parse(trimmed.substring(9, 11));
          final minute = int.parse(trimmed.substring(11, 13));
          final second = int.parse(trimmed.substring(13, 15));
          dates.add(DateTime.utc(year, month, day, hour, minute, second));
        } else {
          // Date only format (e.g., 20260115)
          final year = int.parse(trimmed.substring(0, 4));
          final month = int.parse(trimmed.substring(4, 6));
          final day = int.parse(trimmed.substring(6, 8));
          dates.add(DateTime.utc(year, month, day));
        }
      } on Object catch (_) {
        // Skip invalid date strings
      }
    }

    return dates;
  }
}
