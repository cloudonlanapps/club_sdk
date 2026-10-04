/// Narrows a programme's credit roster (`CreditSource.listEventCredits`).
///
/// The roster understands these two filters only; it is not a list of
/// accounts, so `CreditAccountState` does not apply to it.
enum RosterCreditFilter {
  /// Members with no usable credit: enrolled, but they cannot be marked.
  blocked('blocked'),

  /// Members whose paying credit lapses before the `expiringBeforeUtc`
  /// given with the filter. Without that bound nobody matches.
  expiringSoon('expiringSoon');

  const RosterCreditFilter(this.wireName);

  /// The value the server accepts as the roster's `state` parameter.
  final String wireName;
}
