/// Derived lifecycle state of a credit account (#14).
///
/// Ordered by precedence on the server: [closed] wins, then [expired],
/// then [empty], then [usable]. Never stored — computed from the validity
/// window and the ledger balance.
enum CreditAccountState {
  /// Inside its validity window with a positive balance.
  usable('usable'),

  /// Inside its window but the balance is zero.
  empty('empty'),

  /// The validity window has ended; the balance survives (expiry never
  /// destroys credit).
  expired('expired'),

  /// Closed by a transfer; nothing further can happen to it.
  closed('closed');

  const CreditAccountState(this.wireName);

  /// The value the server sends and accepts as a filter.
  final String wireName;

  /// Parses a wire value; an unknown value reads as [closed], the state
  /// in which nothing can be spent, so a misread never over-promises.
  static CreditAccountState fromWire(String wire) {
    for (final v in CreditAccountState.values) {
      if (v.wireName == wire) return v;
    }
    return CreditAccountState.closed;
  }
}
