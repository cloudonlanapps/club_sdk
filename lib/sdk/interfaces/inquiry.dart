import '../models/inquiry.dart';
import '../models/inquiry_kind.dart';
import '../models/pagination.dart';

/// The admin inquiry inbox (`/admin/inquiries`, club_server#407, #35).
///
/// Rows arrive from the unauthenticated form on `PublicSource`. Admin
/// only; every write is audited. There is no soft delete: an inquiry is
/// PII, so removing it removes it.
abstract interface class InquirySource {
  /// The inbox, newest first. [kind] and [handled] narrow it; [limit] is
  /// 1–100, default 20.
  Future<PaginatedList<Inquiry>> listInquiries({
    InquiryKind? kind,
    bool? handled,
    int offset = 0,
    int limit = 20,
  });

  /// Marks [id] handled by the caller, now, or reopens it when [handled]
  /// is false — which clears both the stamp and the handler.
  Future<Inquiry> setInquiryHandled(int id, {required bool handled});

  /// Removes the row permanently.
  Future<void> deleteInquiry(int id);
}
