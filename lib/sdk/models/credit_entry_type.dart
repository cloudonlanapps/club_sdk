/// Every kind of movement recorded in the credit ledger (#14).
enum CreditEntryType {
  /// An account was opened with this amount.
  grant('grant'),

  /// A mistaken grant was undone (negative).
  grantReversal('grantReversal'),

  /// An occurrence was charged (negative).
  sessionDeduction('sessionDeduction'),

  /// A charged occurrence was refunded (positive).
  sessionRefund('sessionRefund'),

  /// A departure penalty (negative).
  penalty('penalty'),

  /// The balance left an account being closed by a transfer (negative).
  transferOut('transferOut'),

  /// The balance arrived in the account a transfer created (positive).
  transferIn('transferIn'),

  /// The validity window was extended. Carries an amount of zero: not a
  /// movement of credit, but it belongs on the statement.
  validityExtended('validityExtended'),

  /// A value this SDK does not know. The server may add entry types; the
  /// amount and reason still read correctly, only the classification is
  /// lost.
  unknown('unknown');

  const CreditEntryType(this.wireName);

  /// The value the server sends and accepts as a filter.
  final String wireName;

  /// Parses a wire value; anything unrecognised is [unknown].
  static CreditEntryType fromWire(String wire) {
    for (final v in CreditEntryType.values) {
      if (v.wireName == wire) return v;
    }
    return CreditEntryType.unknown;
  }
}
