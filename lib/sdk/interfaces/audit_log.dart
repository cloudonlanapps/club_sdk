// A single-method Source kept as an interface for consistency with the SDK's
// one-interface-per-domain architecture (see the other `*Source` types).
// ignore_for_file: one_member_abstracts
import '../models/audit_log.dart';

/// Read-only access to the server audit log (`GET /v1/audit_log`).
///
/// The endpoint has two access modes that share this one method:
///
/// - **Global feed** — no scope params (`username`, `resourceType` and
///   `resourceId` all null): super-admin only, the full unfiltered history.
/// - **Entity-scoped** — pass `username` (a user, matched as actor *or*
///   target) or `resourceType`+`resourceId` together (an event / group /
///   venue): allowed for any admin or coach, regardless of ownership.
///
/// `verbose` widens an entity scope: `1` = the entity's own rows (default),
/// `2` = also its media-link rows, `3` = also its occurrence rows (events
/// only). It is ignored for the global feed and the username scope.
abstract interface class AuditLogSource {
  /// List audit rows newest-first.
  ///
  /// [resourceType] and [resourceId] must be supplied together or the server
  /// returns 422.
  Future<AuditLogPage> list({
    int offset = 0,
    int limit = 50,
    String? actor,
    String? action,
    int? fromTsUtc,
    int? toTsUtc,
    String? username,
    String? resourceType,
    String? resourceId,
    int verbose = 1,
  });
}
