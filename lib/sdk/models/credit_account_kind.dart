/// Whether a credit account pays for one programme or for any (#14).
enum CreditAccountKind {
  /// Bound to one programme (`eventId` is set) and spent only there.
  event('event'),

  /// Spent on any programme the member is enrolled in.
  general('general');

  const CreditAccountKind(this.wireName);

  /// The value the server sends and accepts.
  final String wireName;

  /// Parses a wire value; an unknown value reads as [general], the kind
  /// that makes no claim about an event.
  static CreditAccountKind fromWire(String wire) {
    for (final v in CreditAccountKind.values) {
      if (v.wireName == wire) return v;
    }
    return CreditAccountKind.general;
  }
}
