import '../models/credit_account.dart';
import '../models/credit_account_state.dart';
import '../models/credit_entry.dart';
import '../models/entry_order.dart';
import '../models/pagination.dart';

/// A member's view of their own credit (`/mycredits`, #14).
///
/// Self or staff: a member reads their own accounts and statement through
/// the same calls an admin or coach uses to read them on the member's
/// behalf, so `username` is always explicit.
///
/// Every call throws `ModuleDisabledException` (503 `CREDIT_SYSTEM_DISABLED`)
/// on a deployment without the credit system.
abstract interface class MyCreditsSource {
  /// The member's accounts. Expired and empty accounts are included so the
  /// member can see where their credit went; closed ones only with
  /// [includeClosed]. [state] narrows to one state.
  Future<List<CreditAccount>> listMyAccounts(
    String username, {
    CreditAccountState? state,
    bool includeClosed = false,
  });

  /// One of the member's accounts. Throws `ServerException` with
  /// `CREDIT_ACCOUNT_NOT_FOUND` when the code is unknown or belongs to
  /// someone else.
  Future<CreditAccount> getMyAccount(String username, String accountId);

  /// The member's statement: which occurrence took what from which account,
  /// oldest first unless [order] says otherwise. Each entry carries the
  /// running `balanceAfter` and `totalAfter`, independent of the filters
  /// and page.
  Future<PaginatedList<CreditEntry>> listMyEntries(
    String username, {
    String? accountId,
    int? eventId,
    DateTime? fromUtc,
    DateTime? toUtc,
    EntryOrder? order,
    int offset = 0,
    int limit = 50,
  });
}
