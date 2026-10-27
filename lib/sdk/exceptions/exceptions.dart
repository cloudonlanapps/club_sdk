/// SDK Exception Classes
///
/// Two concrete types:
/// - [ServerException] — errors from the server (HTTP 4xx/5xx responses)
/// - [SdkError] — client-side errors caught before making an HTTP call
///
/// Both carry a `code` string for programmatic branching and a `message`
/// string for display. See `SdkErrorCode` for all known code constants.
library;

import '../models/application_missing_text.dart';
import '../models/application_unknown_gap.dart';
import '../models/conflict_report.dart';
import 'error_codes.dart';

// ═════════════════════════════════════════════════════════════════════════════
// BASE EXCEPTION
// ═════════════════════════════════════════════════════════════════════════════

/// Base class for all SDK exceptions.
abstract class SdkException implements Exception {
  const SdkException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

// ═════════════════════════════════════════════════════════════════════════════
// HTTP EXCEPTION (from server)
// ═════════════════════════════════════════════════════════════════════════════

/// An error response from the server.
///
/// Check [statusCode] for the HTTP status category (400, 401, 403, 404, 409,
/// 422, 5xx). Check [code] for the specific error (e.g., `DUPLICATE_USERNAME`).
/// Display [message] to the user.
class ServerException extends SdkException {
  const ServerException({
    required this.statusCode,
    required String code,
    required String message,
    this.details,
  }) : super(message, code: code);

  /// The key of [details] under which a schema rejection names the fields
  /// the server refused.
  static const refusedFieldsKey = 'fields';

  final int statusCode;

  /// What the server sent beside `code` and `message`, when it sent
  /// anything. Used for error codes that carry contextual data (e.g.
  /// `MEMBERS_INELIGIBLE` carries `membernames`).
  ///
  /// A schema rejection (422 `VALIDATION_ERROR`) carries one entry here,
  /// [refusedFieldsKey]: a list with a map for each field the server
  /// refused, in the server's order. Each map holds `loc`, the path to the
  /// field (`['body', 'email']`, or `['body', 'timetable', 1, 'startMinute']`
  /// for a nested one), `msg`, the reason, and `type`, the server's name for
  /// the rule. The value that was sent is not kept.
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ServerException($statusCode): [$code] $message';
}

/// 409 `STALE_VERSION`: the event, occurrence or marketing block was
/// changed since the caller loaded it (club_server#292, #25; occurrences
/// club_server#430, #1; cutoff verbs and marketing club_server#13, #1).
///
/// Carries its current [version], and when it was changed and by whom, so
/// an app can tell the user before reloading. An occurrence nobody has
/// changed, and an event with no marketing block, is at version 1 with no
/// [updatedAtUtc] or [updatedBy].
class StaleVersionException extends ServerException {
  const StaleVersionException({
    required super.message,
    required this.version,
    this.updatedAtUtc,
    this.updatedBy,
    super.details,
  }) : super(statusCode: 409, code: SdkErrorCode.staleVersion);

  /// Builds from the server's error object (`detail`), whose extra fields
  /// are `version`, `updatedAt` (epoch ms) and `updatedBy`.
  factory StaleVersionException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) {
    final updatedAt = details?['updatedAt'];
    return StaleVersionException(
      message: message,
      version: (details?['version'] as int?) ?? 0,
      updatedAtUtc: updatedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true)
          : null,
      updatedBy: details?['updatedBy'] as String?,
      details: details,
    );
  }

  /// The current version of the event, occurrence or marketing block.
  final int version;

  /// When it was last changed, or null when it never has been.
  final DateTime? updatedAtUtc;

  /// Who last changed it, or null when unknown.
  final String? updatedBy;

  @override
  String toString() =>
      'StaleVersionException(version: $version, updatedBy: $updatedBy): '
      '$message';
}

/// 409 `SCHEDULE_CONFLICT`: a schedule or staff write clashes with other
/// events and was sent without `acceptConflicts: true` (club_server#72,
/// #56). Nothing was written.
///
/// Raised by `EventSource.createEvent`, `updateEvent` (an organizer or coach
/// change), `updateEventForAllFuture`, `rescheduleEvent`, `reinstate` and
/// `OccurrenceSource.rescheduleOccurrence`. [report] names every clashing
/// event by gate — venue, organizer and coach — with the overlapping
/// occurrence pairs, in the shape `EventSource.checkConflict` returns. Show
/// it to the organizer, and re-send the same call with
/// `acceptConflicts: true` to save anyway; the server then notifies the
/// admins.
class ScheduleConflictException extends ServerException {
  const ScheduleConflictException({
    required super.message,
    required this.report,
    super.details,
  }) : super(statusCode: 409, code: SdkErrorCode.scheduleConflict);

