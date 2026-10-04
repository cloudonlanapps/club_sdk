import 'package:meta/meta.dart';

/// The credit system's routes (#14): `/credits` for staff, `/mycredits`
/// for a member's own view, and the one roster a programme owns.
@immutable
class CreditEndpoints {
  const CreditEndpoints();

  String get accounts => '/credits/accounts';
  String account(String accountId) => '/credits/accounts/$accountId';
  String extend(String accountId) => '/credits/accounts/$accountId/extend';
  String reverse(String accountId) => '/credits/accounts/$accountId/reverse';
  String transfer(String accountId) => '/credits/accounts/$accountId/transfer';
  String get entries => '/credits/entries';
  String eventCredits(int eventId) => '/events/by_id/$eventId/credits';

  String myAccounts(String username) => '/mycredits/by_id/$username';
  String myAccount(String username, String accountId) =>
      '/mycredits/by_id/$username/accounts/$accountId';
  String myEntries(String username) => '/mycredits/by_id/$username/entries';
}
