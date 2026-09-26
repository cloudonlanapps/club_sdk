import '../../sdk/interfaces/credit.dart';
import '../../sdk/models/credit_account.dart';
import '../../sdk/models/credit_account_kind.dart';
import '../../sdk/models/credit_account_state.dart';
import '../../sdk/models/credit_entry.dart';
import '../../sdk/models/credit_entry_type.dart';
import '../../sdk/models/credit_transfer_result.dart';
import '../../sdk/models/member_credit_status.dart';
import '../../sdk/models/pagination.dart';
import '../../sdk/models/roster_credit_filter.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [CreditSource] using HTTP API.
class RemoteCreditSource implements CreditSource {
  RemoteCreditSource(this._store);

  final RemoteStore _store;

  @override
  Future<CreditAccount> openAccount({
    required String membername,
    required int credits,
    required DateTime validFromUtc,
    required DateTime validUntilUtc,
    required String reason,
    int? eventId,
    bool isTrial = false,
  }) async {
    final response = await _store.post(
      endpoints.credits.accounts,
      body: {
        'membername': membername,
        'credits': credits,
        'validFromUtc': validFromUtc.millisecondsSinceEpoch,
        'validUntilUtc': validUntilUtc.millisecondsSinceEpoch,
        'reason': reason,
        'eventId': ?eventId,
        'isTrial': isTrial,
      },
    );
    return CreditAccount.fromMap(response);
  }

  @override
  Future<CreditAccount> getAccount(String accountId) async {
    final response = await _store.get(endpoints.credits.account(accountId));
    return CreditAccount.fromMap(response);
  }

  @override
  Future<PaginatedList<CreditAccount>> listAccounts({
    String? membername,
    int? eventId,
    CreditAccountKind? kind,
    CreditAccountState? state,
    bool? isTrial,
    DateTime? expiringBeforeUtc,
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await _store.get(
      endpoints.credits.accounts,
      queryParams: {
        'membername': ?membername,
        if (eventId != null) 'eventId': eventId.toString(),
        if (kind != null) 'kind': kind.wireName,
        if (state != null) 'state': state.wireName,
        if (isTrial != null) 'isTrial': isTrial.toString(),
        if (expiringBeforeUtc != null)
          'expiringBeforeUtc': expiringBeforeUtc.millisecondsSinceEpoch
              .toString(),
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, CreditAccount.fromMap);
  }

  @override
  Future<CreditAccount> extendValidity(
    String accountId, {
    required DateTime validUntilUtc,
    required String reason,
  }) async {
    final response = await _store.post(
      endpoints.credits.extend(accountId),
      body: {
        'validUntilUtc': validUntilUtc.millisecondsSinceEpoch,
        'reason': reason,
      },
    );
    return CreditAccount.fromMap(response);
  }

  @override
  Future<CreditAccount> reverseGrant(
    String accountId, {
    required String reason,
    int? credits,
  }) async {
    final response = await _store.post(
      endpoints.credits.reverse(accountId),
      body: {'reason': reason, 'credits': ?credits},
    );
    return CreditAccount.fromMap(response);
  }

  @override
  Future<CreditTransferResult> transfer(
    String accountId, {
    required int penalty,
    required DateTime validFromUtc,
    required DateTime validUntilUtc,
    required String reason,
  }) async {
    final response = await _store.post(
      endpoints.credits.transfer(accountId),
      body: {
        'penalty': penalty,
        'validFromUtc': validFromUtc.millisecondsSinceEpoch,
        'validUntilUtc': validUntilUtc.millisecondsSinceEpoch,
        'reason': reason,
      },
    );
    return CreditTransferResult.fromMap(response);
  }

  @override
  Future<PaginatedList<CreditEntry>> listEntries({
    String? membername,
    String? accountId,
    int? eventId,
    CreditEntryType? entryType,
    DateTime? occurrenceTimeUtc,
    DateTime? fromUtc,
    DateTime? toUtc,
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await _store.get(
      endpoints.credits.entries,
      queryParams: {
        'membername': ?membername,
        'accountId': ?accountId,
        if (eventId != null) 'eventId': eventId.toString(),
        if (entryType != null) 'entryType': entryType.wireName,
        if (occurrenceTimeUtc != null)
          'occurrenceTimeUtc': occurrenceTimeUtc.millisecondsSinceEpoch
              .toString(),
        if (fromUtc != null)
          'fromTs': fromUtc.millisecondsSinceEpoch.toString(),
        if (toUtc != null) 'toTs': toUtc.millisecondsSinceEpoch.toString(),
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, CreditEntry.fromMap);
  }

  @override
  Future<PaginatedList<MemberCreditStatus>> listEventCredits(
    int eventId, {
    RosterCreditFilter? filter,
    DateTime? expiringBeforeUtc,
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await _store.get(
      endpoints.credits.eventCredits(eventId),
      queryParams: {
        if (filter != null) 'state': filter.wireName,
        if (expiringBeforeUtc != null)
          'expiringBeforeUtc': expiringBeforeUtc.millisecondsSinceEpoch
              .toString(),
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, MemberCreditStatus.fromMap);
  }
}