  /// Builds from the server's error object (`detail`), whose extra fields
  /// are `venueConflicts`, `organizerConflicts` and `coachConflicts`.
  factory ScheduleConflictException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) {
    return ScheduleConflictException(
      message: message,
      report: ConflictReport.fromMap(details ?? const {}),
      details: details,
    );
  }

  /// The clashes the server found, by gate.
  final ConflictReport report;

  @override
  String toString() => 'ScheduleConflictException($report): $message';
}

/// 422 `INVALID_PROFILE_OPTION`: a profile edit put a value in
/// `preferredPositions` or `preferredLanguages` that is not one of the
/// club's profile options (club_server#92, #106, #66, #75). Nothing was
/// written.
///
/// [field] is the server's name of the refused field and [value] what was
/// sent. A value already stored is never refused, even when its option has
/// since been removed.
class InvalidProfileOptionException extends ServerException {
  const InvalidProfileOptionException({
    required super.message,
    this.field,
    this.value,
    super.details,
  }) : super(statusCode: 422, code: SdkErrorCode.invalidProfileOption);

  /// Builds from the server's error object (`detail`), whose extra fields
  /// are `field` and `value`.
  factory InvalidProfileOptionException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) {
    final field = details?['field'];
    final value = details?['value'];
    return InvalidProfileOptionException(
      message: message,
      field: field is String ? field : null,
      value: value is String ? value : null,
      details: details,
    );
  }

  /// The refused field (`preferredPositions` or `preferredLanguages`).
  final String? field;

  /// The refused value: the first entry of the list that is not one of the
  /// club's options.
  final String? value;

  @override
  String toString() =>
      'InvalidProfileOptionException(field: $field, value: $value): '
      '$message';
}

/// The `details` object inside the server's error, where the application
/// routers put their structured fields (`{"code", "message", "details"}`).
Map<String, dynamic>? applicationErrorDetails(Map<String, dynamic>? details) {
  final inner = details?['details'];
  return inner is Map<String, dynamic> ? inner : null;
}

/// 422 `APPLICATION_INCOMPLETE`: saving an application template found
/// texts the form needs missing, or without a print language
/// (club_server#93, R9; #101). The template stays a draft.
///
/// [missing] names each text by its API path (`title`, `formFooter`,
/// `terms[1].heading`, …) with the print languages it lacks.
class ApplicationIncompleteException extends ServerException {
  const ApplicationIncompleteException({
    required super.message,
    this.missing = const [],
    super.details,
  }) : super(statusCode: 422, code: SdkErrorCode.applicationIncomplete);

  /// Builds from the server's error object, whose `details` carry
  /// `missing: [{field, languages}]`. An entry of another shape is skipped.
  factory ApplicationIncompleteException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) {
    final missing = applicationErrorDetails(details)?['missing'];
    return ApplicationIncompleteException(
      message: message,
      missing: missing is List
          ? List<ApplicationMissingText>.unmodifiable([
              for (final m in missing)
                if (m is Map<String, dynamic> && m['field'] is String)
                  ApplicationMissingText.fromMap(m),
            ])
          : const [],
      details: details,
    );
  }

  /// Each text missing print languages, with the languages it lacks.
  final List<ApplicationMissingText> missing;

  /// The API paths of the [missing] texts.
  List<String> get fields => [for (final m in missing) m.field];

  @override
  String toString() =>
      'ApplicationIncompleteException(missing: $missing): $message';
}

/// 422 `APPLICATION_UNKNOWN_FACT`: saving an application template found
/// `{gap}`s in its printed texts naming no fact of the template
/// (club_server#126). The template stays a draft.
///
/// [gaps] come in print order, each with the text's place, its language
/// and the gap's name; a gap repeated in one text is listed once.
class ApplicationUnknownFactException extends ServerException {
  const ApplicationUnknownFactException({
    required super.message,
    this.gaps = const [],
    super.details,
  }) : super(statusCode: 422, code: SdkErrorCode.applicationUnknownFact);

  /// Builds from the server's error object, whose `details` carry
  /// `gaps: [{place, language, gap}]`. An entry of another shape is
  /// skipped.
  factory ApplicationUnknownFactException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) {
    final gaps = applicationErrorDetails(details)?['gaps'];
    return ApplicationUnknownFactException(
      message: message,
      gaps: gaps is List
          ? List<ApplicationUnknownGap>.unmodifiable([
              for (final g in gaps)
                if (g is Map<String, dynamic> &&
                    g['place'] is String &&
                    g['language'] is String &&
                    g['gap'] is String)
                  ApplicationUnknownGap.fromMap(g),
            ])
          : const [],
      details: details,
    );
  }

  /// Each gap naming no fact, where it is and in which language.
  final List<ApplicationUnknownGap> gaps;

  @override
  String toString() => 'ApplicationUnknownFactException(gaps: $gaps): $message';
}

