/// The order of a credit statement (`listEntries`, `listMyEntries`).
///
/// Left unset, the server lists oldest first.
enum EntryOrder {
  /// Oldest entry first: reads like a passbook.
  oldestFirst('asc'),

  /// Newest entry first: the latest movement on top.
  newestFirst('desc');

  const EntryOrder(this.wireName);

  /// The value the server accepts as the `order` parameter.
  final String wireName;
}
