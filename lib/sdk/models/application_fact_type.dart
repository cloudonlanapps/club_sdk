/// The type of a fact on an application template, and of a clause's gap
/// (club_server#93, R6a).
enum ApplicationFactType {
  /// `value`: a UTC-midnight date in ms.
  date('date'),

  /// `from` and `to`: UTC-midnight dates in ms, the end not before the
  /// start.
  dateRange('date_range'),

  /// `value`: `"H:MM"` on a 24-hour clock.
  time('time'),

  /// `value`: a whole number, 0 or more.
  amount('amount'),

  /// `value`: text, or `{language: text}` with English.
  name('name'),

  /// `value`: a non-empty list of the library's choice ids.
  choices('choices');

  const ApplicationFactType(this.wireName);

  /// The value as the server sends it.
  final String wireName;

  /// Parse a wire value. The server knows no other type, so an unknown one
  /// is a [FormatException].
  static ApplicationFactType fromWire(String wire) {
    for (final v in ApplicationFactType.values) {
      if (v.wireName == wire) return v;
    }
    throw FormatException('Unknown application fact type', wire);
  }
}
