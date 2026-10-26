import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'application_fact_type.dart';

/// A value typed once on an application template and printed wherever a
/// clause names it (club_server#93, R6a): `{"type": …, "value": …}`, or
/// `{"type": "date_range", "from": …, "to": …}`.
///
/// [value] holds the JSON value as sent — ms for a date, `"H:MM"` for a
/// time, an int for an amount, a string or `{language: text}` for a name, a
/// list of choice ids for choices — so the fact reads back unchanged; the
/// typed getters read it. A range's ends are [fromUtc] and [toUtc].
@immutable
class ApplicationFact {
  const ApplicationFact({
    required this.type,
    this.value,
    this.fromUtc,
    this.toUtc,
  });

  /// A date; [dateUtc] must be a UTC midnight.
  factory ApplicationFact.date(DateTime dateUtc) => ApplicationFact(
    type: ApplicationFactType.date,
    value: dateUtc.millisecondsSinceEpoch,
  );

  /// A range of dates, both UTC midnights, [toUtc] not before [fromUtc].
  factory ApplicationFact.dateRange(DateTime fromUtc, DateTime toUtc) =>
      ApplicationFact(
        type: ApplicationFactType.dateRange,
        fromUtc: fromUtc,
        toUtc: toUtc,
      );

  /// A time of day, `"H:MM"` on a 24-hour clock.
  const ApplicationFact.time(String time)
    : this(type: ApplicationFactType.time, value: time);

  /// A whole amount, 0 or more.
  const ApplicationFact.amount(int amount)
    : this(type: ApplicationFactType.amount, value: amount);

  /// A name printed as typed in every language.
  const ApplicationFact.name(String name)
    : this(type: ApplicationFactType.name, value: name);

  /// A name given per language; it must have English.
  const ApplicationFact.localizedName(Map<String, String> names)
    : this(type: ApplicationFactType.name, value: names);

  /// Choices from the clause library (`on_ice`, `inline`).
  const ApplicationFact.choices(List<String> ids)
    : this(type: ApplicationFactType.choices, value: ids);

  factory ApplicationFact.fromMap(Map<String, dynamic> map) {
    final type = ApplicationFactType.fromWire(map['type'] as String);
    final raw = map['value'];
    return ApplicationFact(
      type: type,
      value: switch (raw) {
        final Map<dynamic, dynamic> m => <String, String>{
          for (final e in m.entries) e.key as String: e.value as String,
        },
        final List<dynamic> l => List<String>.from(l),
        _ => raw,
      },
      fromUtc: dateFromWire(map['from']),
      toUtc: dateFromWire(map['to']),
    );
  }

  /// A UTC date from ms, or null.
  static DateTime? dateFromWire(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;

  /// The fact's type.
  final ApplicationFactType type;

  /// The JSON value, for every type but a range.
  final Object? value;

  /// A range's first day.
  final DateTime? fromUtc;

  /// A range's last day.
  final DateTime? toUtc;

  /// A date's day.
  DateTime? get dateUtc =>
      type == ApplicationFactType.date ? dateFromWire(value) : null;

  /// A time's `"H:MM"`.
  String? get time => type == ApplicationFactType.time && value is String
      ? value! as String
      : null;

  /// An amount's number.
  int? get amount =>
      type == ApplicationFactType.amount && value is int ? value! as int : null;

  /// A name typed once for every language.
  String? get plainName => type == ApplicationFactType.name && value is String
      ? value! as String
      : null;

  /// A name given per language.
  Map<String, String>? get localizedName =>
      type == ApplicationFactType.name && value is Map<String, String>
      ? value! as Map<String, String>
      : null;

  /// A choices fact's ids.
  List<String>? get choices =>
      type == ApplicationFactType.choices && value is List<String>
      ? value! as List<String>
      : null;

  Map<String, dynamic> toMap() => type == ApplicationFactType.dateRange
      ? {
          'type': type.wireName,
          'from': fromUtc?.millisecondsSinceEpoch,
          'to': toUtc?.millisecondsSinceEpoch,
        }
      : {'type': type.wireName, 'value': value};

  @override
  String toString() => 'ApplicationFact(${toMap()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationFact &&
          other.type == type &&
          other.fromUtc == fromUtc &&
          other.toUtc == toUtc &&
          const DeepCollectionEquality().equals(other.value, value);

  @override
  int get hashCode => Object.hash(
    type,
    fromUtc,
    toUtc,
    const DeepCollectionEquality().hash(value),
  );
}
