import '../../sdk/interfaces/my_credits.dart';
import '../../sdk/models/credit_account.dart';
import '../../sdk/models/credit_account_state.dart';
import '../../sdk/models/credit_entry.dart';
import '../../sdk/models/entry_order.dart';
import '../../sdk/models/pagination.dart';
import '../endpoints/endpoints.dart';
import '../remote_store.dart';

/// Remote implementation of [MyCreditsSource] using HTTP API.
class RemoteMyCreditsSource implements MyCreditsSource {
  RemoteMyCreditsSource(this._store);

  final RemoteStore _store;

  @override
  Future<List<CreditAccount>> listMyAccounts(
    String username, {
    CreditAccountState? state,
    bool includeClosed = false,
  }) async {
    final response = await _store.getList(
      endpoints.credits.myAccounts(username),
      queryParams: {
        if (state != null) 'state': state.wireName,
        'includeClosed': includeClosed.toString(),
      },
    );
    return response
        .map((item) => CreditAccount.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CreditAccount> getMyAccount(String username, String accountId) async {
    final response = await _store.get(
      endpoints.credits.myAccount(username, accountId),
    );
    return CreditAccount.fromMap(response);
  }

  @override
  Future<PaginatedList<CreditEntry>> listMyEntries(
    String username, {
    String? accountId,
    int? eventId,
    DateTime? fromUtc,
    DateTime? toUtc,
    EntryOrder? order,
    int offset = 0,
    int limit = 50,
  }) async {
    final response = await _store.get(
      endpoints.credits.myEntries(username),
      queryParams: {
        'accountId': ?accountId,
        if (eventId != null) 'eventId': eventId.toString(),
        if (fromUtc != null)
          'fromTs': fromUtc.millisecondsSinceEpoch.toString(),
        if (toUtc != null) 'toTs': toUtc.millisecondsSinceEpoch.toString(),
        if (order != null) 'order': order.wireName,
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    return PaginatedList.fromMap(response, CreditEntry.fromMap);
  }
}
