import '../models/broadcast.dart';
import '../models/pagination.dart';

/// Admin-only broadcast operations.
///
/// Broadcasts fan out into per-recipient notification rows server-side; the
/// recipients see them via the regular `/notifications` feed. These methods
/// cover the authoring and reporting surface.
abstract interface class BroadcastSource {
  /// Create a broadcast and fan it out synchronously.
  ///
  /// When [email] is true the broadcast is also delivered by email and
  /// [emailSubject] and [emailBody] are required; [emailBody] is rendered as
  /// markdown. The server is the judge of this rule: a request without them
  /// is sent, and the server's 422 surfaces as a `ServerException`, the same
  /// in debug and release builds (#35).
  Future<Broadcast> createBroadcast({
    required AudienceSelector audienceSelector,
    required Map<String, dynamic> payload,
    DateTime? expiresAtUtc,
    bool email = false,
    String? emailSubject,
    String? emailBody,
  });

  /// List broadcasts newest-first.
  Future<PaginatedList<Broadcast>> listBroadcasts({
    int offset = 0,
    int limit = 20,
  });

  /// Get a single broadcast with `readCount` / `unreadCount` populated.
  Future<Broadcast> getBroadcast(int id);

  /// List a broadcast's recipients. Pass [statusFilter] = `read` or `unread`
  /// to narrow the listing.
  Future<PaginatedList<BroadcastRecipient>> listRecipients(
    int id, {
    String? statusFilter,
    int offset = 0,
    int limit = 50,
  });

  /// Revoke a broadcast. Deletes the fan-out notifications; the broadcast row
  /// itself is preserved for audit and returned with `status = revoked`.
  Future<Broadcast> revokeBroadcast(int id);
}
