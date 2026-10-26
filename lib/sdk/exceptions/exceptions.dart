/// SDK Exception Classes
///
/// Two concrete types:
/// - [ServerException] — errors from the server (HTTP 4xx/5xx responses)
/// - [SdkError] — client-side errors caught before making an HTTP call
///
/// Both carry a `code` string for programmatic branching and a `message`
/// string for display. See `SdkErrorCode` for all known code constants.
library;

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

/// 422 `INVALID_PROFILE_OPTION`: a profile edit set `preferredPosition` or
/// `preferredLanguage` to a value that is not one of the club's profile
/// options (club_server#92, #66). Nothing was written.
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

  /// The refused field (`preferredPosition` or `preferredLanguage`).
  final String? field;

  /// The value that was sent.
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

/// 422 `APPLICATION_INCOMPLETE`: saving an application template found a
/// text the form needs missing, or without a print language
/// (club_server#93, R9). The template stays a draft.
///
/// [missing] names each text (`title`, `declaration`, `formFooter`,
/// `terms[1]`, …) and [language] the print language they lack.
class ApplicationIncompleteException extends ServerException {
  const ApplicationIncompleteException({
    required super.message,
    this.missing = const [],
    this.language,
    super.details,
  }) : super(statusCode: 422, code: SdkErrorCode.applicationIncomplete);

  /// Builds from the server's error object, whose `details` carry
  /// `missing` and `language`.
  factory ApplicationIncompleteException.fromDetails(
    String message,
    Map<String, dynamic>? details,
  ) {
    final inner = applicationErrorDetails(details);
    final missing = inner?['missing'];
    final language = inner?['language'];
    return ApplicationIncompleteException(
      message: message,
      missing: missing is List
          ? List<String>.unmodifiable(missing.whereType<String>())
          : const [],
      language: language is String ? language : null,
      details: details,
    );
  }

  /// The texts that are missing or lack [language].
  final List<String> missing;

  /// The print language they lack.
  final String? language;

  @override
  String toString() =>
      'ApplicationIncompleteException(missing: $missing, '
      'language: $language): $message';
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
