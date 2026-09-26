import '../models/credit_account.dart';
import '../models/credit_account_kind.dart';
import '../models/credit_account_state.dart';
import '../models/credit_entry.dart';
import '../models/credit_entry_type.dart';
import '../models/credit_transfer_result.dart';
import '../models/entry_order.dart';
import '../models/member_credit_status.dart';
import '../models/pagination.dart';
import '../models/roster_credit_filter.dart';

/// Staff-side credit operations (`/credits`, #14).
///
/// Writes are admin-only; the listings and the programme roster are open to
/// coaches too. A member reads their own credit through `MyCreditsSource`.
///
/// Credit applies to programmes only. There is no top-up, no edit and no
/// delete: balances derive from an append-only ledger, so more credit means
/// a new account and a correction means a reversal. Deduction and refund
/// have no calls here either — they happen when attendance is marked,
/// cleared, or leave is approved or rejected.
///
/// Every call throws `ModuleDisabledException` (503 `CREDIT_SYSTEM_DISABLED`)
/// on a deployment without the credit system; read
/// `CapabilitiesSource.getCapabilities().creditSystem` once after login
/// instead of probing.
abstract interface class CreditSource {
  // ══════════════════════════════════════════════════════════════════════════
  // ACCOUNT LIFECYCLE (ADMIN)
  // ══════════════════════════════════════════════════════════════════════════

  /// Opens an account holding [credits] for [membername].
  ///
  /// Bound to the programme [eventId] when given, general otherwise. A
  /// trial account funds trial enrollments only. Throws `ServerException`
  /// with `CREDIT_NOT_APPLICABLE` for a camp or one-off,
  /// `INVALID_CREDIT_AMOUNT` unless [credits] is a positive whole number,
  /// and `INVALID_VALIDITY_WINDOW` when the window ends before it starts or
  /// lies wholly in the past. Opening an account for a blocked member
  /// restores them at once.
  ///
  /// [membername] may be any existing user, whatever their account status
  /// (registered, pending, active, blocked or left), so credit can be
  /// recorded before approval. An unknown username throws
  /// `ServerException(404, USER_NOT_FOUND)`.
  Future<CreditAccount> openAccount({
    required String membername,
    required int credits,
    required DateTime validFromUtc,
    required DateTime validUntilUtc,
    required String reason,
    int? eventId,
    bool isTrial = false,
  });

  /// Looks an account up by its code alone. Throws `ServerException` with
  /// `CREDIT_ACCOUNT_NOT_FOUND`.
  Future<CreditAccount> getAccount(String accountId);

  /// Searches accounts. Admin or coach.
  ///
  /// [expiringBeforeUtc] keeps accounts whose validity ends before it.
  Future<PaginatedList<CreditAccount>> listAccounts({
    String? membername,
    int? eventId,
    CreditAccountKind? kind,
    CreditAccountState? state,
    bool? isTrial,
    DateTime? expiringBeforeUtc,
    int offset = 0,
    int limit = 50,
  });

  /// Moves an account's validity end to [validUntilUtc]. The ledger gains a
  /// `validityExtended` entry of amount zero.
  Future<CreditAccount> extendValidity(
    String accountId, {
    required DateTime validUntilUtc,
    required String reason,
  });

  /// Undoes a mistaken grant: [credits] of it, or the whole remaining
  /// balance when null. Throws `ServerException` with `INSUFFICIENT_BALANCE`
  /// when more is reversed than remains unspent, and `ACCOUNT_CLOSED` on a
  /// closed account.
  Future<CreditAccount> reverseGrant(
    String accountId, {
    required String reason,
    int? credits,
  });

  /// Closes the account and moves what survives [penalty] into a new
  /// general account valid over the given window.
  ///
  /// There is no destination to choose: accounts are never topped up, so
  /// the operation creates the one it transfers into. `created` is null
  /// when the penalty consumed the balance. A penalty of zero is ordinary.
  /// This one call serves expiry disposition, voluntary drop-out and admin
  /// removal; they differ only in the penalty.
  Future<CreditTransferResult> transfer(
    String accountId, {
    required int penalty,
    required DateTime validFromUtc,
    required DateTime validUntilUtc,
    required String reason,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // LEDGER AND ROSTER (ADMIN OR COACH)
  // ══════════════════════════════════════════════════════════════════════════

  /// The ledger across accounts, oldest first unless [order] says
  /// otherwise. Each entry carries the running `balanceAfter` and
  /// `totalAfter`, independent of the filters and page.
  Future<PaginatedList<CreditEntry>> listEntries({
    String? membername,
    String? accountId,
    int? eventId,
    CreditEntryType? entryType,
    DateTime? occurrenceTimeUtc,
    DateTime? fromUtc,
    DateTime? toUtc,
    EntryOrder? order,
    int offset = 0,
    int limit = 50,
  });

  /// Who on programme [eventId] can be marked, and whose departure needs a
  /// `CreditDisposition`: one row per enrolled member with their usable
  /// and bound credit, the account that would pay, and whether they are
  /// blocked.
  ///
  /// Enrolled includes members who asked to withdraw
  /// (`EnrollmentStatus.withdrawRequested`): until the withdrawal is
  /// approved they can still be marked and charged. Members who are only
  /// invited are not on it. [filter] narrows the rows;
  /// [RosterCreditFilter.expiringSoon] uses [expiringBeforeUtc].
  Future<PaginatedList<MemberCreditStatus>> listEventCredits(
    int eventId, {
    RosterCreditFilter? filter,
    DateTime? expiringBeforeUtc,
    int offset = 0,
    int limit = 50,
  });
}
