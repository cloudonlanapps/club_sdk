/// SDK Exception Classes
///
/// Two concrete types:
/// - [ServerException] — errors from the server (HTTP 4xx/5xx responses)
/// - [SdkError] — client-side errors caught before making an HTTP call
///
/// Both carry a `code` string for programmatic branching and a `message`
/// string for display. See `SdkErrorCode` for all known code constants.
library;

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

  final int statusCode;

  /// Structured payload from the server's `detail.details` object, when
  /// present. Used for error codes that carry contextual data (e.g.
  /// `MEMBERS_INELIGIBLE` carries `membernames`).
  final Map<String, dynamic>? details;

  @override
  String toString() => 'ServerException($statusCode): [$code] $message';
}

/// 409 `STALE_VERSION`: the event or occurrence was changed since the
/// caller loaded it (club_server#292, #25; occurrences club_server#430, #1).
///
/// Carries its current [version], and when it was changed and by whom, so
/// an app can tell the user before reloading. An occurrence nobody has
/// changed is at version 1 with no [updatedAtUtc] or [updatedBy].
class StaleVersionException extends ServerException {
  const StaleVersionException({
    required super.message,
    required this.version,
    this.updatedAtUtc,
    this.updatedBy,
    super.details,
  }) : super(statusCode: 409, code: 'STALE_VERSION');

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

  /// The current version of the event or occurrence.
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

/// 503 from an optional module that is off on this deployment
/// (`CREDIT_SYSTEM_DISABLED`, `EVALUATIONS_DISABLED`,
/// `EVENT_MARKETING_DISABLED`).
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