/// The `categories` of an application error's `details`: the indexes of
/// the age categories the member fits (club_server#108). Empty when the
/// server sent none.
List<int> applicationErrorCategories(Map<String, dynamic>? details) {
  final categories = applicationErrorDetails(details)?['categories'];
  return categories is List
      ? List<int>.unmodifiable(categories.whereType<int>())
      : const [];
}

/// 422 `APPLICATION_CATEGORY_REQUIRED`: the member fits several age
/// categories of the template and the download named none
/// (club_server#108). Download again with one of [categories] as
/// `category`.
class ApplicationCategoryRequiredException extends ServerException {
  const ApplicationCategoryRequiredException({
    required super.message,
    this.categories = const [],
    super.details,
  }) : super(statusCode: 422, code: SdkErrorCode.applicationCategoryRequired);

  /// Builds from the server's error object, whose `details` carry
  /// `categories`.
  factory ApplicationCategoryRequiredException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) => ApplicationCategoryRequiredException(
    message: message,
    categories: applicationErrorCategories(details),
    details: details,
  );

  /// The indexes of the age categories the member fits.
  final List<int> categories;

  @override
  String toString() =>
      'ApplicationCategoryRequiredException(categories: $categories): '
      '$message';
}

/// 422 `APPLICATION_CATEGORY_NOT_FITTING`: the download named an age
/// category the member does not fit (club_server#108). [categories] are
/// the ones they do fit.
class ApplicationCategoryNotFittingException extends ServerException {
  const ApplicationCategoryNotFittingException({
    required super.message,
    this.categories = const [],
    super.details,
  }) : super(
         statusCode: 422,
         code: SdkErrorCode.applicationCategoryNotFitting,
       );

  /// Builds from the server's error object, whose `details` carry
  /// `categories`.
  factory ApplicationCategoryNotFittingException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) => ApplicationCategoryNotFittingException(
    message: message,
    categories: applicationErrorCategories(details),
    details: details,
  );

  /// The indexes of the age categories the member fits.
  final List<int> categories;

  @override
  String toString() =>
      'ApplicationCategoryNotFittingException(categories: $categories): '
      '$message';
}

/// 422 `APPLICATION_DOES_NOT_FIT`: the member's details alone do not fit
/// page 1 of the form, so the template cannot be saved (club_server#93,
/// R17) — usually too many age categories. It stays a draft.
class ApplicationDoesNotFitException extends ServerException {
  const ApplicationDoesNotFitException({
    required super.message,
    this.overflowPt,
    super.details,
  }) : super(statusCode: 422, code: SdkErrorCode.applicationDoesNotFit);

  /// Builds from the server's error object, whose `details` carry
  /// `overflowPt`.
  factory ApplicationDoesNotFitException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) {
    final overflow = applicationErrorDetails(details)?['overflowPt'];
    return ApplicationDoesNotFitException(
      message: message,
      overflowPt: overflow is num ? overflow.toDouble() : null,
      details: details,
    );
  }

  /// How far page 1 overflows, in points.
  final double? overflowPt;

  @override
  String toString() =>
      'ApplicationDoesNotFitException(overflowPt: $overflowPt): $message';
}

/// 503 from an optional module that is off on this deployment
/// (`CREDIT_SYSTEM_DISABLED`, `EVALUATIONS_DISABLED`,
/// `EVENT_MARKETING_DISABLED`, `EXTENDED_PROFILE_DISABLED`,
/// `APPLICATIONS_DISABLED`).
///
/// Every module route stays registered on every deployment, so this is how
/// a call into an absent module fails. Apps should not reach it: read
/// `CapabilitiesSource.getCapabilities()` after login and hide the feature.
class ModuleDisabledException extends ServerException {
  const ModuleDisabledException({
    required super.code,
    required super.message,
    super.details,
  }) : super(statusCode: 503);

  @override
  String toString() => 'ModuleDisabledException: [$code] $message';
}

// ═════════════════════════════════════════════════════════════════════════════
// SDK ERROR (client-side)
// ═════════════════════════════════════════════════════════════════════════════

/// A client-side error caught before making an HTTP call.
///
/// Used for local validation (e.g., invalid RRULE, bad user status).
/// Check [code] for the specific error. Display [message] to the user.
class SdkError extends SdkException {
  const SdkError(super.message, {required String super.code});

  @override
  String toString() => 'SdkError: [$code] $message';
}
